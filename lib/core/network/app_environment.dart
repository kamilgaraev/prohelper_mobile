class AppEnvironment {
  const AppEnvironment._();

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.1мост.рф/api/v1/mobile',
  );
}
