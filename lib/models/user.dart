class User {
  final int id;
  final String name;
  final String email;
  final String role; // Rol obtenido del backend
  final String? token; // Token de autenticación

  User({required this.id, required this.name, required this.email, required this.role, this.token});

  // Factory constructor para crear una instancia de User desde un mapa (JSON)
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      token: json['token'],
    );
  }

  // Método para convertir una instancia de User a un mapa (JSON)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
    };
  }
}