import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  factory ApiException.fromDio(
    DioException error, {
    String fallbackMessage = 'Не удалось выполнить запрос.',
  }) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'];
      if (message is String && message.trim().isNotEmpty) {
        return ApiException(message.trim(), statusCode: statusCode);
      }

      final errors = responseData['errors'];
      final nestedMessage = _extractNestedMessage(errors);
      if (nestedMessage != null) {
        return ApiException(nestedMessage, statusCode: statusCode);
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

  @override
  String toString() => message;
}
