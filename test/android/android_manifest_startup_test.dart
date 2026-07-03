import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android startup disables Impeller renderer explicitly', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(manifest.existsSync(), isTrue);

    final content = manifest.readAsStringSync();

    expect(
      content,
      contains('android:name="io.flutter.embedding.android.EnableImpeller"'),
    );
    expect(content, contains('android:value="false"'));
  });

  test('Android startup uses branded splash resources', () {
    final mainActivity = File(
      'android/app/src/main/kotlin/ru/prohelper/prohelpers_mobile/MainActivity.kt',
    );
    final launchBackground = File(
      'android/app/src/main/res/drawable/launch_background.xml',
    );
    final launchBackgroundV21 = File(
      'android/app/src/main/res/drawable-v21/launch_background.xml',
    );
    final splashIcon = File(
      'android/app/src/main/res/drawable/splash_icon.xml',
    );
    final android12Styles = File(
      'android/app/src/main/res/values-v31/styles.xml',
    );
    final android12NightStyles = File(
      'android/app/src/main/res/values-night-v31/styles.xml',
    );
    final colors = File('android/app/src/main/res/values/colors.xml');
    final nightColors = File(
      'android/app/src/main/res/values-night/colors.xml',
    );

    expect(mainActivity.existsSync(), isTrue);
    expect(launchBackground.existsSync(), isTrue);
    expect(launchBackgroundV21.existsSync(), isTrue);
    expect(splashIcon.existsSync(), isTrue);
    expect(android12Styles.existsSync(), isTrue);
    expect(android12NightStyles.existsSync(), isTrue);
    expect(colors.existsSync(), isTrue);
    expect(nightColors.existsSync(), isTrue);

    final mainActivityContent = mainActivity.readAsStringSync();
    expect(
      mainActivityContent,
      contains('splashScreen.setOnExitAnimationListener'),
    );
    expect(mainActivityContent, contains('splashScreenView.remove()'));

    for (final file in [launchBackground, launchBackgroundV21]) {
      final content = file.readAsStringSync();
      expect(content, contains('@color/most_splash_background'));
      expect(content, contains('@drawable/splash_icon'));
      expect(content, isNot(contains('@mipmap/ic_launcher')));
      expect(content, isNot(contains('@mipmap/launch_image')));
    }

    final splashIconContent = splashIcon.readAsStringSync();
    expect(splashIconContent, contains('android:viewportWidth="209"'));
    expect(splashIconContent, contains('android:viewportHeight="209"'));
    expect(splashIconContent, isNot(contains('@mipmap/ic_launcher')));

    final android12Content = android12Styles.readAsStringSync();
    expect(android12Content, contains('android:windowSplashScreenBackground'));
    expect(
      android12Content,
      contains('android:windowSplashScreenAnimatedIcon'),
    );
    expect(android12Content, contains('@drawable/splash_icon'));
    expect(android12Content, isNot(contains('@mipmap/ic_launcher')));

    final android12NightContent = android12NightStyles.readAsStringSync();
    expect(
      android12NightContent,
      contains('@android:style/Theme.Black.NoTitleBar'),
    );
    expect(
      android12NightContent,
      contains('android:windowSplashScreenBackground'),
    );
    expect(
      android12NightContent,
      contains('android:windowSplashScreenAnimatedIcon'),
    );
    expect(android12NightContent, contains('@drawable/splash_icon'));
    expect(android12NightContent, isNot(contains('@mipmap/ic_launcher')));
  });
}
