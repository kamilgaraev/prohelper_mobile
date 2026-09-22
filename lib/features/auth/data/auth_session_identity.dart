class AuthSessionIdentity {
  const AuthSessionIdentity({
    required this.userId,
    required this.organizationId,
    required this.sessionId,
  });

  final int userId;
  final int? organizationId;
  final String sessionId;

  @override
  bool operator ==(Object other) =>
      other is AuthSessionIdentity &&
      userId == other.userId &&
      organizationId == other.organizationId &&
      sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(userId, organizationId, sessionId);
}
