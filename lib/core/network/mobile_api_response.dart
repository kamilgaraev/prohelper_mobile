class MobileApiResponse<T> {
  const MobileApiResponse({
    required this.success,
    required this.data,
    required this.message,
    required this.meta,
  });

  final bool success;
  final T data;
  final String? message;
  final Map<String, dynamic> meta;

  static MobileApiResponse<Map<String, dynamic>> map(dynamic responseData) {
    final root = _asMap(responseData);
    final data = _payload(responseData);

    return MobileApiResponse<Map<String, dynamic>>(
      success: root['success'] == true,
      data: _asMap(data),
      message: root['message'] as String?,
      meta: _meta(root, data),
    );
  }

  static MobileApiResponse<List<Map<String, dynamic>>> list(
    dynamic responseData,
  ) {
    final root = _asMap(responseData);
    final payload = _payload(responseData);
    final listPayload = _listPayload(payload);

    return MobileApiResponse<List<Map<String, dynamic>>>(
      success: root['success'] == true,
      data: _asMapList(listPayload),
      message: root['message'] as String?,
      meta: _meta(root, payload),
    );
  }

  static dynamic payload(dynamic responseData) {
    return _payload(responseData);
  }

  static Map<String, dynamic> dataMap(dynamic responseData) {
    return map(responseData).data;
  }

  static List<Map<String, dynamic>> dataList(dynamic responseData) {
    return list(responseData).data;
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }

    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, entry) => MapEntry(key.toString(), entry)),
        )
        .toList(growable: false);
  }

  static dynamic _payload(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('data')) {
      return responseData['data'];
    }

    if (responseData is Map && responseData.containsKey('data')) {
      return responseData['data'];
    }

    return responseData;
  }

  static dynamic _listPayload(dynamic payload) {
    final payloadMap = _asMap(payload);

    if (payloadMap['data'] is List) {
      return payloadMap['data'];
    }

    if (payloadMap['items'] is List) {
      return payloadMap['items'];
    }

    return payload;
  }

  static Map<String, dynamic> _meta(
    Map<String, dynamic> root,
    dynamic payload,
  ) {
    final rootMeta = _asMap(root['meta']);

    if (rootMeta.isNotEmpty) {
      return rootMeta;
    }

    final payloadMeta = _asMap(payload);

    if (payloadMeta.isEmpty) {
      return const <String, dynamic>{};
    }

    final meta =
        Map<String, dynamic>.from(payloadMeta)
          ..remove('data')
          ..remove('items');

    return meta;
  }
}
