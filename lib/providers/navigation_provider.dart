import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:pedometer/pedometer.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../utils/kalman_filter.dart';
import '../utils/constants.dart';

class NavigationProvider extends ChangeNotifier {
  // Current position
  double _currentX = 0;
  double _currentY = 0;
  double _heading = 0;
  int _currentFloor = 0;

  // Target room for navigation
  Room? _targetRoom;

  // All rooms
  List<Room> _rooms = [];

  // Waypoints for pathfinding
  List<NavigationWaypoint> _waypoints = [];
  List<WaypointConnection> _waypointConnections = [];

  // Position is set
  bool _positionSet = false;

  // Sensor fusion
  late SensorFusion _sensorFusion;

  // Sensor subscriptions
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _magnetometerSubscription;
  StreamSubscription? _gyroscopeSubscription;
  StreamSubscription? _pedometerSubscription;

  // Step counting
  int _stepCount = 0;
  int _initialPedometerSteps = -1; // Track initial pedometer count

  // Navigation active
  bool _isNavigating = false;
  bool _sensorsActive = false;

  // Admin mode
  bool _isAdminMode = false;

  // Computed path
  List<Offset> _computedPath = [];

  // Calibration state
  bool _isCalibrating = false;
  bool _isCalibrated = false;
  double _headingOffset = 0;

  // Getters
  double get currentX => _currentX;
  double get currentY => _currentY;
  double get heading => _heading;
  int get currentFloor => _currentFloor;
  Room? get targetRoom => _targetRoom;
  List<Room> get rooms => _rooms;
  bool get positionSet => _positionSet;
  bool get isNavigating => _isNavigating;
  bool get sensorsActive => _sensorsActive;
  bool get isAdminMode => _isAdminMode;
  int get stepCount => _stepCount;
  bool get isCalibrating => _isCalibrating;
  bool get isCalibrated => _isCalibrated;

  // Distance to target
  double get distanceToTarget {
    if (_targetRoom == null) return 0;
    return sqrt(
      pow(_targetRoom!.xCoordinate - _currentX, 2) +
          pow(_targetRoom!.yCoordinate - _currentY, 2),
    );
  }

  // Direction to target (in degrees)
  double get directionToTarget {
    if (_targetRoom == null) return 0;
    final dx = _targetRoom!.xCoordinate - _currentX;
    final dy = _targetRoom!.yCoordinate - _currentY;
    return atan2(dx, -dy) * 180 / pi;
  }

  // Has reached destination
  bool get hasReachedDestination {
    return distanceToTarget < 30; // Within 30 pixels
  }

  NavigationProvider() {
    _sensorFusion = SensorFusion(
      stepLength: AppConstants.stepLengthPixels,
    );
    _loadRooms();
    _loadWaypoints();
  }

  Future<void> _loadRooms() async {
    try {
      _rooms = await SupabaseService.getRooms();
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      // Silent fail - rooms will be empty but app won't crash
    }
  }

  Future<void> _loadWaypoints() async {
    try {
      _waypoints = await SupabaseService.getWaypoints();
      _waypointConnections = await SupabaseService.getWaypointConnections();
    } catch (e) {
      debugPrint('Error loading waypoints: $e');
      // Silent fail - navigation will use direct path
    }
  }

  Future<void> refreshRooms() async {
    try {
      await _loadRooms();
      await _loadWaypoints();
    } catch (e) {
      debugPrint('Error refreshing rooms: $e');
    }
  }

  void setInitialPosition(double x, double y, {int floor = 0}) {
    _currentX = x;
    _currentY = y;
    _currentFloor = floor;
    _positionSet = true;
    _sensorFusion.setPosition(x, y);

    // Vibrate for feedback
    HapticFeedback.mediumImpact();

    // Recompute path if navigating
    if (_isNavigating && _targetRoom != null) {
      _computePath();
    }

    notifyListeners();
  }

  void setCurrentFloor(int floor) {
    _currentFloor = floor;
    notifyListeners();
  }

  void setTargetRoom(Room? room) {
    _targetRoom = room;
    _isNavigating = room != null;
    if (room != null && _positionSet) {
      _computePath();
    }
    notifyListeners();
  }

  void navigateToRoom(Room room) {
    _targetRoom = room;
    _isNavigating = true;
    if (!_positionSet) {
      // Default starting position if not set (center of map)
      setInitialPosition(350, 550, floor: room.floor);
    }
    _computePath();
    notifyListeners();
  }

  void stopNavigation() {
    _targetRoom = null;
    _isNavigating = false;
    _computedPath = [];
    notifyListeners();
  }

  void startSensors() {
    if (_sensorsActive) return;
    _sensorsActive = true;

    // Use pedometer for accurate step counting (like Google Maps)
    _pedometerSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (_initialPedometerSteps < 0) {
          _initialPedometerSteps = event.steps;
        }
        final newSteps = event.steps - _initialPedometerSteps;

        // Only update position if steps increased and position is set
        if (newSteps > _stepCount && _positionSet) {
          final stepsToProcess = newSteps - _stepCount;
          _stepCount = newSteps;

          // Process each new step
          for (int i = 0; i < stepsToProcess; i++) {
            final (x, y) = _sensorFusion.processStep();
            _updatePosition(x, y);
          }

          // Vibrate on step if navigating
          if (_isNavigating) {
            HapticFeedback.selectionClick();
          }
        }
      },
      onError: (error) {
        debugPrint('Pedometer error: $error - falling back to accelerometer');
        // Fall back to accelerometer-based step detection
        _useAccelerometerSteps();
      },
    );

    // Magnetometer for heading
    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      // Calculate heading from magnetometer
      double heading = atan2(event.y, event.x) * 180 / pi;

      // Apply calibration offset
      heading = (heading + _headingOffset + 360) % 360;

      _heading = heading;
      _sensorFusion.updateMagnetometer(heading);
      notifyListeners();
    });

    // Gyroscope for additional rotation tracking
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      // Could be used for more accurate rotation tracking
    });

    // Also listen to accelerometer for backup step detection
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      _sensorFusion.updateAccelerometer(event.x, event.y, event.z);
    });

    notifyListeners();
  }

  void _useAccelerometerSteps() {
    // Fallback: use accelerometer-based step detection
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      _sensorFusion.updateAccelerometer(event.x, event.y, event.z);

      if (_positionSet && _sensorFusion.detectStep()) {
        _stepCount++;
        final (x, y) = _sensorFusion.processStep();
        _updatePosition(x, y);

        // Vibrate on step if navigating
        if (_isNavigating) {
          HapticFeedback.selectionClick();
        }
      }
    });
  }

  void stopSensors() {
    _sensorsActive = false;
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _pedometerSubscription?.cancel();
    notifyListeners();
  }

  /// Calibrate compass heading
  void startCalibration() {
    _isCalibrating = true;
    notifyListeners();
  }

  void setCalibrationHeading(double actualHeading) {
    // User points phone in known direction and we calculate offset
    _headingOffset = actualHeading - _heading;
    _isCalibrating = false;
    _isCalibrated = true;
    notifyListeners();
  }

  /// Auto-calibrate using device compass - no manual input needed
  /// This mimics how Google Maps calibrates automatically
  void autoCalibrate() {
    // The compass heading from magnetometer is already being read
    // We just mark it as calibrated since the device compass is being used
    _isCalibrated = true;
    _isCalibrating = false;
    // Reset heading offset to 0 - trust the device compass
    _headingOffset = 0;
    notifyListeners();
  }

  void _updatePosition(double x, double y) {
    // Clamp to map bounds
    _currentX = x.clamp(0, AppConstants.mapWidth);
    _currentY = y.clamp(0, AppConstants.mapHeight);

    // Check if reached destination
    if (_isNavigating && hasReachedDestination) {
      HapticFeedback.heavyImpact();
    }

    // Update computed path
    if (_isNavigating && _targetRoom != null) {
      _computePath();
    }

    notifyListeners();
  }

  // Simulate a step (for testing without sensors)
  void simulateStep() {
    if (!_positionSet) return;

    _stepCount++;
    final (x, y) = _sensorFusion.processStep();
    _updatePosition(x, y);
  }

  // Simulate heading change (for testing)
  void simulateHeading(double heading) {
    _heading = heading;
    _sensorFusion.updateMagnetometer(heading);
    notifyListeners();
  }

  // Manual position update (for touch-based adjustment)
  void updatePositionManual(double x, double y) {
    _currentX = x;
    _currentY = y;
    _sensorFusion.setPosition(x, y);
    notifyListeners();
  }

  // Reset position
  void resetPosition() {
    _currentX = 0;
    _currentY = 0;
    _positionSet = false;
    _stepCount = 0;
    _initialPedometerSteps = -1; // Reset pedometer baseline
    _computedPath = [];
    _sensorFusion.reset(0, 0);
    notifyListeners();
  }

  // Admin mode functions
  void toggleAdminMode() {
    _isAdminMode = !_isAdminMode;
    notifyListeners();
  }

  Future<Room?> saveRoomCoordinates({
    required String name,
    required String roomNumber,
    required double x,
    required double y,
    String roomType = 'classroom',
    String? branchId,
    int floor = 3,
  }) async {
    final room = Room(
      id: '',
      name: name,
      roomNumber: roomNumber,
      floor: floor,
      branchId: branchId,
      xCoordinate: x,
      yCoordinate: y,
      roomType: roomType,
    );

    final savedRoom = await SupabaseService.createRoom(room);
    if (savedRoom != null) {
      await _loadRooms();
    }
    return savedRoom;
  }

  Future<bool> updateRoomCoordinates(Room room) async {
    final success = await SupabaseService.updateRoom(room);
    if (success) {
      await _loadRooms();
    }
    return success;
  }

  // Get room by coordinates (nearest room within threshold)
  Room? getRoomAtPosition(double x, double y, {double threshold = 50}) {
    Room? nearest;
    double minDistance = double.infinity;

    for (final room in _rooms) {
      final distance = sqrt(
        pow(room.xCoordinate - x, 2) + pow(room.yCoordinate - y, 2),
      );
      if (distance < threshold && distance < minDistance) {
        nearest = room;
        minDistance = distance;
      }
    }

    return nearest;
  }

  /// Compute path from current position to target room
  void _computePath() {
    if (!_positionSet || _targetRoom == null) {
      _computedPath = [];
      return;
    }

    // If no waypoints, use straight line
    if (_waypoints.isEmpty) {
      _computedPath = [
        Offset(_currentX, _currentY),
        Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
      ];
      return;
    }

    // Simple A* pathfinding through waypoints
    _computedPath = _findPath(
      Offset(_currentX, _currentY),
      Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
    );
  }

  /// Simple A* pathfinding
  List<Offset> _findPath(Offset start, Offset end) {
    // Find nearest waypoint to start
    NavigationWaypoint? startWaypoint =
        _findNearestWaypoint(start.dx, start.dy);
    NavigationWaypoint? endWaypoint = _findNearestWaypoint(end.dx, end.dy);

    if (startWaypoint == null || endWaypoint == null) {
      return [start, end];
    }

    // Build adjacency map
    final Map<String, List<String>> adjacency = {};
    for (final wp in _waypoints) {
      adjacency[wp.id] = [];
    }

    for (final conn in _waypointConnections) {
      adjacency[conn.fromWaypointId]?.add(conn.toWaypointId);
      if (conn.isBidirectional) {
        adjacency[conn.toWaypointId]?.add(conn.fromWaypointId);
      }
    }

    // A* algorithm
    final Map<String, double> gScore = {};
    final Map<String, double> fScore = {};
    final Map<String, String?> cameFrom = {};
    final Set<String> openSet = {startWaypoint.id};
    final Set<String> closedSet = {};

    for (final wp in _waypoints) {
      gScore[wp.id] = double.infinity;
      fScore[wp.id] = double.infinity;
    }

    gScore[startWaypoint.id] = 0;
    fScore[startWaypoint.id] = _heuristic(startWaypoint, endWaypoint);

    while (openSet.isNotEmpty) {
      // Find node with lowest fScore
      String current = openSet.reduce((a, b) =>
          (fScore[a] ?? double.infinity) < (fScore[b] ?? double.infinity)
              ? a
              : b);

      if (current == endWaypoint.id) {
        // Reconstruct path
        final path = <Offset>[end];
        String? node = current;
        while (node != null) {
          final wp = _waypoints.firstWhere((w) => w.id == node);
          path.insert(0, Offset(wp.xCoordinate, wp.yCoordinate));
          node = cameFrom[node];
        }
        path.insert(0, start);
        return path;
      }

      openSet.remove(current);
      closedSet.add(current);

      for (final neighborId in adjacency[current] ?? []) {
        if (closedSet.contains(neighborId)) continue;

        final currentWp = _waypoints.firstWhere((w) => w.id == current);
        final neighborWp = _waypoints.firstWhere((w) => w.id == neighborId);

        final tentativeG = (gScore[current] ?? double.infinity) +
            _distance(currentWp, neighborWp);

        if (!openSet.contains(neighborId)) {
          openSet.add(neighborId);
        } else if (tentativeG >= (gScore[neighborId] ?? double.infinity)) {
          continue;
        }

        cameFrom[neighborId] = current;
        gScore[neighborId] = tentativeG;
        fScore[neighborId] = tentativeG + _heuristic(neighborWp, endWaypoint);
      }
    }

    // No path found, use straight line
    return [start, end];
  }

  NavigationWaypoint? _findNearestWaypoint(double x, double y) {
    NavigationWaypoint? nearest;
    double minDist = double.infinity;

    for (final wp in _waypoints) {
      final dist =
          sqrt(pow(wp.xCoordinate - x, 2) + pow(wp.yCoordinate - y, 2));
      if (dist < minDist) {
        minDist = dist;
        nearest = wp;
      }
    }

    return nearest;
  }

  double _heuristic(NavigationWaypoint a, NavigationWaypoint b) {
    return sqrt(pow(a.xCoordinate - b.xCoordinate, 2) +
        pow(a.yCoordinate - b.yCoordinate, 2));
  }

  double _distance(NavigationWaypoint a, NavigationWaypoint b) {
    return sqrt(pow(a.xCoordinate - b.xCoordinate, 2) +
        pow(a.yCoordinate - b.yCoordinate, 2));
  }

  // Get path points for navigation with waypoints
  List<Offset> getNavigationPath() {
    if (!_positionSet || _targetRoom == null) return [];

    if (_computedPath.isEmpty) {
      return [
        Offset(_currentX, _currentY),
        Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
      ];
    }

    return _computedPath;
  }

  // Get navigation instructions based on current position and target
  String getNavigationInstructions() {
    if (!_positionSet) return 'Tap on the map to set your starting position';
    if (_targetRoom == null) return 'Select a destination to navigate';

    final distance = distanceToTarget;
    if (distance < 30) {
      return '🎉 You have arrived at ${_targetRoom!.name}!';
    }

    // Calculate direction relative to user's heading
    final targetDirection = directionToTarget;
    final relativeDegrees = (targetDirection - heading + 360) % 360;

    String direction;
    String emoji;

    if (relativeDegrees < 30 || relativeDegrees > 330) {
      direction = 'Continue straight ahead';
      emoji = '⬆️';
    } else if (relativeDegrees >= 30 && relativeDegrees < 60) {
      direction = 'Turn slightly right';
      emoji = '↗️';
    } else if (relativeDegrees >= 60 && relativeDegrees < 120) {
      direction = 'Turn right';
      emoji = '➡️';
    } else if (relativeDegrees >= 120 && relativeDegrees < 150) {
      direction = 'Turn sharply right';
      emoji = '↘️';
    } else if (relativeDegrees >= 150 && relativeDegrees < 210) {
      direction = 'Turn around';
      emoji = '⬇️';
    } else if (relativeDegrees >= 210 && relativeDegrees < 240) {
      direction = 'Turn sharply left';
      emoji = '↙️';
    } else if (relativeDegrees >= 240 && relativeDegrees < 300) {
      direction = 'Turn left';
      emoji = '⬅️';
    } else {
      direction = 'Turn slightly left';
      emoji = '↖️';
    }

    // Convert pixel distance to meters (approximate: 10 pixels ≈ 1 meter)
    final meters = (distance / 10).round();

    return '$emoji $direction\n${meters}m to ${_targetRoom!.name} (${_targetRoom!.roomNumber})';
  }

  /// Get estimated time to destination as formatted string
  String getEstimatedTime() {
    // Average walking speed: ~5 km/h = ~83 m/min
    // Our scale: 10 pixels ≈ 1 meter
    final meters = distanceToTarget / 10;
    final minutes = max(1, (meters / 83).ceil());

    if (minutes < 1) {
      return '<1 min';
    } else if (minutes == 1) {
      return '~1 min';
    } else {
      return '~$minutes min';
    }
  }

  @override
  void dispose() {
    stopSensors();
    super.dispose();
  }
}
