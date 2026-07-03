import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile UI strings and fixtures do not contain mojibake markers', () {
    final roots = [Directory('lib'), Directory('test')];
    final offenders = <String>[];

    for (final root in roots.where((root) => root.existsSync())) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }

        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          final line = lines[index];
          if (_containsMojibakeMarker(line)) {
            offenders.add('${entity.path}:${index + 1}: $line');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.take(40).join('\n'));
  });
}

bool _containsMojibakeMarker(String line) {
  final runes = line.runes.toList(growable: false);
  for (var index = 0; index < runes.length - 1; index += 1) {
    final current = runes[index];
    final next = runes[index + 1];

    if ((current == 0x0420 || current == 0x0421) && _isMojibakeFollower(next)) {
      return true;
    }

    if (current == 0x0432 && next >= 0x0400 && next <= 0x040f) {
      return true;
    }
  }

  return line.contains(String.fromCharCode(0xfffd));
}

bool _isMojibakeFollower(int codePoint) {
  return (codePoint >= 0x0080 && codePoint <= 0x00bf) ||
      (codePoint >= 0x0400 && codePoint <= 0x040f) ||
      (codePoint >= 0x0450 && codePoint <= 0x045f) ||
      (codePoint >= 0x2010 && codePoint <= 0x202f);
}
