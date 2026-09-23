class PushDeviceRegistration {
  const PushDeviceRegistration({
    required this.installationId,
    required this.platform,
    required this.provider,
    required this.token,
  });

  final String installationId;
  final String platform;
  final String provider;
  final String token;

  Map<String, String> toJson() => {
    'installation_id': installationId,
    'platform': platform,
    'provider': provider,
    'token': token,
  };
}
