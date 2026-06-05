class Student {
  final String id;
  final String name;
  final String deviceId; // The NFC tag ID
  final DateTime? scanTime;
  final bool isVerified;

  Student({
    required this.id,
    required this.name,
    required this.deviceId,
    this.scanTime,
    this.isVerified = false,
  });

  Student copyWith({
    String? id,
    String? name,
    String? deviceId,
    DateTime? scanTime,
    bool? isVerified,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      scanTime: scanTime ?? this.scanTime,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceId': deviceId,
      'scanTime': scanTime?.toIso8601String(),
      'isVerified': isVerified,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      deviceId: json['deviceId'],
      scanTime: json['scanTime'] != null ? DateTime.parse(json['scanTime']) : null,
      isVerified: json['isVerified'] ?? false,
    );
  }
}
