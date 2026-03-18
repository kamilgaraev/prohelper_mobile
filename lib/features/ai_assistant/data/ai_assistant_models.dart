class AiUsageModel {
  const AiUsageModel({
    required this.monthlyLimit,
    required this.used,
    required this.remaining,
    required this.percentageUsed,
  });

  final int monthlyLimit;
  final int used;
  final int remaining;
  final double percentageUsed;

  factory AiUsageModel.fromJson(Map<String, dynamic> json) {
    return AiUsageModel(
      monthlyLimit: _intValue(json['monthly_limit']),
      used: _intValue(json['used']),
      remaining: _intValue(json['remaining']),
      percentageUsed: _doubleValue(json['percentage_used']),
    );
  }
}

class AiConversationModel {
  const AiConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.messagesCount = 0,
  });

  final int id;
  final String title;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int messagesCount;

  factory AiConversationModel.fromJson(Map<String, dynamic> json) {
    return AiConversationModel(
      id: _intValue(json['id']),
      title: (json['title'] as String? ?? '').trim(),
      createdAt: _dateTimeValue(json['created_at']),
      updatedAt: _dateTimeValue(json['updated_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageAt: _dateTimeValue(json['last_message_at']),
      messagesCount: _intValue(json['messages_count']),
    );
  }
}

class AiMessageModel {
  const AiMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  final int id;
  final String role;
  final String content;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  factory AiMessageModel.fromJson(Map<String, dynamic> json) {
    return AiMessageModel(
      id: _intValue(json['id']),
      role: (json['role'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? '').trim(),
      createdAt: _dateTimeValue(json['created_at']),
    );
  }
}

class AiConversationDetailsModel {
  const AiConversationDetailsModel({
    required this.conversation,
    required this.messages,
  });

  final AiConversationModel conversation;
  final List<AiMessageModel> messages;
}

class AiAssistantHomeModel {
  const AiAssistantHomeModel({
    required this.usage,
    required this.conversations,
  });

  final AiUsageModel usage;
  final List<AiConversationModel> conversations;
}

int _intValue(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _dateTimeValue(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(raw);
}
