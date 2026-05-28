import 'package:flutter_test/flutter_test.dart';
import 'package:prohelpers_mobile/core/error/user_message.dart';
import 'package:prohelpers_mobile/core/network/api_exception.dart';

void main() {
  test('user message hides technical exception names', () {
    expect(
      UserMessage.fromError(const ApiException('Не удалось открыть раздел.')),
      'Не удалось открыть раздел.',
    );

    expect(
      UserMessage.fromError(
        Exception('ApiException: FormatException: broken payload'),
      ),
      'Не удалось выполнить действие. Попробуйте еще раз.',
    );
  });
}
