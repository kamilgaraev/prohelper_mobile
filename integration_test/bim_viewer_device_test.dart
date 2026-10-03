import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_surface.dart';
import 'package:prohelpers_mobile/features/design_management/domain/bim_issue_capture.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = const bool.fromEnvironment(
    'BIM_DEVICE_EXTERNAL_TOUCH',
  );

  testWidgets(
    'real BIM FRAG renders and restores on Android',
    (tester) async {
      expect(Platform.isAndroid, isTrue, reason: 'Run this test on Android.');
      const fixtureUrl = String.fromEnvironment('BIM_FIXTURE_URL');
      const expectedHash = String.fromEnvironment('BIM_DEVICE_FRAG_SHA256');
      expect(
        fixtureUrl,
        isNotEmpty,
        reason: 'Prepare --dart-define-from-file.',
      );
      final bytes = await _device(tester, () => _fetchFixture(fixtureUrl));
      expect(sha256.convert(bytes).toString(), expectedHash);
      final lifecycle = _PlatformLifecycle();
      binding.addObserver(lifecycle);
      addTearDown(() => binding.removeObserver(lifecycle));
      final report = <String, dynamic>{
        'fixture_bytes': bytes.length,
        'fixture_sha256': expectedHash,
        'backend': 'ProviderScope test auth/project; local FRAG source',
      };
      binding.reportData = report;
      report['lifecycle_states'] = lifecycle.names;
      report['process_before_open'] = await _device(tester, _processResources);
      var sourceReads = 0;
      final source = BimViewerBinarySource(
        length: bytes.length,
        mime: 'application/octet-stream',
        read: (start, end) async* {
          sourceReads++;
          yield Uint8List.sublistView(bytes, start, end ?? bytes.length);
        },
      );
      final document = BimViewerDocument(
        modelSetRevisionId: 71,
        models: [
          BimViewerModel.local(versionId: 17, source: source),
          BimViewerModel.local(
            versionId: 18,
            source: source,
            transform: const {
              'shift': [12, 0, 0],
              'rotation': 0,
            },
          ),
        ],
      );
      final errors = <String>[];
      final controller = BimViewerController();
      addTearDown(controller.dispose);
      final eventTrace = <Map<String, dynamic>>[];
      final eventSubscription = controller.events.listen((event) {
        if (eventTrace.length >= 80 ||
            ![
              'selection',
              'cursor',
              'interaction',
              'error',
            ].contains(event['type'])) {
          return;
        }
        final payload = event['payload'];
        eventTrace.add({
          'type': event['type'],
          if (payload is Map)
            'payload': {
              for (final key in [
                'version_id',
                'element_id',
                'position',
                'x',
                'y',
                'z',
                'kind',
                'code',
              ])
                if (payload.containsKey(key)) key: payload[key],
            },
        });
      });
      addTearDown(eventSubscription.cancel);
      report['controller_events'] = eventTrace;
      await _open(tester, controller, document, errors);
      expect(sourceReads, greaterThanOrEqualTo(2));
      final webview = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
      await _device(
        tester,
        () => webview.platform.params.controller.runJavaScript('''
        window.__mostBimAcceptanceEvents = [];
        const rect = element => {
          const value = element?.getBoundingClientRect();
          return value ? {x:value.x,y:value.y,width:value.width,height:value.height} : null;
        };
        window.__mostBimAcceptanceLayout = () => ({
          container:rect(document.getElementById('viewer')),
          canvas:rect(document.querySelector('canvas')),
          device_pixel_ratio:devicePixelRatio});
        for (const type of ['pointerdown','pointerup','pointercancel','pointerleave','pointermove','click','wheel']) {
          document.addEventListener(type, event => {
            const events = window.__mostBimAcceptanceEvents;
            if (events.length < 60) events.push({type:event.type,
              target:event.target?.tagName,pointer_type:event.pointerType,
              pointer_id:event.pointerId,
              button:event.button,buttons:event.buttons,x:event.clientX,y:event.clientY,
              delta_x:event.deltaX,delta_y:event.deltaY,
              layout:window.__mostBimAcceptanceLayout(),
              trusted:event.isTrusted});
          }, true);
        }
      '''),
      );
      final diagnostic = await _device(tester, () async {
        final value = await webview.platform.params.controller
            .runJavaScriptReturningResult('''
        JSON.stringify((() => {
          const canvas = document.querySelector('canvas');
          const gl = canvas?.getContext('webgl2');
          return { url: location.href, webgl2: !!gl,
            context_lost: gl?.isContextLost(), worker: typeof Worker,
            width: canvas?.width, height: canvas?.height,
            models: performance.getEntriesByType('resource')
              .filter(entry => entry.name.endsWith('.frag')).length };
        })())
      ''');
        return Map<String, dynamic>.from(_javaScriptValue(value) as Map);
      });
      expect(diagnostic['webgl2'], isTrue);
      expect(diagnostic['context_lost'], isFalse);
      expect(diagnostic['worker'], 'function');
      expect(diagnostic['models'], 2);
      diagnostic['url'] =
          Uri.parse(diagnostic['url'] as String).replace(path: '/').toString();
      report['webview'] = diagnostic;
      report['process_loaded'] = await _device(tester, _processResources);
      debugPrint('BIM_DEVICE_PHASE loaded ${jsonEncode(diagnostic)}');

      final initial = await _device(tester, controller.getViewState);
      expect(initial['schema_version'], 1);
      expect(initial['model_set_revision_id'], '71');
      expect(_models(initial).keys, unorderedEquals(['17', '18']));
      final firstSelection = _copy(initial)
        ..['selection'] = [
          {'version_id': '17', 'element_id': 2863},
        ];
      await _device(tester, () => controller.applyViewState(firstSelection));
      await _device(tester, controller.hideSelected);
      final hidden = await _device(tester, controller.getViewState);
      expect(_models(hidden)['17']!['hidden_element_ids'], [2863]);
      expect(_models(hidden)['18']!['hidden_element_ids'], isEmpty);
      await _device(tester, controller.showAll);

      final bothSelection = _copy(initial)
        ..['selection'] = [
          {'version_id': '17', 'element_id': 2863},
          {'version_id': '18', 'element_id': 2863},
        ];
      await _device(tester, () => controller.applyViewState(bothSelection));
      await _device(tester, controller.isolateSelected);
      final isolated = await _device(tester, controller.getViewState);
      for (final model in _models(isolated).values) {
        expect(model['isolated_element_ids'], [2863]);
      }
      report['same_express_id_two_models'] = true;

      await _device(tester, () => controller.setCameraPreset('front'));
      final front = await _device(tester, controller.getViewState);
      expect(front['camera'], isNot(equals(initial['camera'])));
      await _device(tester, () => controller.setSection('x', 2.74891));
      final sectioned = await _device(tester, controller.getViewState);
      expect(sectioned['sections'], hasLength(1));
      final portable = _copy(sectioned);
      final models = _models(portable);
      models['18']!['visible'] = false;
      models['18']!['hidden_element_ids'] = [3014];
      portable['models'] = models.values.toList();
      await _device(tester, () => controller.applyViewState(portable));
      final frame = await _device(tester, controller.captureViewSnapshot);
      _expectState(frame.viewState, portable);
      final png = await _device(tester, () => _verifyPng(frame.bytes));
      report['png'] = png;
      report['full_state_restore'] = true;
      await _device(
        tester,
        () => webview.platform.params.controller.runJavaScript('''
          window.__mostOriginalToBlob = HTMLCanvasElement.prototype.toBlob;
          window.__mostOriginalFetch = window.fetch;
        '''),
      );
      for (final mode in ['null', 'encode', 'upload']) {
        await _device(
          tester,
          () => webview.platform.params.controller.runJavaScript('''
            HTMLCanvasElement.prototype.toBlob = window.__mostOriginalToBlob;
            window.fetch = window.__mostOriginalFetch;
            if ('$mode' === 'null') HTMLCanvasElement.prototype.toBlob = function(callback) { callback(null); };
            if ('$mode' === 'encode') HTMLCanvasElement.prototype.toBlob = function() { throw new Error('PNG encoding failure'); };
            if ('$mode' === 'upload') window.fetch = function(input, init) {
              if (String(input).includes('/snapshots/')) return Promise.reject(new TypeError('Snapshot upload failure'));
              return window.__mostOriginalFetch.call(this, input, init);
            };
          '''),
        );
        final capture = await _device(
          tester,
          () => captureBimIssueContext(controller),
        );
        expect(capture.snapshot, isNull);
        _expectState(capture.viewState, portable);
      }
      await _device(
        tester,
        () => webview.platform.params.controller.runJavaScript('''
          HTMLCanvasElement.prototype.toBlob = window.__mostOriginalToBlob;
          window.fetch = window.__mostOriginalFetch;
        '''),
      );
      final recovered = await _device(
        tester,
        () => captureBimIssueContext(controller),
      );
      expect(recovered.snapshot, isNotNull);
      _expectState(recovered.viewState, portable);
      report['snapshot_failure_context_preserved'] = [
        'null',
        'encode',
        'upload',
      ];
      report['snapshot_capture_recovered'] = true;
      await _device(tester, controller.showAll);
      await _device(tester, controller.clearSections);
      await _device(tester, () => controller.setCameraPreset('top'));
      await _device(tester, () => controller.restoreIssueView(frame.viewState));
      _expectState(
        await _device(tester, controller.getViewState),
        frame.viewState,
      );
      debugPrint('BIM_DEVICE_PHASE restored ${jsonEncode(png)}');

      await _device(tester, controller.showAll);
      await _device(tester, controller.clearSections);
      final touchState = _copy(initial);
      touchState['camera'] = {
        ...(initial['camera'] as Map),
        'position': [2.74891, -0.15, 10],
        'target': [2.74891, -0.15, -0.0178],
        'up': [0, 1, 0],
        'projection': 'perspective',
        'fov': 50,
        'zoom': 1,
      };
      final touchModels = _models(touchState);
      touchModels['17']!['isolated_element_ids'] = [2863];
      touchModels['18']!['visible'] = false;
      touchState['models'] = touchModels.values.toList();
      await _device(tester, () => controller.applyViewState(touchState));
      await tester.pump(const Duration(seconds: 1));
      final touchPose = await _device(tester, controller.captureSnapshot);
      final touchPosePath = await _device(tester, () async {
        final file = File(
          '${(await getTemporaryDirectory()).path}/bim-device-touch-17.png',
        );
        await file.writeAsBytes(touchPose);
        return file.path;
      });
      report['native_touch_pose_17'] = {
        'device_path': touchPosePath,
        'sha256': sha256.convert(touchPose).toString(),
        'camera': touchState['camera'],
      };
      report['device_pointer_events_enabled'] =
          binding.shouldPropagateDevicePointerEvents;
      const externalTouch = bool.fromEnvironment('BIM_DEVICE_EXTERNAL_TOUCH');
      if (externalTouch) {
        debugPrint('BIM_DEVICE_PHASE native_pick_17_ready');
      } else {
        await tester.tapAt(tester.getCenter(find.byType(WebViewWidget)));
      }
      try {
        await _waitFor(
          tester,
          () async {
            final state = await _device(tester, controller.getViewState);
            return (state['selection'] as List).any(
              (dynamic item) =>
                  item['version_id'] == '17' && item['element_id'] == 2863,
            );
          },
          'Native platform-view tap must return IFC expressID 2863.',
          seconds: externalTouch ? 60 : 12,
        );
      } catch (_) {
        report['native_pointer_events'] = await _pointerTrace(tester, webview);
        report['native_touch_final_state'] = await _device(
          tester,
          controller.getViewState,
        );
        rethrow;
      }
      final secondTouch = _copy(touchState);
      secondTouch['camera'] = {
        ...(touchState['camera'] as Map),
        'position': [14.74891, -0.15, 10],
        'target': [14.74891, -0.15, -0.0178],
      };
      final secondModels = _models(secondTouch);
      secondModels['17']!['visible'] = false;
      secondModels['18']!['visible'] = true;
      secondModels['18']!['isolated_element_ids'] = [2863];
      secondTouch['models'] = secondModels.values.toList();
      await _device(tester, () => controller.applyViewState(secondTouch));
      await tester.pump(const Duration(seconds: 1));
      if (externalTouch) {
        debugPrint('BIM_DEVICE_PHASE native_pick_18_ready');
      } else {
        await tester.tapAt(tester.getCenter(find.byType(WebViewWidget)));
      }
      await _waitFor(
        tester,
        () async {
          final state = await _device(tester, controller.getViewState);
          return (state['selection'] as List).any(
            (dynamic item) =>
                item['version_id'] == '18' && item['element_id'] == 2863,
          );
        },
        'The same IFC expressID must be picked in version 18.',
        seconds: externalTouch ? 60 : 12,
      );
      final beforeDrag = await _device(tester, controller.getViewState);
      if (externalTouch) {
        debugPrint('BIM_DEVICE_PHASE native_drag_ready');
        await _waitFor(
          tester,
          () async {
            final state = await _device(tester, controller.getViewState);
            return !equals(
              beforeDrag['camera'],
            ).matches(state['camera'], <dynamic, dynamic>{});
          },
          'ADB drag must change the camera.',
          seconds: 60,
        );
        await tester.pump(const Duration(seconds: 1));
      } else {
        await tester.drag(find.byType(WebViewWidget), const Offset(75, 35));
        await tester.pump(const Duration(seconds: 1));
      }
      final afterDrag = await _device(tester, controller.getViewState);
      expect(afterDrag['camera'], isNot(equals(beforeDrag['camera'])));
      report['platform_view_touch_pick_and_orbit'] = true;
      report['touch_source'] = externalTouch ? 'ADB native input' : 'tester';
      report['native_pointer_events'] = await _pointerTrace(tester, webview);
      debugPrint('BIM_DEVICE_PHASE touch_verified');

      const requireLifecycle = bool.fromEnvironment(
        'BIM_DEVICE_REQUIRE_PLATFORM_LIFECYCLE',
      );
      if (requireLifecycle) {
        await _device(tester, () => controller.applyViewState(afterDrag));
        final lifecycleView = await _device(tester, controller.getViewState);
        final lifecycleStart = lifecycle.states.length;
        debugPrint('BIM_DEVICE_PHASE background_ready');
        await _device(tester, () async {
          final watch = Stopwatch()..start();
          while (watch.elapsed < const Duration(seconds: 60)) {
            final observed = lifecycle.states.skip(lifecycleStart).toList();
            final paused = observed.indexOf(AppLifecycleState.paused);
            if (paused >= 0 &&
                observed.skip(paused + 1).contains(AppLifecycleState.resumed)) {
              return;
            }
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          fail('Use adb HOME then launch the current activity.');
        });
        await _device(tester, controller.captureSnapshot);
        _expectState(
          await _device(tester, controller.getViewState),
          lifecycleView,
        );
        report['actual_platform_background_resume'] = true;
      } else {
        report['actual_platform_background_resume'] = 'not requested';
      }

      final originalUrl = Uri.parse(diagnostic['url'] as String);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.isAttached, isFalse);
      await expectLater(controller.getViewState(), throwsStateError);
      await _device(tester, () => _expectServerClosed(originalUrl));
      report['process_after_close'] = await _device(tester, _processResources);
      final reopened = BimViewerController();
      addTearDown(reopened.dispose);
      await _open(tester, reopened, document, errors);
      await _device(tester, () => reopened.restoreIssueView(frame.viewState));
      _expectState(
        await _device(tester, reopened.getViewState),
        frame.viewState,
      );
      await _device(tester, reopened.captureSnapshot);
      final finalCloseState = await _device(tester, reopened.getViewState);
      report['sections_before_final_close'] =
          (finalCloseState['sections'] as List).length;
      expect(finalCloseState['sections'], hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      expect(reopened.isAttached, isFalse);
      report['process_after_reopen_close'] = await _device(
        tester,
        _processResources,
      );
      expect(errors, isEmpty);
      report['close_reopen_and_loopback_release'] = true;
      report['lifecycle_states'] =
          lifecycle.states.map((state) => state.name).toList();
      report['source_reads'] = sourceReads;
      debugPrint('BIM_DEVICE_RESULT ${jsonEncode(report)}');
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

Future<void> _open(
  WidgetTester tester,
  BimViewerController controller,
  BimViewerDocument document,
  List<String> errors,
) async {
  var ready = false;
  final subscription = controller.events.listen((event) {
    if (event['type'] == 'ready') ready = true;
  });
  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: mostCoreOverrides(selectedProject: MostTestData.project()),
        child: MaterialApp(
          home: Scaffold(
            body: BimViewerSurface(
              document: document,
              controller: controller,
              onError: errors.add,
            ),
          ),
        ),
      ),
    );
    await _waitFor(
      tester,
      () async => ready || errors.isNotEmpty,
      'Real WebGL/Worker initialization timed out.',
      seconds: 90,
    );
    expect(errors, isEmpty);
    expect(ready, isTrue);
  } finally {
    await subscription.cancel();
  }
}

Future<T> _device<T>(
  WidgetTester tester,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 75),
}) async {
  T? result;
  Object? failure;
  StackTrace? failureStack;
  await tester.runAsync(() async {
    try {
      result = await action().timeout(timeout);
    } catch (error, stack) {
      failure = error;
      failureStack = stack;
    }
  });
  if (failure != null) {
    Error.throwWithStackTrace(failure!, failureStack!);
  }
  return result as T;
}

dynamic _javaScriptValue(Object value) {
  dynamic decoded = value;
  for (var attempt = 0; attempt < 3 && decoded is String; attempt++) {
    decoded = jsonDecode(decoded);
  }
  return decoded;
}

Future<dynamic> _pointerTrace(WidgetTester tester, WebViewWidget webview) =>
    _device(tester, () async {
      final value = await webview.platform.params.controller
          .runJavaScriptReturningResult(
            'JSON.stringify({events:window.__mostBimAcceptanceEvents ?? [],'
            'layout:window.__mostBimAcceptanceLayout?.()})',
          );
      return _javaScriptValue(value);
    });

Future<void> _waitFor(
  WidgetTester tester,
  Future<bool> Function() condition,
  String reason, {
  int seconds = 12,
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < Duration(seconds: seconds)) {
    if (await condition()) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(reason);
}

BimViewerViewState _copy(BimViewerViewState state) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(state)) as Map);

Map<String, Map<String, dynamic>> _models(BimViewerViewState state) => {
  for (final dynamic model in state['models'] as List)
    model['version_id'] as String: Map<String, dynamic>.from(model as Map),
};

void _expectState(dynamic actual, dynamic expected, [String path = 'state']) {
  if (expected is num) {
    expect(actual, closeTo(expected.toDouble(), 0.001), reason: path);
  } else if (expected is Map) {
    expect(actual, isA<Map>(), reason: path);
    expect((actual as Map).keys, unorderedEquals(expected.keys), reason: path);
    for (final key in expected.keys) {
      _expectState(actual[key], expected[key], '$path.$key');
    }
  } else if (expected is List) {
    expect(actual, isA<List>(), reason: path);
    expect((actual as List).length, expected.length, reason: path);
    for (var index = 0; index < expected.length; index++) {
      _expectState(actual[index], expected[index], '$path[$index]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

Future<Map<String, dynamic>> _verifyPng(Uint8List bytes) async {
  expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final pixels = await frame.image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  );
  final colors = <int>{};
  for (var offset = 0; offset + 3 < pixels!.lengthInBytes; offset += 64) {
    colors.add(pixels.getUint32(offset));
  }
  expect(frame.image.width, greaterThan(100));
  expect(frame.image.height, greaterThan(100));
  expect(
    colors.length,
    greaterThan(8),
    reason: 'PNG must contain a rendered view.',
  );
  final file = File(
    '${(await getTemporaryDirectory()).path}/bim-device-view.png',
  );
  await file.writeAsBytes(bytes);
  final result = <String, dynamic>{
    'bytes': bytes.length,
    'width': frame.image.width,
    'height': frame.image.height,
    'sampled_colors': colors.length,
    'sha256': sha256.convert(bytes).toString(),
    'device_path': file.path,
  };
  frame.image.dispose();
  codec.dispose();
  return result;
}

Future<void> _expectServerClosed(Uri url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    await expectLater(client.getUrl(url), throwsA(isA<SocketException>()));
  } finally {
    client.close(force: true);
  }
}

class _PlatformLifecycle with WidgetsBindingObserver {
  final states = <AppLifecycleState>[];
  final names = <String>[];

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    states.add(state);
    names.add(state.name);
    debugPrint('BIM_DEVICE_LIFECYCLE ${state.name}');
  }
}

Future<Map<String, dynamic>> _processResources() async {
  try {
    final status = await File('/proc/self/status').readAsString();
    final values = <String, dynamic>{
      for (final name in ['VmRSS', 'VmHWM', 'Threads'])
        name:
            RegExp(
              '^$name:\\s+([^\\n]+)',
              multiLine: true,
            ).firstMatch(status)?.group(1)?.trim(),
    };
    values['file_descriptors'] =
        await Directory('/proc/self/fd').list(followLinks: false).length;
    return values;
  } catch (error) {
    return {'unavailable': error.runtimeType.toString()};
  }
}

Future<Uint8List> _fetchFixture(String value) async {
  final url = Uri.parse(value);
  expect(url.scheme, 'http');
  expect(url.host, '127.0.0.1');
  expect(url.path, '/ifc-express-ids.frag');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final response = await (await client.getUrl(url)).close();
    expect(response.statusCode, HttpStatus.ok);
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response) {
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  } finally {
    client.close(force: true);
  }
}
