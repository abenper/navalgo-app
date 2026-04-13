class Owner {
  const Owner({
    required this.id,
    required this.type,
    required this.displayName,
    required this.documentId,
    this.phone,
    this.email,
    this.companyId,
  });

  final int id;
  final String type;
  final String displayName;
  final String documentId;
  final String? phone;
  final String? email;
  final int? companyId;

  factory Owner.fromJson(Map<String, dynamic> json) {
    return Owner(
      id: json['id'] as int,
      type: json['type'] as String,
      displayName: json['displayName'] as String,
      documentId: json['documentId'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      companyId: json['companyId'] as int?,
    );
  }
}
