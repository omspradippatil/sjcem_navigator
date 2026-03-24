class Teacher {
  final String id;
  final String email;
  final String? passwordHash;
  final String name;
  final String? phone;
  final String? branchId;
  final bool isHod;
  final bool isAdmin;
  final String? defaultRoomId;
  final String? currentRoomId;
  final DateTime? currentRoomUpdatedAt;
  final DateTime? createdAt;

  Teacher({
    required this.id,
    required this.email,
    this.passwordHash,
    required this.name,
    this.phone,
    this.branchId,
    this.isHod = false,
    this.isAdmin = false,
    this.defaultRoomId,
    this.currentRoomId,
    this.currentRoomUpdatedAt,
    this.createdAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      passwordHash: json['password_hash'],
      name: json['name'] ?? '',
      phone: json['phone'],
      branchId: json['branch_id'],
      isHod: json['is_hod'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      defaultRoomId: json['default_room_id'],
      currentRoomId: json['current_room_id'],
      currentRoomUpdatedAt: json['current_room_updated_at'] != null 
          ? DateTime.parse(json['current_room_updated_at']) 
          : null,
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
      'phone': phone,
      'branch_id': branchId,
      'is_hod': isHod,
      'is_admin': isAdmin,
      'default_room_id': defaultRoomId,
      'current_room_id': currentRoomId,
    };
  }

  Teacher copyWith({
    String? id,
    String? email,
    String? passwordHash,
    String? name,
    String? phone,
    String? branchId,
    bool? isHod,
    bool? isAdmin,
    String? defaultRoomId,
    String? currentRoomId,
    DateTime? currentRoomUpdatedAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      branchId: branchId ?? this.branchId,
      isHod: isHod ?? this.isHod,
      isAdmin: isAdmin ?? this.isAdmin,
      defaultRoomId: defaultRoomId ?? this.defaultRoomId,
      currentRoomId: currentRoomId ?? this.currentRoomId,
      currentRoomUpdatedAt: currentRoomUpdatedAt ?? this.currentRoomUpdatedAt,
      createdAt: createdAt,
    );
  }
}
