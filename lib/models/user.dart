class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? token;
  final bool mustChangePassword;
  final bool canEditWorkOrders;
  final bool emailVerified;
  final int? ownerId;
  final String? photoUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token,
    this.mustChangePassword = false,
    this.canEditWorkOrders = false,
    this.emailVerified = true,
    this.ownerId,
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
      emailVerified: json['emailVerified'] ?? true,
      ownerId: json['ownerId'] as int?,
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
      'emailVerified': emailVerified,
      'ownerId': ownerId,
      'photoUrl': photoUrl,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? role,
    String? token,
    bool? mustChangePassword,
    bool? canEditWorkOrders,
    bool? emailVerified,
    int? ownerId,
    String? photoUrl,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      token: token ?? this.token,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      canEditWorkOrders: canEditWorkOrders ?? this.canEditWorkOrders,
      emailVerified: emailVerified ?? this.emailVerified,
      ownerId: ownerId ?? this.ownerId,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
