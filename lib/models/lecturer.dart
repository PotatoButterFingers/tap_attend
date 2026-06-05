class Lecturer {
  final String name;
  final String department;
  final String email;
  final String phone;
  final String office;

  Lecturer({
    required this.name,
    required this.department,
    required this.email,
    required this.phone,
    required this.office,
  });

  Lecturer copyWith({
    String? name,
    String? department,
    String? email,
    String? phone,
    String? office,
  }) {
    return Lecturer(
      name: name ?? this.name,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      office: office ?? this.office,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'department': department,
      'email': email,
      'phone': phone,
      'office': office,
    };
  }

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    return Lecturer(
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      office: json['office'] ?? '',
    );
  }
}
