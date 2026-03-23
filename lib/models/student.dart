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
}
