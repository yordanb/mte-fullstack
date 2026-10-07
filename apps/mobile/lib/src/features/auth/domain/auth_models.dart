/// Model auth — kontrak apps/api/app/api/v1/auth.py + users.py:31-40.
class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final String role;
  final String username;

  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.username,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> j) => LoginResponse(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
        role: (j['role'] ?? '') as String,
        username: (j['username'] ?? '') as String,
      );
}

class MeResponse {
  final String username;
  final String role;
  final String? avatarUrl;
  final Map<String, dynamic> permissions;

  const MeResponse({
    required this.username,
    required this.role,
    required this.permissions,
    this.avatarUrl,
  });

  factory MeResponse.fromJson(Map<String, dynamic> j) => MeResponse(
        username: (j['username'] ?? '') as String,
        role: (j['role'] ?? '') as String,
        avatarUrl: j['avatar_url'] as String?,
        permissions: (j['permissions'] as Map?)?.cast<String, dynamic>() ?? {},
      );
}
