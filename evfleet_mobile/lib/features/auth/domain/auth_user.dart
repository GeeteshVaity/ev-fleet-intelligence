/// Authenticated user profile.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.createdAt,
    this.isDemoAccount = false,
  });

  final String id;
  final String email;
  final String fullName;
  final String? phoneNumber;
  final bool isEmailVerified;
  final DateTime? createdAt;

  /// True when this identity comes from the development-only mock auth
  /// provider rather than Amazon Cognito.
  final bool isDemoAccount;

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? email : parts.first;
  }

  AuthUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phoneNumber,
    bool? isEmailVerified,
    DateTime? createdAt,
    bool? isDemoAccount,
    bool clearPhone = false,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phoneNumber: clearPhone ? null : (phoneNumber ?? this.phoneNumber),
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
      isDemoAccount: isDemoAccount ?? this.isDemoAccount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'phoneNumber': phoneNumber,
    'isEmailVerified': isEmailVerified,
    'createdAt': createdAt?.toIso8601String(),
    'isDemoAccount': isDemoAccount,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    email: json['email'] as String,
    fullName: json['fullName'] as String? ?? '',
    phoneNumber: json['phoneNumber'] as String?,
    isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    createdAt: json['createdAt'] == null
        ? null
        : DateTime.parse(json['createdAt'] as String),
    isDemoAccount: json['isDemoAccount'] as bool? ?? false,
  );
}
