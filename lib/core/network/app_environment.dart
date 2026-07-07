class AppEnvironment {
  const AppEnvironment._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.xn--1-xtbgmf.xn--p1ai/api/v1/mobile',
  );
}
