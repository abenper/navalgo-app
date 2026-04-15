class WorkerProfile {
  const WorkerProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.speciality,
    required this.role,
    required this.active,
    required this.mustChangePassword,
    required this.canEditWorkOrders,
    required this.contractStartDate,
  });

  final int id;
  final String fullName;
  final String email;
  final String? speciality;
  final String role;
  final bool active;
  final bool mustChangePassword;
  final bool canEditWorkOrders;
  final DateTime contractStartDate;

  factory WorkerProfile.fromJson(Map<String, dynamic> json) {
    return WorkerProfile(
      id: json['id'] as int,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      speciality: json['speciality'] as String?,
      role: json['role'] as String,
      active: json['active'] as bool,
      mustChangePassword: json['mustChangePassword'] as bool? ?? false,
      canEditWorkOrders: json['canEditWorkOrders'] as bool? ?? false,
      contractStartDate: DateTime.parse(
        (json['contractStartDate'] as String?) ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
