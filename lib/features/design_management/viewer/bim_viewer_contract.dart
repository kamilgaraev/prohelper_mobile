import 'dart:async';
import 'dart:typed_data';

typedef BimViewerViewState = Map<String, dynamic>;
typedef BimViewerCommandSender =
    Future<Map<String, dynamic>> Function(
      String type,
      Map<String, dynamic> payload,
    );

class BimViewerBinarySource {
  const BimViewerBinarySource({
    required this.length,
    required this.mime,
    required this.read,
  });

  final int length;
  final String mime;
  final Stream<List<int>> Function(int start, int? end) read;
}

class BimViewerModel {
  const BimViewerModel({
    required this.versionId,
    required Uri this.geometryUrl,
    this.geometryLength,
    this.transform,
  }) : localSource = null;

  const BimViewerModel.local({
    required this.versionId,
    required BimViewerBinarySource source,
    this.transform,
  }) : localSource = source,
       geometryLength = source.length,
       geometryUrl = null;

  final int versionId;
  final Uri? geometryUrl;
  final int? geometryLength;
  final BimViewerBinarySource? localSource;
  final Map<String, dynamic>? transform;
}

class BimViewerDocument {
  const BimViewerDocument({required this.models, this.modelSetRevisionId});

  final List<BimViewerModel> models;
  final int? modelSetRevisionId;
}

class BimViewerSelection {
  const BimViewerSelection({required this.versionId, required this.expressId});

  final int versionId;
  final int expressId;
}

class BimViewerCapturedFrame {
  const BimViewerCapturedFrame({required this.bytes, required this.viewState});
  final Uint8List bytes;
  final BimViewerViewState viewState;
}

class BimViewerController {
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  BimViewerCommandSender? _sender;
  Future<Uint8List> Function()? _capture;
  bool _disposed = false;
  bool _ready = false;
  bool _capturing = false;
  BimViewerViewState? _snapshotState;

  Stream<Map<String, dynamic>> get events => _events.stream;
  bool get isAttached => _sender != null && !_disposed;
  bool get isReady => isAttached && _ready;

  void attach(
    BimViewerCommandSender sender,
    Future<Uint8List> Function() capture,
  ) {
    if (_disposed) throw StateError('Viewer controller disposed');
    _sender = sender;
    _capture = capture;
    _ready = false;
  }

  void markReady() {
    if (isAttached) _ready = true;
  }

  void detach() {
    _sender = null;
    _capture = null;
    _ready = false;
    _snapshotState = null;
  }

  void emit(Map<String, dynamic> event) {
    if (!_disposed) _events.add(event);
  }

  Future<Map<String, dynamic>> command(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) {
    final sender = _sender;
    if (sender == null || _disposed) {
      return Future.error(StateError('Viewer is not ready'));
    }
    return sender(type, payload);
  }

  Future<void> hideSelected() async => command('hideSelected');
  Future<void> isolateSelected() async => command('isolateSelected');
  Future<void> showAll() async => command('showAll');
  Future<void> setSection(String axis, double offset) async =>
      command('setSection', {'axis': axis, 'offset': offset});
  Future<void> clearSections() async => command('clearSections');
  Future<void> fit() async => command('fit');
  Future<void> setCameraPreset(String preset) async =>
      command('cameraPreset', {'preset': preset});
  Future<void> applyViewState(BimViewerViewState state) async =>
      command('applyViewState', {'view_state': state});
  Future<void> restoreIssueView(BimViewerViewState state) async =>
      command('restoreIssueView', {'view_state': state});
  Future<BimViewerViewState> getViewState() async {
    final result = await command('getViewState');
    return Map<String, dynamic>.from(result['view_state'] as Map);
  }

  Future<Uint8List> captureSnapshot() {
    final capture = _capture;
    if (capture == null) return Future.error(StateError('Viewer is not ready'));
    return capture();
  }

  void recordSnapshotState(BimViewerViewState state) {
    _snapshotState = state;
  }

  Future<BimViewerCapturedFrame> captureViewSnapshot() async {
    if (_capturing) throw StateError('Snapshot already in progress');
    _capturing = true;
    try {
      _snapshotState = null;
      final bytes = await captureSnapshot();
      final viewState = _snapshotState ?? await getViewState();
      return BimViewerCapturedFrame(bytes: bytes, viewState: viewState);
    } finally {
      _capturing = false;
      _snapshotState = null;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    if (_sender != null) {
      try {
        await command('dispose').timeout(const Duration(seconds: 2));
      } catch (_) {}
    }
    _disposed = true;
    detach();
    await _events.close();
  }
}
