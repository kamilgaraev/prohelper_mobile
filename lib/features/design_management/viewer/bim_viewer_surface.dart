import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/network/dio_client.dart';
import '../../auth/domain/auth_provider.dart';
import '../../projects/domain/projects_provider.dart';
import 'bim_loopback_server.dart';
import 'bim_viewer_contract.dart';

export 'bim_viewer_contract.dart';

class BimViewerSurface extends ConsumerStatefulWidget {
  const BimViewerSurface({
    super.key,
    required this.document,
    required this.controller,
    this.onSelection,
    this.onViewChanged,
    this.onError,
  });

  final BimViewerDocument document;
  final BimViewerController controller;
  final ValueChanged<BimViewerSelection?>? onSelection;
  final ValueChanged<BimViewerViewState>? onViewChanged;
  final ValueChanged<String>? onError;

  @override
  ConsumerState<BimViewerSurface> createState() => _BimViewerSurfaceState();
}

class _BimViewerSurfaceState extends ConsumerState<BimViewerSurface>
    with WidgetsBindingObserver {
  final _server = BimLoopbackServer();
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _cancellations = <CancelToken>[];
  final _externalDio = Dio();
  WebViewController? _webview;
  List<Map<String, dynamic>> _models = const [];
  String? _error;
  bool _ready = false;
  bool _closed = false;
  int _requestId = 0;
  ProviderSubscription<AuthState>? _authSubscription;
  ProviderSubscription<int?>? _projectSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final auth = ref.read(authProvider);
    final identity = auth is AuthAuthenticated ? auth.sessionIdentity : null;
    final projectId = ref.read(projectsProvider).selectedProject?.serverId;
    _authSubscription = ref.listenManual<AuthState>(authProvider, (_, next) {
      if (next is! AuthAuthenticated || next.sessionIdentity != identity) {
        _invalidateContext();
      }
    });
    _projectSubscription = ref.listenManual<int?>(
      projectsProvider.select((state) => state.selectedProject?.serverId),
      (_, next) {
        if (next != projectId) _invalidateContext();
      },
    );
    unawaited(_initialize());
  }

  void _invalidateContext() {
    if (_closed) return;
    _fail('Просмотр закрыт: изменился пользователь, организация или объект.');
    _release();
  }

  Future<void> _initialize() async {
    try {
      await _server.start();
      final manifest =
          jsonDecode(
                await rootBundle.loadString('assets/bim/viewer-manifest.json'),
              )
              as Map<String, dynamic>;
      if (manifest['schema_version'] != 1) {
        throw const FormatException('Manifest');
      }
      for (final entry in (manifest['files'] as List).cast<Map>()) {
        final path = entry['path'] as String;
        final data = await rootBundle.load('assets/bim/$path');
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        if (sha256.convert(bytes).toString() != entry['sha256'] ||
            bytes.length != entry['size']) {
          throw const FormatException('Viewer assets checksum');
        }
        _server.registerBytes(path, bytes, entry['mime'] as String);
      }
      _models = await Future.wait(widget.document.models.map(_registerModel));
      if (_closed || !mounted) return;
      final background = Theme.of(context).colorScheme.surface;
      final webview = WebViewController();
      await webview.setJavaScriptMode(JavaScriptMode.unrestricted);
      await webview.setBackgroundColor(background);
      await webview.addJavaScriptChannel(
        'MostBimNative',
        onMessageReceived: _onMessage,
      );
      await webview.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url == 'about:blank') {
              return NavigationDecision.navigate;
            }
            final uri = Uri.tryParse(request.url);
            return uri != null &&
                    uri.hasAuthority &&
                    uri.origin == _server.baseUri.origin &&
                    uri.path.startsWith(_server.baseUri.path)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _fail('Не удалось открыть модель. Повторите попытку.');
            }
          },
        ),
      );
      if (_closed) return;
      _webview = webview;
      widget.controller.attach(_command, _captureSnapshot);
      await webview.loadRequest(_server.baseUri.resolve('index.html'));
      if (mounted) setState(() {});
    } catch (_) {
      _fail(
        'Не удалось подготовить просмотр модели. Проверьте соединение и повторите попытку.',
      );
    }
  }

  Future<Map<String, dynamic>> _registerModel(BimViewerModel model) async {
    final local = model.localSource;
    BimLoopbackResource resource;
    if (local != null) {
      resource = BimLoopbackResource(
        length: local.length,
        mime: local.mime,
        read: (start, end) => local.read(start, end),
      );
    } else {
      final uri = model.geometryUrl!;
      final nativeDio = ref.read(dioProvider);
      final apiOrigin = Uri.parse(nativeDio.options.baseUrl).origin;
      if (uri.scheme != 'https' && uri.origin != apiOrigin) {
        throw const FormatException('Invalid model URL');
      }
      final dio = uri.origin == apiOrigin ? nativeDio : _externalDio;
      final token = CancelToken();
      _cancellations.add(token);
      final first = await dio.get<ResponseBody>(
        uri.toString(),
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(minutes: 5),
        ),
        cancelToken: token,
      );
      final length =
          model.geometryLength ??
          int.tryParse(first.headers.value(Headers.contentLengthHeader) ?? '');
      if (length == null || length <= 0) {
        token.cancel();
        throw const FormatException('Missing model length');
      }
      var initialAvailable = true;
      resource = BimLoopbackResource(
        length: length,
        mime: 'application/octet-stream',
        read: (start, end) async* {
          ResponseBody body;
          if (initialAvailable && start == 0 && end == length) {
            initialAvailable = false;
            body = first.data!;
          } else {
            if (initialAvailable) {
              initialAvailable = false;
              await first.data!.stream.listen(null).cancel();
            }
            final response = await dio.get<ResponseBody>(
              uri.toString(),
              options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: const Duration(minutes: 5),
                headers: {'Range': 'bytes=$start-${end - 1}'},
              ),
              cancelToken: token,
            );
            if (response.statusCode != 206 && (start != 0 || end != length)) {
              throw const FormatException('Range not supported');
            }
            body = response.data!;
          }
          yield* body.stream;
        },
      );
    }
    final url = _server.register('models/${model.versionId}.frag', resource);
    return {
      'version_id': '${model.versionId}',
      'url': '$url',
      'transform': model.transform,
    };
  }

  void _onMessage(JavaScriptMessage message) {
    if (_closed || message.message.length > 1024 * 1024) return;
    try {
      final event = Map<String, dynamic>.from(
        jsonDecode(message.message) as Map,
      );
      if (event['schema_version'] != 1) return;
      if (event['kind'] == 'response') {
        final pending = _pending.remove(event['id']);
        if (pending != null && !pending.isCompleted) {
          if (event['error'] != null) {
            pending.completeError(
              StateError(
                event['error'] == 'realtime_tls_required'
                    ? 'Для совместной сессии требуется защищённое соединение с сервером.'
                    : 'Viewer command failed',
              ),
            );
          } else {
            pending.complete(
              Map<String, dynamic>.from(event['payload'] as Map? ?? {}),
            );
          }
        }
        return;
      }
      final type = event['type'];
      final payload = event['payload'];
      if (type == 'boot') {
        unawaited(_loadDocument());
      } else if (type == 'unsupported') {
        _fail(
          'На этом устройстве просмотр BIM недоступен. Требуется поддержка WebGL 2 и Web Workers.',
        );
      } else if (type == 'nativeAuthRequest') {
        unawaited(_authorize(event));
      } else if (type == 'selection') {
        final selection = payload is Map ? payload : null;
        widget.onSelection?.call(
          selection == null
              ? null
              : BimViewerSelection(
                versionId: int.parse('${selection['version_id']}'),
                expressId: (selection['element_id'] as num).toInt(),
              ),
        );
      } else if (type == 'viewChanged' && payload is Map) {
        widget.onViewChanged?.call(Map<String, dynamic>.from(payload));
      } else if (type == 'error') {
        _fail(
          'Не удалось показать модель. Повторите подготовку модели или откройте другую версию.',
        );
      }
      widget.controller.emit({'type': type, 'payload': payload});
    } catch (_) {
      _fail('Не удалось обработать состояние модели. Повторите попытку.');
    }
  }

  Future<void> _loadDocument() async {
    try {
      await _command('initialize', {
        'models': _models,
        'model_set_revision_id': widget.document.modelSetRevisionId?.toString(),
        'worker_url': _server.baseUri.resolve('vendor/worker.mjs').toString(),
      });
      if (!mounted || _closed) return;
      widget.controller.markReady();
      setState(() => _ready = true);
      widget.controller.emit({
        'type': 'ready',
        'payload': const <String, dynamic>{},
      });
    } catch (_) {
      _fail(
        'Не удалось загрузить модель. Проверьте соединение и повторите попытку.',
      );
    }
  }

  Future<void> _authorize(Map<String, dynamic> request) async {
    final payload = request['payload'] as Map;
    final channel = '${payload['channelName']}';
    if (!RegExp(r'^presence-design-model-session\.\d+$').hasMatch(channel)) {
      return;
    }
    try {
      final response = await ref
          .read(dioProvider)
          .post<dynamic>(
            '/broadcasting/auth',
            data: {'socket_id': payload['socketId'], 'channel_name': channel},
          );
      final body = response.data as Map;
      final result = body['data'] is Map ? body['data'] as Map : body;
      await _send({
        'schema_version': 1,
        'kind': 'authResponse',
        'id': request['id'],
        'payload': {
          'auth': result['auth'],
          'channel_data': result['channel_data'],
        },
      });
    } catch (_) {
      await _send({
        'schema_version': 1,
        'kind': 'authResponse',
        'id': request['id'],
        'error': 'Authorization failed',
      });
    }
  }

  Future<Map<String, dynamic>> _command(
    String type,
    Map<String, dynamic> payload,
  ) async {
    if (_closed) throw StateError('Viewer closed');
    final id = '${++_requestId}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    try {
      await _send({
        'schema_version': 1,
        'kind': 'command',
        'id': id,
        'type': type,
        'payload': payload,
      });
      return await completer.future.timeout(const Duration(minutes: 3));
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> _send(Map<String, dynamic> message) async {
    final webview = _webview;
    if (_closed || webview == null) throw StateError('Viewer closed');
    await webview.runJavaScript(
      'window.MostBim.receive(${jsonEncode(message)});',
    );
  }

  Future<Uint8List> _captureSnapshot() async {
    final url = _server.registerSnapshot('capture-${++_requestId}');
    final result = await _command('captureSnapshot', {
      'upload_url': url.toString(),
    });
    final state = result['camera'];
    if (state is Map) {
      widget.controller.recordSnapshotState(Map<String, dynamic>.from(state));
    }
    return _server.takeSnapshot(url);
  }

  void _fail(String message) {
    if (_closed || !mounted) return;
    setState(() => _error = message);
    widget.onError?.call(message);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_ready || _closed) return;
    unawaited(
      _command('lifecycle', {
        'active': state == AppLifecycleState.resumed,
      }).catchError((_) => <String, dynamic>{}),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.close();
    _projectSubscription?.close();
    _release();
    super.dispose();
  }

  void _release() {
    if (_closed) return;
    widget.controller.detach();
    final webview = _webview;
    if (webview != null) {
      unawaited(
        webview.runJavaScript('window.MostBim?.dispose();').catchError((_) {}),
      );
      unawaited(
        webview.loadRequest(Uri.parse('about:blank')).catchError((_) {}),
      );
    }
    _closed = true;
    for (final cancellation in _cancellations) {
      cancellation.cancel();
    }
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError('Viewer closed'));
      }
    }
    _pending.clear();
    _externalDio.close(force: true);
    unawaited(_server.close());
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final webview = _webview;
    return Stack(
      children: [
        if (webview != null)
          Positioned.fill(child: WebViewWidget(controller: webview)),
        if (!_ready) const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
