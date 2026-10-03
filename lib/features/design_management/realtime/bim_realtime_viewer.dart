import '../viewer/bim_viewer_contract.dart';
import 'bim_session_models.dart';

abstract interface class BimRealtimeViewer {
  bool get isReady;
  Stream<Map<String, dynamic>> get events;
  Future<Map<String, dynamic>> command(
    String type, [
    Map<String, dynamic> payload = const {},
  ]);
  Future<BimViewState> getViewState();
  Future<void> applyViewState(BimViewState viewState);
}

class BimRealtimeViewerAdapter implements BimRealtimeViewer {
  BimRealtimeViewerAdapter(this.controller);

  final BimViewerController controller;

  @override
  bool get isReady => controller.isReady;

  @override
  Stream<Map<String, dynamic>> get events => controller.events;

  @override
  Future<Map<String, dynamic>> command(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) => controller.command(type, payload);

  @override
  Future<BimViewState> getViewState() => controller.getViewState();

  @override
  Future<void> applyViewState(BimViewState viewState) async {
    await controller.applyViewState(viewState);
  }
}
