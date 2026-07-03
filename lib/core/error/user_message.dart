import 'package:prohelpers_mobile/core/network/api_exception.dart';

class UserMessage {
  const UserMessage._();

  static const _genericMessage =
      'Не удалось выполнить действие. Попробуйте еще раз.';
  static const _sessionExpiredMessage =
      'Сессия истекла. Выполните вход заново.';

  static String fromError(Object error) {
    if (error is ApiException &&
        error.statusCode == 401 &&
        _isRawAuthMessage(error.message)) {
      return _sessionExpiredMessage;
    }

    if (error is ApiException && error.message.trim().isNotEmpty) {
      return _cleanOrFallback(error.message);
    }

    return _cleanOrFallback(error.toString());
  }

  static String _cleanOrFallback(String raw) {
    final cleaned = _clean(raw);
    if (cleaned.isEmpty || _containsTechnicalText(cleaned)) {
      return _genericMessage;
    }

    return cleaned;
  }

  static bool _containsTechnicalText(String value) {
    final normalized = value.toLowerCase();

    return normalized.contains('apiexception') ||
        normalized.contains('formatexception') ||
        normalized.contains('dioexception') ||
        normalized.contains('exception:') ||
        normalized.contains('payload') ||
        normalized.contains('fallback') ||
        normalized.contains('legacy') ||
        normalized.contains('constraint') ||
        normalized.contains('sql') ||
        normalized.contains('stack trace') ||
        normalized.contains('stacktrace') ||
        normalized.contains('statuscode') ||
        normalized.contains('status code') ||
        normalized.contains('unauthenticated') ||
        normalized.contains('unauthorized') ||
        normalized.contains('not authorized') ||
        normalized.contains('endpoint') ||
        normalized.contains('http ') ||
        normalized.contains('null') ||
        normalized.contains('undefined') ||
        normalized.contains('is not a subtype') ||
        normalized.contains('nosuchmethoderror') ||
        normalized.contains('typeerror');
  }

  static bool _isRawAuthMessage(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s.!?]+$'),
      '',
    );

    return normalized == 'unauthenticated' ||
        normalized == 'unauthorized' ||
        normalized == 'not authorized';
  }

  static String _clean(String value) {
    return value
        .replaceFirst('ApiException: ', '')
        .replaceFirst('FormatException: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
  }
}
