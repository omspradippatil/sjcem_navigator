class Room {
  final String id;
  final String name;
  final String roomNumber;
  final int floor;
  final String? branchId;
  final double xCoordinate;
  final double yCoordinate;
  final String roomType;
  final DateTime? createdAt;

  Room({
    required this.id,
    required this.name,
    required this.roomNumber,
    required this.floor,
    this.branchId,
    required this.xCoordinate,
    required this.yCoordinate,
    this.roomType = 'classroom',
    this.createdAt,
  });

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
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
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
    };
  }
}
