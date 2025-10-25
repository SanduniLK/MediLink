class MedicalCenter {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String email;
  final String adminId; // Medical center admin ID
  final String adminName;
  final bool isActive;

  MedicalCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.adminId,
    required this.adminName,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'adminId': adminId,
      'adminName': adminName,
      'isActive': isActive,
    };
  }

  factory MedicalCenter.fromJson(Map<String, dynamic> json) {
    return MedicalCenter(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      adminId: json['adminId'] ?? '',
      adminName: json['adminName'] ?? '',
      isActive: json['isActive'] ?? true,
    );
  }
}