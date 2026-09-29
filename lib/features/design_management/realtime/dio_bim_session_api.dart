import 'package:dio/dio.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/mobile_api_response.dart';
import 'bim_session_models.dart';

final bimSessionApiProvider = Provider<DioBimSessionApi>(
  (ref) => DioBimSessionApi(ref.read(dioProvider)),
);

class BimSessionPage {
  const BimSessionPage({required this.sessions, required this.canCreate});

  final List<BimSessionSummary> sessions;
  final bool canCreate;
}

class DioBimSessionApi implements BimSessionApi {
  DioBimSessionApi(this._dio);

  final Dio _dio;
  static const _path = '/design-management/model-sessions';

  Future<BimSessionPage> listSessions(int projectId, int revisionId) async {
    return _request(() async {
      final sessions = <BimSessionSummary>[];
      var page = 1;
      var lastPage = 1;
      var canCreate = false;
      do {
        final response = await _dio.get(
          _path,
          queryParameters: {
            'project_id': projectId,
            'per_page': 100,
            'page': page,
          },
        );
        final envelope = MobileApiResponse.list(response.data);
        final actions = envelope.meta['available_actions'];
        if (page == 1) {
          canCreate =
              actions is List &&
              actions.any((value) {
                final action = bimMap(value);
                return action['key'] == 'create' && action['enabled'] == true;
              });
        }
        sessions.addAll(envelope.data.map(BimSessionSummary.fromJson));
        lastPage = bimInt(envelope.meta['last_page']);
        ++page;
      } while (page <= lastPage);
      return BimSessionPage(
        sessions:
            sessions
                .where(
                  (session) =>
                      session.modelSetRevisionId == revisionId &&
                      session.status != 'closed',
                )
                .toList(),
        canCreate: canCreate,
      );
    });
  }

  Future<BimSessionSummary> createSession({
    required int projectId,
    required int modelSetRevisionId,
    required String title,
  }) async {
    return _request(() async {
      final response = await _dio.post(
        _path,
        data: {
          'project_id': projectId,
          'model_set_revision_id': modelSetRevisionId,
          'title': title,
        },
      );
      return BimSessionSummary.fromJson(
        MobileApiResponse.dataMap(response.data),
      );
    });
  }

  @override
  Future<Map<String, dynamic>> bootstrap(
    int sessionId, {
    required String clientId,
  }) => _request(() async {
    final response = await _dio.get('$_path/$sessionId/bootstrap');
    return MobileApiResponse.dataMap(response.data);
  });

  @override
  Future<void> sendEvent(int sessionId, Map<String, dynamic> envelope) =>
      _request(() async {
        await _dio.post(
          '$_path/$sessionId/events',
          data: {
            'schema_version': 2,
            'client_id': envelope['client_id'],
            'sequence': envelope['sequence'],
            'type': envelope['type'],
            'payload': envelope['payload'],
          },
        );
      });

  Future<List<Map<String, dynamic>>> _participants(int sessionId) =>
      _request(() async {
        final response = await _dio.get('$_path/$sessionId/participants');
        return MobileApiResponse.list(
          response.data,
        ).data.map((value) => bimMap(value)).toList();
      });

  @override
  Future<List<BimParticipant>> heartbeat(
    int sessionId, {
    required String clientId,
    required int sequence,
  }) async {
    await sendEvent(sessionId, {
      'client_id': clientId,
      'sequence': sequence,
      'type': 'heartbeat',
      'payload': null,
    });
    final participants = await _participants(sessionId);
    return participants.map(BimParticipant.fromJson).toList();
  }

  @override
  Future<List<BimPresenceEnvelope>> fetchSnapshots(int sessionId) async {
    final participants = await _participants(sessionId);
    return [
      for (final participant in participants)
        for (final raw in bimMap(participant['latest_events']).values)
          if (BimPresenceEnvelope.tryParse(raw) case final event?) event,
    ];
  }

  @override
  Future<void> publishViewState(
    int sessionId,
    String clientId,
    int sequence,
    BimViewState viewState,
  ) => _request(() async {
    await _dio.post(
      '$_path/$sessionId/view-state',
      data: {
        'client_id': clientId,
        'sequence': sequence,
        'view_state': viewState,
      },
    );
  });

  @override
  Future<BimViewState?> fetchViewState(int sessionId, String clientId) =>
      _request(() async {
        final response = await _dio.get(
          '$_path/$sessionId/view-state',
          queryParameters: {'client_id': clientId},
        );
        final data = bimMap(bimMap(response.data)['data']);
        if (data.isEmpty) return null;
        return bimMap(data['view_state']);
      });

  @override
  Future<void> leave(
    int sessionId, {
    required String clientId,
    required int sequence,
  }) => sendEvent(sessionId, {
    'client_id': clientId,
    'sequence': sequence,
    'type': 'leave',
    'payload': null,
  });

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
