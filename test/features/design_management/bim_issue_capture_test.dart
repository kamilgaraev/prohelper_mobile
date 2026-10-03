import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/error/user_message.dart';
import 'package:prohelpers_mobile/features/design_management/domain/bim_issue_capture.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_contract.dart';

void main() {
  const view = {
    'schema_version': 1,
    'selection': [
      {'version_id': '11', 'element_id': 20787},
    ],
    'camera': {
      'position': [1, 2, 3],
    },
    'sections': [],
  };

  test(
    'uses the view captured atomically with a successful snapshot',
    () async {
      final controller = BimViewerController();
      controller.attach(
        (type, payload) async {
          fail('Successful capture must not fetch a later view');
        },
        () async {
          controller.recordSnapshotState(view);
          return Uint8List.fromList([1, 2, 3]);
        },
      );
      final capture = await captureBimIssueContext(controller);
      expect(capture.snapshot, [1, 2, 3]);
      expect(capture.viewState, view);
      controller.detach();
      await controller.dispose();
    },
  );

  for (final code in [
    'snapshot_unavailable',
    'snapshot_capture_failed',
    'snapshot_upload_failed',
  ]) {
    test('$code preserves selected element and camera without PNG', () async {
      final controller = BimViewerController();
      controller.attach((type, payload) async {
        expect(type, 'getViewState');
        return {'view_state': view};
      }, () async => throw BimViewerCommandException(code));
      final capture = await captureBimIssueContext(controller);
      expect(capture.snapshot, isNull);
      expect(capture.viewState, view);
      controller.detach();
      await controller.dispose();
    });
  }

  test(
    'does not ignore unavailable viewer or other command failures',
    () async {
      final controller = BimViewerController();
      controller.attach((type, payload) async {
        fail('Unexpected failures must not continue issue creation');
      }, () async => throw const BimViewerCommandException('viewer_not_ready'));
      await expectLater(
        captureBimIssueContext(controller),
        throwsA(isA<BimViewerCommandException>()),
      );
      controller.detach();
      await expectLater(captureBimIssueContext(controller), throwsStateError);
      await controller.dispose();
    },
  );

  test(
    'does not create context when the current view cannot be read',
    () async {
      final controller = BimViewerController();
      controller.attach(
        (type, payload) async {
          throw const BimViewerCommandException('viewer_not_ready');
        },
        () async =>
            throw const BimViewerCommandException('snapshot_unavailable'),
      );
      await expectLater(
        captureBimIssueContext(controller),
        throwsA(isA<BimViewerCommandException>()),
      );
      controller.detach();
      await controller.dispose();
    },
  );

  test('viewer errors contain user messages and no internal code', () {
    expect(
      UserMessage.fromError(
        const BimViewerCommandException('snapshot_capture_failed'),
      ),
      'Не удалось сделать снимок модели. Попробуйте ещё раз.',
    );
    expect(
      UserMessage.fromError(
        const BimViewerCommandException('private_unknown_error'),
      ),
      'Не удалось выполнить действие с моделью. Попробуйте ещё раз.',
    );
  });
}
