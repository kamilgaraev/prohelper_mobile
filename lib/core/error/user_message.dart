import 'package:prohelpers_mobile/core/network/api_exception.dart';

class UserMessage {
  const UserMessage._();

  static String fromError(Object error) {
    if (error is ApiException && error.message.trim().isNotEmpty) {
      return _clean(error.message);
    }

    final raw = error.toString();
    if (_containsTechnicalText(raw)) {
      return 'Не удалось выполнить действие. Попробуйте еще раз.';
    }

    final cleaned = _clean(raw);
    if (cleaned.isEmpty || _containsTechnicalText(cleaned)) {
      return 'Не удалось выполнить действие. Попробуйте еще раз.';
    }

    return cleaned;
  }

  static bool _containsTechnicalText(String value) {
    final normalized = value.toLowerCase();

    return normalized.contains('apiexception') ||
        normalized.contains('formatexception') ||
        normalized.contains('dioexception') ||
        normalized.contains('payload') ||
        normalized.contains('fallback') ||
        normalized.contains('legacy') ||
        normalized.contains('constraint') ||
        normalized.contains('sql');
  }

  static String _clean(String value) {
    return value
        .replaceFirst('ApiException: ', '')
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
  }
}
