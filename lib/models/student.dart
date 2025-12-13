class Student {
  final String id;
  final String email;
  final String? passwordHash;
  final String name;
  final String rollNumber;
  final String? branchId;
  final int semester;
  final String anonymousId;
  final String? phone;
  final DateTime? createdAt;

  Student({
    required this.id,
    required this.email,
    this.passwordHash,
    required this.name,
    required this.rollNumber,
    this.branchId,
    required this.semester,
    required this.anonymousId,
    this.phone,
    this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      passwordHash: json['password_hash'],
      name: json['name'] ?? '',
      rollNumber: json['roll_number'] ?? '',
      branchId: json['branch_id'],
      semester: json['semester'] ?? 1,
      anonymousId: json['anonymous_id'] ?? '',
      phone: json['phone'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'roll_number': rollNumber,
      'branch_id': branchId,
      'semester': semester,
      'anonymous_id': anonymousId,
      'phone': phone,
    };
  }

  Student copyWith({
    String? id,
    String? email,
    String? passwordHash,
    String? name,
    String? rollNumber,
    String? branchId,
    int? semester,
    String? anonymousId,
    String? phone,
  }) {
    return Student(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      branchId: branchId ?? this.branchId,
      semester: semester ?? this.semester,
      anonymousId: anonymousId ?? this.anonymousId,
      phone: phone ?? this.phone,
      createdAt: createdAt,
    );
  }
}
