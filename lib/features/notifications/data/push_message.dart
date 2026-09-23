class PushMessage {
  const PushMessage({required this.data, this.messageId});

  factory PushMessage.fromData({required Object? rawData, String? messageId}) {
    final data = <String, dynamic>{};
    if (rawData is Map) {
      for (final entry in rawData.entries) {
        if (entry.key != null && entry.value != null) {
          data[entry.key.toString()] = entry.value;
        }
      }
    }
    return PushMessage(data: data, messageId: messageId);
  }

  final String? messageId;
  final Map<String, dynamic> data;
}
