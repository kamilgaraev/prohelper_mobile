import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';

void main() {
  test('normalizes unauthenticated server message with punctuation', () {
    final exception = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(
          path: '/mobile/workforce/attendance/self',
        ),
        response: Response<dynamic>(
          requestOptions: RequestOptions(
            path: '/mobile/workforce/attendance/self',
          ),
          statusCode: 401,
          data: const <String, dynamic>{'message': 'Unauthenticated.'},
        ),
        type: DioExceptionType.badResponse,
      ),
    );

    expect(exception.message, 'Сессия истекла. Выполните вход заново.');
  });

  test('explains certificate failures caused by incorrect device date', () {
    final exception = ApiException.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/auth/login'),
        type: DioExceptionType.unknown,
        error: const HandshakeException(
          'CERTIFICATE_VERIFY_FAILED: certificate is not yet valid',
        ),
      ),
      fallbackMessage: 'Не удалось выполнить вход.',
    );

    expect(
      exception.message,
      'Проверьте дату и время на устройстве, затем повторите вход.',
    );
  });
}
