import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/error/user_message.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';

void main() {
  test('user message preserves readable business text', () {
    expect(
      UserMessage.fromError(const ApiException('Email или пароль не подошли.')),
      'Email или пароль не подошли.',
    );
    expect(
      UserMessage.fromError(
        const ApiException(
          'Email или пароль не подошли. Проверьте данные и попробуйте еще раз.',
          statusCode: 401,
        ),
      ),
      'Email или пароль не подошли. Проверьте данные и попробуйте еще раз.',
    );

    expect(
      UserMessage.fromError(
        Exception('FormatException: Проверьте заполненные поля.'),
      ),
      'Проверьте заполненные поля.',
    );
  });

  test('user message hides technical diagnostics', () {
    const generic = 'Не удалось выполнить действие. Попробуйте еще раз.';
    const sessionExpired = 'Сессия истекла. Выполните вход заново.';

    expect(
      UserMessage.fromError(
        Exception('ApiException: FormatException: broken payload'),
      ),
      generic,
    );
    expect(
      UserMessage.fromError(
        const ApiException('SQL constraint violation on endpoint /tasks'),
      ),
      generic,
    );
    expect(
      UserMessage.fromError(
        const ApiException('Unauthenticated.', statusCode: 401),
      ),
      sessionExpired,
    );
    expect(
      UserMessage.fromError(
        Exception(
          "type '_Map<String, dynamic>' is not a subtype of type 'List<dynamic>'",
        ),
      ),
      generic,
    );
  });

  test('user-facing layers do not expose raw error strings', () {
    final violations = <String>[];
    final forbiddenFragments = <String>[
      'error.toString()',
      'snapshot.error.toString()',
      'snapshot.error?.toString()',
      ".replaceFirst('ApiException: '",
      '.replaceFirst("ApiException: "',
      ".replaceFirst('FormatException: '",
      '.replaceFirst("FormatException: "',
    ];

    for (final file in _userFacingDartFiles()) {
      final source = file.readAsStringSync();
      for (final fragment in forbiddenFragments) {
        if (source.contains(fragment)) {
          violations.add('${file.path}: $fragment');
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<File> _userFacingDartFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .where((file) => !file.path.endsWith('.g.dart'))
      .where((file) {
        final path = file.path.replaceAll('\\', '/');
        return path.contains('/presentation/') ||
            path.contains('/domain/') ||
            path.contains('/core/providers/');
      });
}
