class Room {
  final String id;
  final String name;
  final String roomNumber;
  final int floor;
  final String? branchId;
  final double xCoordinate;
  final double yCoordinate;
  final String roomType;
  final int capacity;
  final String? displayName; // Custom display name (can be changed by HOD)
  final String? lastModifiedBy; // Teacher who last modified
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    required this.id,
    required this.name,
    required this.roomNumber,
    required this.floor,
    this.branchId,
    required this.xCoordinate,
    required this.yCoordinate,
    this.roomType = 'classroom',
    this.capacity = 60,
    this.displayName,
    this.lastModifiedBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns the display name if set, otherwise the room name
  String get effectiveName => displayName ?? name;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      roomNumber: json['room_number'] ?? '',
      floor: json['floor'] ?? 1,
      branchId: json['branch_id'],
      xCoordinate: (json['x_coordinate'] ?? 0).toDouble(),
      yCoordinate: (json['y_coordinate'] ?? 0).toDouble(),
      roomType: json['room_type'] ?? 'classroom',
      capacity: json['capacity'] ?? 60,
      displayName: json['display_name'],
      lastModifiedBy: json['last_modified_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'room_number': roomNumber,
      'floor': floor,
      'branch_id': branchId,
      'x_coordinate': xCoordinate,
      'y_coordinate': yCoordinate,
      'room_type': roomType,
      'capacity': capacity,
      'display_name': displayName,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'room_number': roomNumber,
      'floor': floor,
      'branch_id': branchId,
      'x_coordinate': xCoordinate,
      'y_coordinate': yCoordinate,
      'room_type': roomType,
      'capacity': capacity,
      'display_name': displayName,
    };
  }

  Room copyWith({
    String? id,
    String? name,
    String? roomNumber,
    int? floor,
    String? branchId,
    double? xCoordinate,
    double? yCoordinate,
    String? roomType,
    int? capacity,
    String? displayName,
    String? lastModifiedBy,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      roomNumber: roomNumber ?? this.roomNumber,
      floor: floor ?? this.floor,
      branchId: branchId ?? this.branchId,
      xCoordinate: xCoordinate ?? this.xCoordinate,
      yCoordinate: yCoordinate ?? this.yCoordinate,
      roomType: roomType ?? this.roomType,
      capacity: capacity ?? this.capacity,
      displayName: displayName ?? this.displayName,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
