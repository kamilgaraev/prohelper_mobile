import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

final class MostLocalizations {
  const MostLocalizations._();

  static const ru = Locale('ru', 'RU');

  static const supportedLocales = <Locale>[ru];

  static const delegates = <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
}
