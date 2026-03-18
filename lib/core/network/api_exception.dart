import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(
    DioException error, {
    String fallbackMessage = 'Не удалось выполнить запрос.',
  }) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return ApiException(
          _normalizeServerMessage(message.trim(), statusCode, fallbackMessage),
          statusCode: statusCode,
        );
      }

      final errors = responseData['errors'];
      final nestedMessage = _extractNestedMessage(errors);
      if (nestedMessage != null) {
        return ApiException(
          _normalizeServerMessage(nestedMessage, statusCode, fallbackMessage),
          statusCode: statusCode,
        );
      }
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'Сервер не ответил вовремя. Попробуйте еще раз.',
      DioExceptionType.connectionError =>
        'Нет соединения с сервером. Проверьте интернет.',
      DioExceptionType.badCertificate =>
        'Не удалось установить защищенное соединение.',
      DioExceptionType.cancel => 'Запрос был отменен.',
      _ => _fallbackByStatus(statusCode, fallbackMessage),
    };

    return ApiException(message, statusCode: statusCode);
  }

  static String? _extractNestedMessage(dynamic errors) {
    if (errors is Map) {
      for (final value in errors.values) {
        final message = _extractNestedMessage(value);
        if (message != null) {
          return message;
        }
      }
    }

    if (errors is List) {
      for (final value in errors) {
        final message = _extractNestedMessage(value);
        if (message != null) {
          return message;
        }
      }
    }

    if (errors is String && errors.trim().isNotEmpty) {
      return errors.trim();
    }

    return null;
  }

  static String _fallbackByStatus(int? statusCode, String fallbackMessage) {
    return switch (statusCode) {
      400 => 'Запрос содержит некорректные данные.',
      401 => 'Сессия истекла. Выполните вход заново.',
      403 => 'Недостаточно прав для этого действия.',
      404 => 'Данные не найдены.',
      422 => 'Проверьте введенные данные.',
      500 => 'На сервере произошла ошибка. Попробуйте позже.',
      _ => fallbackMessage,
    };
  }

  static String _normalizeServerMessage(
    String message,
    int? statusCode,
    String fallbackMessage,
  ) {
    final normalized = message.trim();

    if (normalized.isEmpty) {
      return _fallbackByStatus(statusCode, fallbackMessage);
    }

    if (!normalized.startsWith('ai_assistant.')) {
      return normalized;
    }

    return switch (normalized) {
      'ai_assistant.access_denied' =>
        'Недостаточно прав для работы с AI-ассистентом.',
      'ai_assistant.limit_exceeded' =>
        'Исчерпан месячный лимит запросов к AI-ассистенту.',
      'ai_assistant.request_failed' =>
        'Не удалось выполнить запрос к AI-ассистенту.',
      'ai_assistant.unauthorized' => 'Пользователь не авторизован.',
      'ai_assistant.organization_not_found' =>
        'Организация для AI-ассистента не найдена.',
      'ai_assistant.conversation_not_found' =>
        'Диалог не найден или недоступен.',
      'ai_assistant.load_conversations_failed' =>
        'Не удалось загрузить список диалогов.',
      'ai_assistant.load_conversation_failed' =>
        'Не удалось загрузить диалог.',
      'ai_assistant.delete_conversation_failed' =>
        'Не удалось удалить диалог.',
      'ai_assistant.usage_failed' =>
        'Не удалось получить статистику использования AI-ассистента.',
      _ => _fallbackByStatus(statusCode, fallbackMessage),
    };
  }

  @override
  String toString() => message;
}
