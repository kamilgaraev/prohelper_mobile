typedef BimViewState = Map<String, dynamic>;

class BimSessionSummary {
  const BimSessionSummary({
    required this.id,
    required this.name,
    required this.modelSetRevisionId,
    this.status = 'active',
  });

  final int id;
  final String name;
  final int modelSetRevisionId;
  final String status;

  factory BimSessionSummary.fromJson(Map<String, dynamic> json) =>
      BimSessionSummary(
        id: bimInt(json['id']),
        name:
            (json['name'] ?? json['title'] ?? 'Совместный просмотр').toString(),
        modelSetRevisionId: bimInt(json['model_set_revision_id']),
        status: (json['status'] ?? 'active').toString(),
      );
}

class BimParticipant {
  const BimParticipant({
    required this.clientId,
    required this.userId,
    required this.name,
    this.color = '#3b82f6',
    this.lastSeenAt,
    this.maxSequence,
  });

  final String clientId;
  final int userId;
  final String name;
  final String color;
  final DateTime? lastSeenAt;
  final int? maxSequence;

  factory BimParticipant.fromJson(Map<String, dynamic> json) {
    final user = bimMap(json['user'] ?? json['sender']);
    return BimParticipant(
      clientId: (json['client_id'] ?? '').toString(),
      userId: bimInt(json['user_id'] ?? user['id'] ?? json['id']),
      name: (json['name'] ?? user['name'] ?? 'Участник').toString(),
      color: (json['color'] ?? user['color'] ?? '#3b82f6').toString(),
      lastSeenAt: DateTime.tryParse((json['last_seen_at'] ?? '').toString()),
      maxSequence:
          json['max_sequence'] == null ? null : bimInt(json['max_sequence']),
    );
  }
}

class BimPresenceEnvelope {
  const BimPresenceEnvelope({
    required this.sessionId,
    required this.modelSetRevisionId,
    required this.clientId,
    required this.sequence,
    required this.type,
    required this.senderId,
    required this.senderName,
    this.senderColor,
    required this.occurredAt,
    required this.payload,
  });

  final int sessionId;
  final int modelSetRevisionId;
  final String clientId;
  final int sequence;
  final String type;
  final int senderId;
  final String senderName;
  final String? senderColor;
  final DateTime occurredAt;
  final Map<String, dynamic> payload;

  static BimPresenceEnvelope? tryParse(Object? value) {
    final json = bimMap(value);
    final sender = bimMap(json['sender']);
    final clientId = (json['client_id'] ?? '').toString();
    final type = (json['type'] ?? '').toString();
    if (bimInt(json['schema_version']) != 2 ||
        clientId.isEmpty ||
        !const {
          'camera',
          'cursor',
          'select',
          'view',
          'heartbeat',
          'leave',
        }.contains(type) ||
        bimInt(json['sequence']) < 1) {
      return null;
    }
    return BimPresenceEnvelope(
      sessionId: bimInt(json['session_id']),
      modelSetRevisionId: bimInt(json['model_set_revision_id']),
      clientId: clientId,
      sequence: bimInt(json['sequence']),
      type: type,
      senderId: bimInt(sender['id']),
      senderName: (sender['name'] ?? 'Участник').toString(),
      senderColor: sender['color']?.toString(),
      occurredAt:
          DateTime.tryParse((json['occurred_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      payload: bimMap(json['payload']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': 2,
    'session_id': sessionId,
    'model_set_revision_id': modelSetRevisionId,
    'sender': {
      'id': senderId,
      'name': senderName,
      if (senderColor != null) 'color': senderColor,
    },
    'client_id': clientId,
    'sequence': sequence,
    'type': type,
    'occurred_at': occurredAt.toUtc().toIso8601String(),
    'payload': payload,
  };
}

enum BimSessionConnection {
  idle,
  joining,
  connected,
  reconnecting,
  offline,
  failed,
}

class BimSessionState {
  const BimSessionState({
    this.session,
    this.connection = BimSessionConnection.idle,
    this.participants = const [],
    this.followingClientId,
    this.followLoading = false,
    this.notice,
    this.error,
  });

  final BimSessionSummary? session;
  final BimSessionConnection connection;
  final List<BimParticipant> participants;
  final String? followingClientId;
  final bool followLoading;
  final String? notice;
  final Object? error;

  BimSessionState copyWith({
    BimSessionConnection? connection,
    List<BimParticipant>? participants,
    String? followingClientId,
    bool clearFollow = false,
    bool? followLoading,
    String? notice,
    Object? error,
    bool clearError = false,
  }) => BimSessionState(
    session: session,
    connection: connection ?? this.connection,
    participants: participants ?? this.participants,
    followingClientId:
        clearFollow ? null : followingClientId ?? this.followingClientId,
    followLoading: followLoading ?? this.followLoading,
    notice: notice ?? this.notice,
    error: clearError ? null : error ?? this.error,
  );
}

abstract interface class BimSessionApi {
  Future<Map<String, dynamic>> bootstrap(
    int sessionId, {
    required String clientId,
  });
  Future<void> sendEvent(int sessionId, Map<String, dynamic> envelope);
  Future<List<BimParticipant>> heartbeat(
    int sessionId, {
    required String clientId,
    required int sequence,
  });
  Future<List<BimPresenceEnvelope>> fetchSnapshots(int sessionId);
  Future<void> publishViewState(
    int sessionId,
    String clientId,
    int sequence,
    BimViewState viewState,
  );
  Future<BimViewState?> fetchViewState(int sessionId, String clientId);
  Future<void> leave(
    int sessionId, {
    required String clientId,
    required int sequence,
  });
}

Map<String, dynamic> bimMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
int bimInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
