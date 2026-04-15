class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? token;
  final bool mustChangePassword;
  final bool canEditWorkOrders;
  final String? photoUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token,
    this.mustChangePassword = false,
    this.canEditWorkOrders = false,
    this.photoUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      token: json['token'],
      mustChangePassword: json['mustChangePassword'] ?? false,
      canEditWorkOrders: json['canEditWorkOrders'] ?? false,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
      'mustChangePassword': mustChangePassword,
      'canEditWorkOrders': canEditWorkOrders,
      'photoUrl': photoUrl,
    };
  }
}