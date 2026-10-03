import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_contract.dart';

void main() {
  test(
    'typed commands preserve binary snapshots and full view state',
    () async {
      final controller = BimViewerController();
      final requests = <String>[];
      controller.attach((type, payload) async {
        requests.add(type);
        return type == 'getViewState'
            ? {
              'view_state': {
                'schema_version': 1,
                'sections': [1, 2],
              },
            }
            : {};
      }, () async => Uint8List.fromList([1, 2, 3]));
      expect(await controller.captureSnapshot(), [1, 2, 3]);
      expect((await controller.getViewState())['sections'], [1, 2]);
      await controller.hideSelected();
      await controller.applyViewState({
        'sections': [1, 2],
      });
      await controller.dispose();
      expect(requests, [
        'getViewState',
        'hideSelected',
        'applyViewState',
        'dispose',
      ]);
      await expectLater(controller.fit(), throwsStateError);
    },
  );

  test('detaching prevents commands to the destroyed viewer', () async {
    final controller = BimViewerController();
    controller.attach((type, payload) async => {}, () async => Uint8List(0));
    controller.detach();
    await expectLater(controller.command('sessionStart'), throwsStateError);
    await controller.dispose();
  });

  test(
    'snapshot uses the selection and sections captured with the PNG',
    () async {
      final controller = BimViewerController();
      final bytes = Completer<Uint8List>();
      controller.attach((type, payload) async {
        throw StateError('A later view must not replace the captured frame');
      }, () => bytes.future);
      final frame = controller.captureViewSnapshot();
      await expectLater(controller.captureViewSnapshot(), throwsStateError);
      controller.recordSnapshotState({
        'schema_version': 1,
        'selection': [
          {'version_id': '17', 'element_id': 2863},
        ],
        'sections': [
          {
            'id': 'x',
            'normal': [1, 0, 0],
            'constant': 3,
            'enabled': true,
          },
        ],
      });
      bytes.complete(Uint8List.fromList([1, 2, 3]));
      final captured = await frame;
      expect(captured.bytes, [1, 2, 3]);
      expect(captured.viewState['selection'], [
        {'version_id': '17', 'element_id': 2863},
      ]);
      expect((captured.viewState['sections'] as List).single['constant'], 3);
      controller.detach();
      await controller.dispose();
    },
  );
}
