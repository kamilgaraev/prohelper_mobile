import 'dart:typed_data';

import '../viewer/bim_viewer_contract.dart';

class BimIssueCapture {
  const BimIssueCapture({required this.viewState, this.snapshot});

  final BimViewerViewState viewState;
  final Uint8List? snapshot;
}

Future<BimIssueCapture> captureBimIssueContext(
  BimViewerController controller,
) async {
  try {
    final frame = await controller.captureViewSnapshot();
    return BimIssueCapture(viewState: frame.viewState, snapshot: frame.bytes);
  } on BimViewerCommandException catch (error) {
    if (!error.isSnapshotFailure) rethrow;
    return BimIssueCapture(viewState: await controller.getViewState());
  }
}
