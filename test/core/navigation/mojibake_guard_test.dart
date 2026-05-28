import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile UI strings do not contain mojibake markers', () {
    final root = Directory('lib');
    final pattern = RegExp(r'[РС][\u0080-\u00BF]|вЂ|Рџ|Рќ|Р”|Р|СЃ|СЂ|С‚');
    final offenders = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }

      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index += 1) {
        final line = lines[index];
        if (pattern.hasMatch(line)) {
          offenders.add('${entity.path}:${index + 1}: $line');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.take(40).join('\n'));
  });
}
