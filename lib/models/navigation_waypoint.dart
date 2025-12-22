class NavigationWaypoint {
  final String id;
  final String? name;
  final int floor;
  final double xCoordinate;
  final double yCoordinate;
  final String waypointType;
  final DateTime? createdAt;

  NavigationWaypoint({
    required this.id,
    this.name,
    required this.floor,
    required this.xCoordinate,
    required this.yCoordinate,
    this.waypointType = 'corridor',
    this.createdAt,
  });

  factory NavigationWaypoint.fromJson(Map<String, dynamic> json) {
    return NavigationWaypoint(
      id: json['id'] ?? '',
      name: json['name'],
      floor: json['floor'] ?? 1,
      xCoordinate: (json['x_coordinate'] ?? 0).toDouble(),
      yCoordinate: (json['y_coordinate'] ?? 0).toDouble(),
      waypointType: json['waypoint_type'] ?? 'corridor',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'floor': floor,
      'x_coordinate': xCoordinate,
      'y_coordinate': yCoordinate,
      'waypoint_type': waypointType,
    };
  }
}

class WaypointConnection {
  final String id;
  final String fromWaypointId;
  final String toWaypointId;
  final double? distance;
  final bool isBidirectional;
  final DateTime? createdAt;

  WaypointConnection({
    required this.id,
    required this.fromWaypointId,
    required this.toWaypointId,
    this.distance,
    this.isBidirectional = true,
    this.createdAt,
  });

  factory WaypointConnection.fromJson(Map<String, dynamic> json) {
    return WaypointConnection(
      id: json['id'] ?? '',
      fromWaypointId: json['from_waypoint_id'] ?? '',
      toWaypointId: json['to_waypoint_id'] ?? '',
      distance: json['distance']?.toDouble(),
      isBidirectional: json['is_bidirectional'] ?? true,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_waypoint_id': fromWaypointId,
      'to_waypoint_id': toWaypointId,
      'distance': distance,
      'is_bidirectional': isBidirectional,
    };
  }
}
