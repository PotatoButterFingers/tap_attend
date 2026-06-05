class Lecturer {
  final String id;
  final String name;
  final String department;
  final String email;
  final String phone;
  final String office;
  final String? cardUid;

  Lecturer({
    required this.id,
    required this.name,
    required this.department,
    required this.email,
    required this.phone,
    required this.office,
    this.cardUid,
  });

  Lecturer copyWith({
    String? id,
    String? name,
    String? department,
    String? email,
    String? phone,
    String? office,
    String? cardUid,
  }) {
    return Lecturer(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      office: office ?? this.office,
      cardUid: cardUid ?? this.cardUid,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'department': department,
      'email': email,
      'phone': phone,
      'office': office,
      'card_uid': cardUid,
    };
  }

  factory Lecturer.fromJson(Map<String, dynamic> json) {
    return Lecturer(
      id: json['lecturer_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      office: json['office'] ?? '',
      cardUid: json['card_uid'],
    );
  }
}
