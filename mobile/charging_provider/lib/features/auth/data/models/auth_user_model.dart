class AuthUserModel {
  const AuthUserModel({required this.userId,
  required this.username,this.fullName, this.email,});

  final String userId;
  final String username;
  final String? fullName;
  final String? email;
}
