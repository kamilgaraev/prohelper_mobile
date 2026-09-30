import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:prohelpers_mobile/core/network/mobile_api_response.dart';
import 'package:prohelpers_mobile/features/design_management/data/bim_models.dart'
    as models;
import 'package:prohelpers_mobile/features/design_management/data/bim_repository.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_realtime_viewer.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_coordinator.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/bim_session_models.dart';
import 'package:prohelpers_mobile/features/design_management/realtime/dio_bim_session_api.dart';
import 'package:prohelpers_mobile/features/design_management/viewer/bim_viewer_surface.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../test/helpers/mobile_integration_test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.shouldPropagateDevicePointerEvents = true;
  testWidgets(
    'actual Android native session interoperates with desktop admin',
    (tester) async {
      expect(
        Platform.isAndroid,
        isTrue,
        reason: 'This opt-in test needs Android WebView.',
      );
      final config = await _native(tester, _configuration);
      final api = _api(config);
      final control = _Control('${config['BIM_API_CONTROL_URL']}');
      final audit = _Audit('${config['BIM_API_TOKEN']}');
      api.interceptors.add(audit.interceptor);
      final sessionApi = DioBimSessionApi(api);
      final repository = BimRepository(api);
      final sessionId = _id(config, 'SESSION_ID');
      final projectId = _id(config, 'PROJECT_ID');
      final revisionId = _id(config, 'MODEL_SET_REVISION_ID');
      final expressId = _id(config, 'EXPRESS_ID');
      final clientId =
          'android-acceptance-${DateTime.now().microsecondsSinceEpoch}';
      final bootstrap = await _native(
        tester,
        () => sessionApi.bootstrap(sessionId, clientId: clientId),
      );
      expect(bimInt(bootstrap['model_set_revision_id']), revisionId);
      final context = models.BimViewContext.fromJson(
        await _native(
          tester,
          () => repository.openSet(
            _id(config, 'SET_ID'),
            _id(config, 'SET_REVISION'),
          ),
        ),
      );
      expect(context.modelSetRevisionId, revisionId);
      expect(
        context.versionIds,
        hasLength(2),
        reason: 'Two pinned real FRAG models are required.',
      );
      final documentModels = <BimViewerModel>[];
      for (final versionId in context.versionIds) {
        final prepared = await _native(
          tester,
          () => repository.viewer(versionId),
        );
        expect(prepared.ready, isTrue);
        documentModels.add(
          BimViewerModel(
            versionId: versionId,
            geometryUrl: prepared.url!,
            geometryLength: prepared.sizeBytes > 0 ? prepared.sizeBytes : null,
            transform: context.transforms[versionId]?.toJson(),
          ),
        );
      }
      final controller = BimViewerController();
      final sessionViewer = _AuditedSessionViewer(
        controller,
        '${config['BIM_API_TOKEN']}',
      );
      final coordinator = BimSessionCoordinator(
        api: sessionApi,
        viewer: sessionViewer,
        userId: _id(config, 'USER_ID'),
        userName: 'Android acceptance',
        clientId: clientId,
      );
      final received = <BimPresenceEnvelope>[];
      final errors = <String>[];
      final stateTrace = <Map<String, dynamic>>[];
      final stopStateTrace = coordinator.addListener((state) {
        stateTrace.add({
          'at_ms': DateTime.now().millisecondsSinceEpoch,
          'connection': state.connection.name,
          'error': _safeDiagnostic(state.error),
          'notice': _safeDiagnostic(state.notice),
          'participant_count': state.participants.length,
          'following_client_id': state.followingClientId,
          'follow_loading': state.followLoading,
        });
        if (stateTrace.length > 60) stateTrace.removeAt(0);
      });
      final sessionEventTrace = <Map<String, dynamic>>[];
      var ready = false;
      final viewerEvents = controller.events.listen((event) {
        final payload = bimMap(event['payload']);
        sessionEventTrace.add({
          'at_ms': DateTime.now().millisecondsSinceEpoch,
          'type': event['type'],
          'payload': {
            for (final key in [
              'state',
              'status',
              'connection',
              'message',
              'error',
              'channel',
              'socket_id',
              'session_id',
              'client_id',
            ])
              if (payload.containsKey(key) &&
                  (payload[key] == null ||
                      payload[key] is String ||
                      payload[key] is num ||
                      payload[key] is bool))
                key:
                    payload[key] is String
                        ? _safeDiagnostic(payload[key])
                        : payload[key],
          },
        });
        if (sessionEventTrace.length > 60) sessionEventTrace.removeAt(0);
        if (event['type'] == 'ready') ready = true;
        if (event['type'] == 'presence' || event['type'] == 'presenceEvent') {
          final envelope = BimPresenceEnvelope.tryParse(event['payload']);
          if (envelope != null) received.add(envelope);
        }
      });
      final report = <String, dynamic>{
        'transport':
            'actual native Dio authorization, Laravel API, Reverb and desktop admin',
        'client_id': clientId,
        'session_id': sessionId,
        'model_set_revision_id': revisionId,
        'version_ids': context.versionIds,
        'session_event_trace': sessionEventTrace,
        'coordinator_state_trace': stateTrace,
        'native_auth_status_trace': audit.authStatuses,
      };
      final flutterInputCounts = <String, int>{};
      final flutterInputTrace = <Map<String, dynamic>>[];
      report['flutter_raw_input'] = {
        'counts': flutterInputCounts,
        'trace': flutterInputTrace,
      };
      binding.reportData = report;
      addTearDown(() async {
        stopStateTrace();
        coordinator.dispose();
        await viewerEvents.cancel();
        await controller.dispose();
        api.close(force: true);
        control.close();
      });
      final user =
          MostTestData.user()
            ..serverId = _id(config, 'USER_ID')
            ..currentOrganizationId = _id(config, 'ORGANIZATION_ID');
      await tester.pumpWidget(
        ProviderScope(
          overrides: mostCoreOverrides(
            user: user,
            selectedProject: MostTestData.project(id: projectId),
            dio: api,
          ),
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Совместный просмотр МОСТ')),
              body: Column(
                children: [
                  Expanded(
                    child: Listener(
                      onPointerDown:
                          (event) => _recordFlutterInput(
                            'pointerdown',
                            event,
                            flutterInputCounts,
                            flutterInputTrace,
                          ),
                      onPointerMove:
                          (event) => _recordFlutterInput(
                            'pointermove',
                            event,
                            flutterInputCounts,
                            flutterInputTrace,
                          ),
                      onPointerUp:
                          (event) => _recordFlutterInput(
                            'pointerup',
                            event,
                            flutterInputCounts,
                            flutterInputTrace,
                          ),
                      onPointerCancel:
                          (event) => _recordFlutterInput(
                            'pointercancel',
                            event,
                            flutterInputCounts,
                            flutterInputTrace,
                          ),
                      child: BimViewerSurface(
                        document: BimViewerDocument(
                          models: documentModels,
                          modelSetRevisionId: revisionId,
                        ),
                        controller: controller,
                        onError: errors.add,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        key: const ValueKey('native-unfollow'),
                        onPressed: coordinator.stopFollowing,
                        child: const Text('Продолжить самостоятельно'),
                      ),
                      TextButton(
                        key: const ValueKey('native-front'),
                        onPressed: () => controller.setCameraPreset('front'),
                        child: const Text('Спереди'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await _wait(
        tester,
        () async => ready || errors.isNotEmpty,
        'The actual WebGL/Worker viewer must load both models.',
      );
      expect(errors, isEmpty);
      final initial = await _native(tester, controller.getViewState);
      expect(
        _modelStates(initial).keys,
        unorderedEquals(context.versionIds.map((id) => '$id')),
      );
      final webview = tester.widget<WebViewWidget>(find.byType(WebViewWidget));
      final diagnostic = await _native(tester, () => _inspect(webview));
      expect(diagnostic['webgl2'], isTrue);
      expect(diagnostic['worker'], 'function');
      expect(diagnostic['jwt_in_page'], isFalse);
      report['webview'] = diagnostic;
      await _native(tester, () => _observeDeviceInput(webview));
      await _phase(tester, control, 'ready', {
        'client_id': clientId,
        'version_ids': context.versionIds,
      });
      await _native(
        tester,
        () => controller.applyViewState(
          _pickPose(initial, context.versionIds, expressId),
        ),
      );
      report['pose_before_join'] = await _native(
        tester,
        controller.getViewState,
      );
      if (!const bool.fromEnvironment('BIM_SESSION_INPUT_DIAGNOSTIC_ONLY')) {
        await _wait(
          tester,
          () async {
            try {
              final status = await _native(tester, control.status);
              return bimMap(
                bimMap(status['phases'])['admin'],
              ).containsKey('admin_workspace_ready');
            } on DioException catch (error) {
              if (_transientControlTimeout(error)) return false;
              rethrow;
            }
          },
          'The genuine desktop must load both models and authorize Echo before native join.',
          timeout: const Duration(seconds: 360),
        );
      }
      final joinClock = Stopwatch()..start();
      try {
        await _native(
          tester,
          () => coordinator.join(BimSessionSummary.fromJson(bootstrap)),
          timeout: const Duration(seconds: 120),
        );
        report['join_elapsed_ms'] = joinClock.elapsedMilliseconds;
        await _connected(tester, coordinator, errors);
      } catch (_) {
        final state = coordinator.currentState;
        report['subscription_failure'] = {
          'elapsed_ms': joinClock.elapsedMilliseconds,
          'connection': state.connection.name,
          'error': _safeDiagnostic(state.error),
          'participant_count': state.participants.length,
          'following_client_id': state.followingClientId,
          'follow_loading': state.followLoading,
          'auth_requests': audit.authRequests.take(30).toList(),
          'auth_responses': audit.authResponses,
          'auth_statuses': audit.authStatuses,
          'public_session_starts': sessionViewer.publicSessionStarts,
          'outgoing_type_counts': {
            for (final type
                in audit.events.map((event) => event['type']).toSet())
              '$type':
                  audit.events.where((event) => event['type'] == type).length,
          },
        };
        await _cursorDiagnostic(
          tester,
          controller,
          webview,
          audit,
          errors,
          report,
          'subscription_failure',
        );
        rethrow;
      }
      await _wait(
        tester,
        () async => audit.authResponses > 0,
        'The real presence channel must be authorized through native Dio.',
      );
      expect(
        audit.authRequests.every((request) => request['native_bearer'] == true),
        isTrue,
      );
      expect(sessionViewer.publicSessionStarts, greaterThan(0));
      expect(
        audit.authRequests.last['channel_name'],
        'presence-design-model-session.$sessionId',
      );
      expect(
        (await _native(tester, () => _inspect(webview)))['jwt_in_page'],
        isFalse,
      );
      await _wait(
        tester,
        () async => coordinator.currentState.participants.any(
          (participant) => participant.clientId == clientId,
        ),
        'The server must record the native participant heartbeat.',
      );
      final ownParticipant = coordinator.currentState.participants.firstWhere(
        (participant) => participant.clientId == clientId,
      );
      expect(ownParticipant.userId, _id(config, 'USER_ID'));
      await _phase(tester, control, 'joined', {
        'client_id': clientId,
        'session_id': sessionId,
        'user_name': ownParticipant.name,
      });
      await _phase(tester, control, 'authReady', {
        'native_auth_count': audit.authResponses,
        'jwt_in_page': false,
      });
      report['pose_after_join'] = await _native(
        tester,
        controller.getViewState,
      );
      final calibratedPose = _pickPose(initial, context.versionIds, expressId);
      await _native(tester, () => controller.applyViewState(calibratedPose));
      final calibratedReadback = await _native(tester, controller.getViewState);
      expect(_sameState(calibratedReadback, calibratedPose), isTrue);
      report['pose_after_join_calibrated'] = calibratedReadback;
      await _cursorDiagnostic(
        tester,
        controller,
        webview,
        audit,
        errors,
        report,
        'before_input',
      );
      final cursorInput = _deviceInputCoordinates(tester);
      final cursorEventsBefore = audit.events.length;
      await _phase(tester, control, 'native_cursor_input_ready', {
        ...cursorInput,
        'move_x': cursorInput['x']! + 3,
        'move_y': cursorInput['y'],
      });
      try {
        await _wait(
          tester,
          () async => audit.events
              .skip(cursorEventsBefore)
              .any(
                (event) =>
                    event['type'] == 'cursor' && event['payload'] != null,
              ),
          'A real native pointer move must publish a cursor through the production coordinator.',
        );
      } catch (_) {
        await _cursorDiagnostic(
          tester,
          controller,
          webview,
          audit,
          errors,
          report,
          'cursor_timeout',
        );
        rethrow;
      }
      final cursorTrace = bimMap(
        (await _native(tester, () => _inspect(webview)))['pointer_events'],
      );
      expect(bimInt(cursorTrace['pointerdown']), greaterThan(0));
      expect(bimInt(cursorTrace['pointermove']), greaterThan(0));
      await _phase(tester, control, 'nativeCursorReady', {
        'client_id': clientId,
      });
      if (const bool.fromEnvironment('BIM_SESSION_INPUT_DIAGNOSTIC_ONLY')) {
        await _cursorDiagnostic(
          tester,
          controller,
          webview,
          audit,
          errors,
          report,
          'cursor_received',
        );
        await _phase(tester, control, 'native_cursor_input_complete', {});
        await _wait(
          tester,
          () async =>
              bimInt(
                bimMap(
                  (await _native(
                    tester,
                    () => _inspect(webview),
                  ))['pointer_events'],
                )['pointerup'],
              ) >
              bimInt(cursorTrace['pointerup']),
          'The diagnostic cursor must release before the actual pick.',
        );
        await _native(tester, () => controller.applyViewState(calibratedPose));
        final beforePick = audit.events.length;
        await _phase(
          tester,
          control,
          'native_selection_input_ready',
          _deviceInputCoordinates(tester),
        );
        await _wait(
          tester,
          () async => audit.events
              .skip(beforePick)
              .any(
                (event) =>
                    event['type'] == 'select' &&
                    bimMap(event['payload'])['model_version_id'] ==
                        context.versionIds.first &&
                    bimMap(event['payload'])['element_id'] == expressId,
              ),
          'The calibrated diagnostic must receive a real platform tap with numeric model and express IDs.',
        );
        await _cursorDiagnostic(
          tester,
          controller,
          webview,
          audit,
          errors,
          report,
          'pick_received',
        );
        expect(errors, isEmpty);
        expect(coordinator.currentState.error, isNull);
        await _native(tester, coordinator.leave);
        report['actual_native_cursor_and_pick'] = true;
        report['mode'] =
            'native input diagnostic only; desktop pair not verified';
        await tester.pumpWidget(const SizedBox.shrink());
        debugPrint('BIM_SESSION_DIAGNOSTIC_RESULT ${jsonEncode(report)}');
        return;
      }
      final leaderCommand = await _command(
        tester,
        control,
        'leader_ready',
        timeout: const Duration(seconds: 420),
      );
      final leaderClientId = '${leaderCommand['client_id']}';
      expect(leaderClientId, isNotEmpty);
      expect(leaderClientId, isNot(clientId));
      await _wait(
        tester,
        () async => coordinator.currentState.participants.any(
          (participant) => participant.clientId == leaderClientId,
        ),
        'The genuine desktop admin must appear as another active client.',
      );
      final leader = coordinator.currentState.participants.firstWhere(
        (participant) => participant.clientId == leaderClientId,
      );
      await _command(
        tester,
        control,
        'short_events_ready',
        timeout: const Duration(seconds: 300),
      );
      await _wait(
        tester,
        () async =>
            received.any(
              (event) =>
                  event.clientId == leaderClientId &&
                  event.type == 'cursor' &&
                  event.payload.isNotEmpty,
            ) &&
            received.any(
              (event) =>
                  event.clientId == leaderClientId && event.type == 'select',
            ),
        'Desktop cursor and selection must arrive through the actual WebSocket bridge.',
      );
      await _wait(
        tester,
        () async =>
            '${(await _native(tester, () => _inspect(webview)))['text']}'
                .contains(leader.name),
        'The renderer must display the desktop participant cursor label.',
      );
      await _phase(tester, control, 'nativeShortEventsReady', {
        'leader_client_id': leaderClientId,
        'leader_name': leader.name,
        'received_types':
            received
                .where((event) => event.clientId == leaderClientId)
                .map((event) => event.type)
                .toSet()
                .toList(),
      });
      final releaseCountBefore = bimInt(cursorTrace['pointerup']);
      await _phase(tester, control, 'native_cursor_input_complete', {});
      await _wait(
        tester,
        () async =>
            bimInt(
              bimMap(
                (await _native(
                  tester,
                  () => _inspect(webview),
                ))['pointer_events'],
              )['pointerup'],
            ) >
            releaseCountBefore,
        'The actual Android cursor gesture must release before following.',
      );
      final fullCommand = await _command(tester, control, 'leader_full_view');
      final leaderView =
          fullCommand['expected_view_state'] is Map
              ? bimMap(fullCommand['expected_view_state'])
              : await _native(
                tester,
                () => sessionApi.fetchViewState(sessionId, leaderClientId),
              );
      expect(leaderView, isNotNull);
      _richState(leaderView!, context.versionIds);
      await _native(tester, () => coordinator.follow(leaderClientId));
      await _wait(
        tester,
        () async =>
            !coordinator.currentState.followLoading &&
            _sameState(
              await _native(tester, controller.getViewState),
              leaderView,
            ),
        'Complete HTTP leader state must restore camera, transforms, visibility, selection and sections.',
      );
      final followed = await _native(tester, controller.getViewState);
      final followedSelections =
          (followed['selection'] as List).map(bimMap).toList();
      final selectedIdentities =
          followedSelections
              .map(
                (selection) =>
                    '${selection['version_id']}:${selection['element_id']}',
              )
              .toSet();
      expect(
        selectedIdentities.length,
        followedSelections.length,
        reason:
            'Version and express ID together must identify every selection.',
      );
      await _phase(tester, control, 'followReady', {
        'leader_client_id': leaderClientId,
        'view_state': followed,
      });
      await tester.tap(find.byKey(const ValueKey('native-unfollow')));
      await tester.pump();
      expect(coordinator.currentState.followingClientId, isNull);
      final own = await _native(tester, controller.getViewState);
      expect(_sameState(own, followed), isTrue);
      await _phase(tester, control, 'ownUnfollow', {'view_state': own});
      await _command(tester, control, 'leader_after_unfollow');
      await tester.pump(const Duration(seconds: 2));
      final preserved = await _native(tester, controller.getViewState);
      expect(
        _sameState(preserved, own),
        isTrue,
        reason:
            'Late desktop changes must preserve the mobile independent view.',
      );
      await _phase(tester, control, 'ownUnfollowPreserved', {
        'view_state': preserved,
      });
      await _native(
        tester,
        () => controller.applyViewState(
          _pickPose(initial, context.versionIds, expressId),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final outgoingBefore = audit.events.length;
      final incomingBefore = received.length;
      await _phase(tester, control, 'selectionReady', {
        'version_id': context.versionIds.first,
        'element_id': expressId,
      });
      await _command(tester, control, 'selection_burst');
      await _wait(
        tester,
        () async =>
            received
                .skip(incomingBefore)
                .where(
                  (event) =>
                      event.clientId == leaderClientId &&
                      event.type == 'camera',
                )
                .length >=
            3,
        'Desktop camera burst must continue while mobile selects.',
      );
      final selectionTraceBefore = bimMap(
        (await _native(tester, () => _inspect(webview)))['pointer_events'],
      );
      await _phase(
        tester,
        control,
        'native_selection_input_ready',
        _deviceInputCoordinates(tester),
      );
      await _wait(
        tester,
        () async => audit.events
            .skip(outgoingBefore)
            .any(
              (event) =>
                  event['type'] == 'select' &&
                  bimMap(event['payload'])['model_version_id'] ==
                      context.versionIds.first &&
                  bimMap(event['payload'])['element_id'] == expressId,
            ),
        'A real platform-view tap must publish numeric version and express ID while camera messages arrive.',
      );
      final selected = audit.events
          .skip(outgoingBefore)
          .lastWhere((event) => event['type'] == 'select');
      final selectionTrace = bimMap(
        (await _native(tester, () => _inspect(webview)))['pointer_events'],
      );
      expect(
        bimInt(selectionTrace['pointerdown']),
        greaterThan(bimInt(selectionTraceBefore['pointerdown'])),
      );
      expect(
        bimInt(selectionTrace['pointerup']),
        greaterThan(bimInt(selectionTraceBefore['pointerup'])),
      );
      report['native_input'] = {
        'source': 'Android input touchscreen',
        'cursor': cursorTrace,
        'selection': selectionTrace,
      };
      await _wait(
        tester,
        () async {
          final stored = await _native(
            tester,
            () => sessionApi.fetchSnapshots(sessionId),
          );
          return stored.any(
            (event) =>
                event.clientId == clientId &&
                event.type == 'select' &&
                event.payload['model_version_id'] == context.versionIds.first &&
                event.payload['element_id'] == expressId,
          );
        },
        'The server must persist the native selection with its model version.',
      );
      await _phase(tester, control, 'nativeSelectionSent', {
        'version_id': context.versionIds.first,
        'element_id': expressId,
        'sequence': selected['sequence'],
      });
      await _command(tester, control, 'late_join_ready');
      final snapshots = await _native(
        tester,
        () => sessionApi.fetchSnapshots(sessionId),
      );
      expect(
        snapshots.any(
          (event) => event.clientId == leaderClientId && event.type == 'select',
        ),
        isTrue,
      );
      expect(
        snapshots.any(
          (event) =>
              event.clientId == leaderClientId &&
              event.type == 'cursor' &&
              event.payload.isNotEmpty,
        ),
        isTrue,
      );
      final authBeforeJoin = audit.authResponses;
      await _native(tester, coordinator.leave);
      await _native(
        tester,
        () => coordinator.join(BimSessionSummary.fromJson(bootstrap)),
      );
      await _connected(tester, coordinator, errors);
      await _wait(
        tester,
        () async =>
            audit.authResponses > authBeforeJoin &&
            '${(await _native(tester, () => _inspect(webview)))['text']}'
                .contains(leader.name),
        'Late joining must reauthorize and display persisted latest cursor snapshots.',
      );
      await _phase(tester, control, 'rejoined', {
        'native_auth_count': audit.authResponses,
        'snapshot_types':
            snapshots
                .where((event) => event.clientId == leaderClientId)
                .map((event) => event.type)
                .toList(),
      });
      await _command(tester, control, 'reconnect_ready');
      final authBeforeReconnect = audit.authResponses;
      coordinator.setOnline(false);
      expect(coordinator.currentState.connection, BimSessionConnection.offline);
      await tester.pump(const Duration(milliseconds: 500));
      coordinator.setOnline(true);
      await _connected(tester, coordinator, errors);
      await _wait(
        tester,
        () async => audit.authResponses > authBeforeReconnect,
        'Reconnect must invoke native broadcasting auth again.',
      );
      expect(
        coordinator.currentState.participants.any(
          (participant) => participant.clientId == leaderClientId,
        ),
        isTrue,
      );
      await _phase(tester, control, 'reconnected', {
        'native_auth_count': audit.authResponses,
        'auth_count': audit.authResponses,
      });
      final nextCommand = await _command(tester, control, 'next_session');
      final nextId = bimInt(
        nextCommand['session_id'] ?? config['BIM_API_SESSION_NEXT_ID'],
      );
      expect(nextId, greaterThan(0));
      expect(nextId, isNot(sessionId));
      final nextBootstrap = await _native(
        tester,
        () => sessionApi.bootstrap(nextId, clientId: clientId),
      );
      expect(bimInt(nextBootstrap['model_set_revision_id']), revisionId);
      await _native(
        tester,
        () => coordinator.join(BimSessionSummary.fromJson(nextBootstrap)),
      );
      await _connected(tester, coordinator, errors);
      expect(
        audit.authRequests.last['channel_name'],
        'presence-design-model-session.$nextId',
      );
      final oldParticipants = await _native(
        tester,
        () => api.get<dynamic>(
          '/design-management/model-sessions/$sessionId/participants',
        ),
      );
      expect(
        (bimMap(oldParticipants.data)['data'] as List).any(
          (value) => bimMap(value)['client_id'] == clientId,
        ),
        isFalse,
      );
      await _phase(tester, control, 'sessionChanged', {
        'session_id': nextId,
        'client_id': clientId,
      });
      await _command(tester, control, 'finish');
      expect(errors, isEmpty);
      report['native_auth_responses'] = audit.authResponses;
      report['actual_short_event_count'] = received.length;
      report['native_event_types'] =
          audit.events.map((event) => event['type']).toSet().toList();
      report['complete_full_follow'] = true;
      report['late_join_snapshot'] = true;
      report['reconnect_and_session_change'] = true;
      await _native(tester, coordinator.leave);
      final leftSessionIds = [sessionId, nextId];
      for (final departedSessionId in leftSessionIds) {
        await _wait(
          tester,
          () async {
            final response = await _native(
              tester,
              () => api.get<dynamic>(
                '/design-management/model-sessions/$departedSessionId/participants',
              ),
            );
            final participants = MobileApiResponse.dataList(response.data);
            if (participants.any(
              (participant) => participant['client_id'] == clientId,
            )) {
              return false;
            }
            final snapshot = await _native(
              tester,
              () => sessionApi.fetchViewState(departedSessionId, clientId),
            );
            return snapshot == null;
          },
          'Native leave must remove its participant and view snapshot from session $departedSessionId.',
        );
      }
      final receivedTypes =
          received
              .where((event) => event.clientId != clientId)
              .map((event) => event.type)
              .toSet()
              .toList()
            ..sort();
      expect(
        receivedTypes,
        containsAll(['camera', 'cursor', 'select', 'view']),
      );
      report['second_session_id'] = nextId;
      report['left_session_ids'] = leftSessionIds;
      report['received_types'] = receivedTypes;
      report['checks'] = {
        'native_auth_bridge': audit.authResponses > 0,
        'jwt_not_in_js': sessionViewer.publicSessionStarts > 0,
        'complete_full_follow': true,
        'own_unfollow_preserved': true,
        'model_version_selection_deduplicated': true,
        'late_join_snapshot': true,
        'reconnect_and_session_change': true,
        'left_sessions_cleaned': true,
      };
      await _phase(tester, control, 'complete', report);
      await tester.pumpWidget(const SizedBox.shrink());
      debugPrint('BIM_SESSION_RESULT ${jsonEncode(report)}');
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}

Future<T> _native<T>(
  WidgetTester tester,
  Future<T> Function() action, {
  Duration timeout = const Duration(seconds: 60),
}) async {
  Object? error;
  StackTrace? trace;
  T? result;
  await tester.runAsync(() async {
    try {
      result = await action().timeout(timeout);
    } catch (caught, stack) {
      error = caught;
      trace = stack;
    }
  });
  if (error != null) Error.throwWithStackTrace(error!, trace!);
  return result as T;
}

Future<void> _wait(
  WidgetTester tester,
  Future<bool> Function() condition,
  String reason, {
  Duration timeout = const Duration(seconds: 180),
}) async {
  final watch = Stopwatch()..start();
  while (watch.elapsed < timeout) {
    final remaining = timeout - watch.elapsed;
    if (await condition().timeout(remaining)) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail(reason);
}

Future<void> _connected(
  WidgetTester tester,
  BimSessionCoordinator coordinator,
  List<String> errors,
) async {
  await _wait(
    tester,
    () async =>
        coordinator.currentState.connection == BimSessionConnection.connected ||
        coordinator.currentState.connection == BimSessionConnection.failed ||
        coordinator.currentState.error != null ||
        errors.isNotEmpty,
    'The native production realtime client must subscribe.',
  );
  expect(errors, isEmpty);
  expect(coordinator.currentState.error, isNull);
  expect(coordinator.currentState.connection, BimSessionConnection.connected);
}

Future<void> _phase(
  WidgetTester tester,
  _Control control,
  String phase,
  Map<String, dynamic> details,
) async {
  await _native(
    tester,
    () => control.phase(phase, details),
    timeout: const Duration(seconds: 180),
  );
  debugPrint('BIM_SESSION_PHASE $phase ${jsonEncode(details)}');
}

Map<String, int> _deviceInputCoordinates(WidgetTester tester) {
  final center = tester.getCenter(find.byType(WebViewWidget));
  final ratio = tester.view.devicePixelRatio;
  return {'x': (center.dx * ratio).round(), 'y': (center.dy * ratio).round()};
}

Future<Map<String, dynamic>> _command(
  WidgetTester tester,
  _Control control,
  String type, {
  Duration timeout = const Duration(seconds: 180),
}) async {
  Map<String, dynamic>? command;
  await _wait(
    tester,
    () async {
      Map<String, dynamic> status;
      try {
        status = await _native(tester, control.status);
      } on DioException catch (error) {
        if (_transientControlTimeout(error)) return false;
        rethrow;
      }
      for (final value in status['commands'] as List? ?? []) {
        final candidate = bimMap(value);
        if (candidate['type'] == type &&
            !control.consumed.contains('${candidate['id'] ?? type}')) {
          command = candidate;
          return true;
        }
      }
      await tester.pump(const Duration(milliseconds: 400));
      return false;
    },
    'Desktop control command $type must arrive within ${timeout.inSeconds} seconds.',
    timeout: timeout,
  );
  final result = command!;
  final id = '${result['id'] ?? type}';
  control.consumed.add(id);
  await _phase(tester, control, 'command_$id', {'type': type});
  return result;
}

bool _transientControlTimeout(DioException error) =>
    error.type == DioExceptionType.connectionTimeout ||
    error.type == DioExceptionType.receiveTimeout ||
    error.type == DioExceptionType.sendTimeout;

Future<Map<String, dynamic>> _configuration() async {
  const url = String.fromEnvironment('BIM_API_CONFIG_URL');
  if (url.isEmpty) {
    throw StateError('Prepare the signed BIM_API_CONFIG_URL test descriptor.');
  }
  expect(Uri.parse(url).host, '127.0.0.1');
  final dio = Dio();
  try {
    return bimMap((await dio.get<dynamic>(url)).data);
  } finally {
    dio.close(force: true);
  }
}

int _id(Map<String, dynamic> config, String name) {
  final id = bimInt(config['BIM_API_$name']);
  if (id <= 0) {
    throw StateError('Missing positive BIM_API_$name descriptor field.');
  }
  return id;
}

Dio _api(Map<String, dynamic> config) {
  final base = '${config['BIM_API_BASE_URL']}';
  expect(Uri.parse(base).host, '127.0.0.1');
  expect('${config['BIM_API_TOKEN']}', isNotEmpty);
  return Dio(
    BaseOptions(
      baseUrl: base,
      headers: {
        'Authorization': 'Bearer ${config['BIM_API_TOKEN']}',
        'Accept': 'application/json',
        'X-Organization-ID': '${config['BIM_API_ORGANIZATION_ID']}',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );
}

class _Control {
  _Control(this.url) {
    if (Uri.parse(url).host != '127.0.0.1') {
      throw StateError('Use the signed localhost test-only control endpoint.');
    }
  }
  final String url;
  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 45),
    ),
  );
  final consumed = <String>{};
  String? _pairRunId;
  Future<Map<String, dynamic>> status() async {
    final status = bimMap((await _dio.get<dynamic>(url)).data);
    final runId = status['run_id'];
    if (runId is! String || runId.isEmpty) {
      throw StateError(
        'The signed control response must contain its run UUID.',
      );
    }
    if (_pairRunId != null && _pairRunId != runId) {
      throw StateError(
        'The paired control run changed during the device test.',
      );
    }
    _pairRunId ??= runId;
    return status;
  }

  Future<void> phase(String name, Map<String, dynamic> details) async {
    if (_pairRunId == null) await status();
    final payload = {'actor': 'mobile', 'phase': name, ...details};
    try {
      await _dio.post<dynamic>(url, data: payload);
    } on DioException catch (error) {
      if (!_transientControlTimeout(error)) rethrow;
      await status();
      await _dio.post<dynamic>(url, data: payload);
    }
  }

  void close() => _dio.close(force: true);
}

class _AuditedSessionViewer extends BimRealtimeViewerAdapter {
  _AuditedSessionViewer(super.controller, this.token);
  final String token;
  int publicSessionStarts = 0;

  @override
  Future<Map<String, dynamic>> command(
    String type, [
    Map<String, dynamic> payload = const {},
  ]) {
    if (type == 'sessionStart') {
      expect(
        jsonEncode(payload).contains(token),
        isFalse,
        reason:
            'Native JWT must never be passed to the WebView JavaScript bridge.',
      );
      publicSessionStarts++;
    }
    return super.command(type, payload);
  }
}

class _Audit {
  _Audit(this.token);
  final String token;
  final authRequests = <Map<String, dynamic>>[];
  final events = <Map<String, dynamic>>[];
  int authResponses = 0;
  final authStatuses = <Map<String, dynamic>>[];
  late final interceptor = InterceptorsWrapper(
    onRequest: (options, handler) {
      if (options.path.endsWith('/broadcasting/auth')) {
        options.extra['_bimDeviceAuthClock'] = Stopwatch()..start();
        authRequests.add({
          'at_ms': DateTime.now().millisecondsSinceEpoch,
          'native_bearer':
              '${options.headers['Authorization']}' == 'Bearer $token',
          'channel_name': bimMap(options.data)['channel_name'],
        });
      }
      if (options.method == 'POST' && options.path.endsWith('/events')) {
        events.add(bimMap(options.data));
      }
      handler.next(options);
    },
    onResponse: (response, handler) {
      if (response.requestOptions.path.endsWith('/broadcasting/auth')) {
        authStatuses.add({
          'at_ms': DateTime.now().millisecondsSinceEpoch,
          'channel_name': bimMap(response.requestOptions.data)['channel_name'],
          'status_code': response.statusCode,
          'duration_ms':
              (response.requestOptions.extra['_bimDeviceAuthClock']
                      as Stopwatch?)
                  ?.elapsedMilliseconds,
        });
        if (authStatuses.length > 30) authStatuses.removeAt(0);
        if (response.statusCode == 200) authResponses++;
      }
      handler.next(response);
    },
    onError: (error, handler) {
      if (error.requestOptions.path.endsWith('/broadcasting/auth')) {
        authStatuses.add({
          'at_ms': DateTime.now().millisecondsSinceEpoch,
          'channel_name': bimMap(error.requestOptions.data)['channel_name'],
          'status_code': error.response?.statusCode,
          'duration_ms':
              (error.requestOptions.extra['_bimDeviceAuthClock'] as Stopwatch?)
                  ?.elapsedMilliseconds,
          'kind': error.type.name,
          'message': _safeDiagnostic(error.message),
        });
        if (authStatuses.length > 30) authStatuses.removeAt(0);
      }
      handler.next(error);
    },
  );
}

String? _safeDiagnostic(Object? value) {
  if (value == null) return null;
  final text = value
      .toString()
      .replaceAll(RegExp(r'https?://\S+'), '[url redacted]')
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[jwt redacted]',
      );
  return text.length <= 500 ? text : text.substring(0, 500);
}

Future<Map<String, dynamic>> _inspect(WebViewWidget widget) async {
  final raw = await widget.platform.params.controller
      .runJavaScriptReturningResult('''JSON.stringify((() => {
    const canvas = document.querySelector('canvas');
    const storage = [...Object.values(localStorage), ...Object.values(sessionStorage)].join(' ');
    const page = document.documentElement.outerHTML + storage;
    return {webgl2: !!canvas?.getContext('webgl2'), worker: typeof Worker,
      origin: location.origin, url_without_query: location.origin + location.pathname,
      jwt_in_page: /eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+/.test(page),
      text: document.body.innerText, width: canvas?.width, height: canvas?.height,
      pointer_events: {...(window.__mostBimSessionDeviceInput || {})},
      input_trace: [...(window.__mostBimSessionDeviceTrace || [])],
      raw_input_events: {...(window.__mostBimSessionRawInput || {})},
      raw_input_trace: [...(window.__mostBimSessionRawTrace || [])],
      canvas_rect: canvas ? (() => {const r=canvas.getBoundingClientRect(); return {x:r.x,y:r.y,width:r.width,height:r.height};})() : null,
      viewport_center_hit: (() => {const x=innerWidth/2,y=innerHeight/2,e=document.elementFromPoint(x,y),r=canvas?.getBoundingClientRect(); return {x,y,target:e ? {tag:e.tagName,id:(e.id||'').slice(0,120),class:(typeof e.className==='string'?e.className:'').slice(0,200)} : null,canvas_contains:!!(canvas&&r&&x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom)};})(),
      device_pixel_ratio: devicePixelRatio};
  })())''');
  dynamic decoded = raw;
  for (var i = 0; i < 3 && decoded is String; i++) {
    decoded = jsonDecode(decoded);
  }
  if (decoded is! Map) {
    throw const FormatException('WebView diagnostic must decode to an object.');
  }
  return bimMap(decoded);
}

Future<void> _cursorDiagnostic(
  WidgetTester tester,
  BimViewerController controller,
  WebViewWidget webview,
  _Audit audit,
  List<String> errors,
  Map<String, dynamic> report,
  String label,
) async {
  String safe(Object error) => _safeDiagnostic(error)!;
  final diagnostic = <String, dynamic>{
    'renderer_errors': errors.take(10).map(safe).toList(),
    'flutter_raw_input': report['flutter_raw_input'],
    'outgoing_events':
        audit.events.reversed.take(40).map((event) {
          final payload = bimMap(event['payload']);
          return {
            for (final key in ['type', 'sequence', 'client_id'])
              if (event.containsKey(key)) key: event[key],
            'payload': {
              for (final key in [
                'model_version_id',
                'element_id',
                'x',
                'y',
                'z',
                'position',
                'target',
                'up',
                'projection',
                'fov',
                'zoom',
              ])
                if (payload.containsKey(key)) key: payload[key],
            },
          };
        }).toList(),
  };
  final collection =
      (report['cursor_diagnostics'] ??= <String, dynamic>{}) as Map;
  collection[label] = diagnostic;
  try {
    diagnostic['view_state'] = await _native(tester, controller.getViewState);
    diagnostic['webview'] = await _native(tester, () => _inspect(webview));
    final png = await _native(tester, controller.captureSnapshot);
    final file = File(
      '${Directory.systemTemp.path}/bim-session-cursor-$label.png',
    );
    await _native(tester, () => file.writeAsBytes(png, flush: true));
    diagnostic['png_path'] = file.path;
    diagnostic['png_bytes'] = png.length;
  } catch (error) {
    diagnostic['capture_error'] = safe(error);
  }
  debugPrint('BIM_SESSION_CURSOR_DIAGNOSTIC $label ${jsonEncode(diagnostic)}');
}

Future<void> _observeDeviceInput(WebViewWidget widget) async {
  await widget.platform.params.controller.runJavaScript('''(() => {
    if (window.__mostBimSessionDeviceInput) return;
    const counts = window.__mostBimSessionDeviceInput = {};
    const trace = window.__mostBimSessionDeviceTrace = [];
    const rawCounts = window.__mostBimSessionRawInput = {};
    const rawTrace = window.__mostBimSessionRawTrace = [];
    for (const type of ['pointerdown', 'pointermove', 'pointerup', 'pointercancel', 'pointerleave', 'click',
      'touchstart', 'touchmove', 'touchend', 'touchcancel', 'mousedown', 'mousemove', 'mouseup']) {
      window.addEventListener(type, event => {
        if (!event.isTrusted) return;
        const target = event.target instanceof Element ? event.target : null;
        const point = event.changedTouches?.[0] || event.touches?.[0] || event;
        const item = {type, trusted:true,
          target:target ? {tag:target.tagName,id:(target.id||'').slice(0,120),class:(typeof target.className==='string'?target.className:'').slice(0,200)} : null,
          x:point.clientX,y:point.clientY,screen_x:point.screenX,screen_y:point.screenY,
          pointer_id:event.pointerId,pointer_type:event.pointerType,button:event.button,buttons:event.buttons};
        rawTrace.push(item);
        if (rawTrace.length>60) rawTrace.shift();
        rawCounts[type] = (rawCounts[type] || 0) + 1;
        if (type.startsWith('pointer')) trace.push(item);
        if (trace.length>60) trace.shift();
        if (event.pointerType !== 'touch') return;
        counts[type] = (counts[type] || 0) + 1;
      }, true);
    }
  })()''');
}

void _recordFlutterInput(
  String type,
  PointerEvent event,
  Map<String, int> counts,
  List<Map<String, dynamic>> trace,
) {
  counts[type] = (counts[type] ?? 0) + 1;
  trace.add({
    'type': type,
    'kind': event.kind.name,
    'x': double.parse(event.position.dx.toStringAsFixed(1)),
    'y': double.parse(event.position.dy.toStringAsFixed(1)),
  });
  if (trace.length > 60) trace.removeAt(0);
}

BimViewState _pickPose(
  BimViewState initial,
  List<int> versions,
  int expressId,
) {
  final state = bimMap(jsonDecode(jsonEncode(initial)));
  state['camera'] = {
    ...bimMap(initial['camera']),
    'position': [-35.26823, 3.35, -87.07903],
    'target': [-35.26823, 3.35, -97.07903],
    'up': [0, 1, 0],
    'projection': 'perspective',
    'fov': 50,
    'zoom': 1,
  };
  state['models'] = [
    for (final version in versions)
      {
        ..._modelStates(initial)['$version']!,
        'visible': version == versions.first,
        'hidden_element_ids': [],
        'isolated_element_ids': version == versions.first ? [expressId] : [],
        'transform': {
          'shift': version == versions.first ? [0, 0, 0] : [12, 0, 0],
          'rotation': 0,
        },
      },
  ];
  state['sections'] = [];
  state['selection'] = [];
  return state;
}

Map<String, Map<String, dynamic>> _modelStates(BimViewState state) => {
  for (final value in state['models'] as List)
    '${bimMap(value)['version_id']}': bimMap(value),
};

void _richState(BimViewState state, List<int> versions) {
  final camera = bimMap(state['camera']);
  expect(camera['projection'], 'orthographic');
  expect(camera['aspect'], isA<num>());
  expect(camera['zoom'], isNot(1));
  expect(camera['up'], isNot(equals([0, 1, 0])));
  final models = _modelStates(state);
  expect(models.keys, unorderedEquals(versions.map((id) => '$id')));
  expect(
    models.values.any(
      (model) => (model['hidden_element_ids'] as List? ?? []).isNotEmpty,
    ),
    isTrue,
  );
  expect(
    models.values.any((model) => bimMap(model['transform']).isNotEmpty),
    isTrue,
  );
  final selections = (state['selection'] as List).map(bimMap).toList();
  expect(selections, hasLength(2));
  expect(
    selections.map((selection) => '${selection['version_id']}'),
    unorderedEquals(versions.map((version) => '$version')),
  );
  final selectedElements =
      selections.map((selection) => bimInt(selection['element_id'])).toSet();
  expect(selectedElements, hasLength(1));
  expect(selectedElements.single, greaterThan(0));
  expect(state['sections'], isNotEmpty);
}

bool _sameState(Object? actual, Object? expected) =>
    _same(_portable(bimMap(actual)), _portable(bimMap(expected)));

Map<String, dynamic> _portable(BimViewState state) {
  final camera = bimMap(state['camera']);
  final modelStates = _modelStates(state);
  final orderedVersions = modelStates.keys.toList()..sort();
  return {
    'schema_version': state['schema_version'],
    'model_set_revision_id': '${state['model_set_revision_id']}',
    'camera': {
      for (final key in [
        'position',
        'target',
        'up',
        'projection',
        'fov',
        'zoom',
        'aspect',
      ])
        key: camera[key],
    },
    'models': [
      for (final version in orderedVersions)
        {
          for (final key in [
            'version_id',
            'transform',
            'visible',
            'hidden_element_ids',
            'isolated_element_ids',
          ])
            key: modelStates[version]![key],
        },
    ],
    'selection': state['selection'],
    'sections': state['sections'],
  };
}

bool _same(Object? actual, Object? expected) {
  if (actual is num && expected is num) return (actual - expected).abs() < 0.01;
  if (actual is Map && expected is Map) {
    return actual.length == expected.length &&
        expected.keys.every(
          (key) => actual.containsKey(key) && _same(actual[key], expected[key]),
        );
  }
  if (actual is List && expected is List) {
    return actual.length == expected.length &&
        List.generate(
          actual.length,
          (index) => index,
        ).every((index) => _same(actual[index], expected[index]));
  }
  return actual == expected;
}
