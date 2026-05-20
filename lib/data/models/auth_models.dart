import 'json_helpers.dart';

class UserResponse {
  const UserResponse({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.displayName,
    this.createdAt,
    this.updatedAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
    id: readInt(json, 'id'),
    username: readString(json, 'username'),
    email: readString(json, 'email'),
    role: readString(json, 'role', 'USER'),
    displayName: readNullableString(json, 'displayName'),
    createdAt: readNullableString(json, 'createdAt'),
    updatedAt: readNullableString(json, 'updatedAt'),
  );

  final int id;
  final String username;
  final String email;
  final String role;
  final String? displayName;
  final String? createdAt;
  final String? updatedAt;

  String get displayLabel =>
      displayName?.isNotEmpty == true ? displayName! : username;
  bool get isAdmin => role == 'ADMIN';

  Map<String, dynamic> toJson() => withoutNulls({
    'id': id,
    'username': username,
    'email': email,
    'role': role,
    'displayName': displayName,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  });
}

class AuthResponse {
  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
    token: readString(json, 'token'),
    user: UserResponse.fromJson(asMap(json['user'])),
  );

  final String token;
  final UserResponse user;
}

class MessageResponse {
  const MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(message: readString(json, 'message'));

  final String message;
}
