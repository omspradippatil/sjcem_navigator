import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';
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

  // Step counting
  int _stepCount = 0;

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

  // Enhanced calibration
  final List<double> _calibrationReadings = [];
  static const int _calibrationSampleCount = 10;

  // Magnetometer readings
  double _rawMagnetometerHeading = 0;
  final List<double> _magnetometerHistory = [];
  static const int _magnetometerHistorySize = 5;

  // Debug info for sensor status
  double _lastAccelMagnitude = 0;
  double _lastDeviation = 0;
  double _dynamicThreshold = 1.2;
  bool _lastStepDetected = false;

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

  // Debug getters
  double get lastAccelMagnitude => _lastAccelMagnitude;
  double get lastDeviation => _lastDeviation;
  double get dynamicThreshold => _dynamicThreshold;
  bool get lastStepDetected => _lastStepDetected;

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
    return distanceToTarget < 30;
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
      if (_rooms.isNotEmpty) {
        await OfflineCacheService.cacheRooms(_rooms);
      }
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error loading rooms: $e');
      final cachedRooms = await OfflineCacheService.getCachedRooms();
      if (cachedRooms.isNotEmpty) {
        _rooms = cachedRooms;
        Future.microtask(() => notifyListeners());
      }
    }
  }

  Future<void> _loadWaypoints() async {
    try {
      _waypoints = await SupabaseService.getWaypoints();
      _waypointConnections = await SupabaseService.getWaypointConnections();
      if (_waypoints.isNotEmpty) {
        await OfflineCacheService.cacheWaypoints(_waypoints);
        await OfflineCacheService.cacheConnections(_waypointConnections);
      }
    } catch (e) {
      debugPrint('Error loading waypoints: $e');
      final cachedWaypoints = await OfflineCacheService.getCachedWaypoints();
      final cachedConnections =
          await OfflineCacheService.getCachedConnections();
      if (cachedWaypoints.isNotEmpty) {
        _waypoints = cachedWaypoints;
        _waypointConnections = cachedConnections;
      }
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
    HapticFeedback.mediumImpact();

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

    // Accelerometer for step detection - 50Hz sampling
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _sensorFusion.updateAccelerometer(event.x, event.y, event.z);

      // Update debug info
      _lastAccelMagnitude = _sensorFusion.lastMagnitude;
      _lastDeviation = _sensorFusion.lastDeviation;
      _dynamicThreshold = _sensorFusion.dynamicThreshold;

      if (_positionSet && _sensorFusion.detectStep()) {
        _stepCount++;
        _lastStepDetected = true;
        final (x, y) = _sensorFusion.processStep();
        _updatePosition(x, y);
        HapticFeedback.lightImpact();
        notifyListeners();
      } else {
        _lastStepDetected = false;
      }
    });

    // Magnetometer for heading
    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      double heading = atan2(event.y, event.x) * 180 / pi;
      heading = (heading + 360) % 360;
      _rawMagnetometerHeading = heading;

      _magnetometerHistory.add(heading);
      if (_magnetometerHistory.length > _magnetometerHistorySize) {
        _magnetometerHistory.removeAt(0);
      }

      double smoothedHeading = _calculateCircularMean(_magnetometerHistory);
      smoothedHeading = (smoothedHeading + _headingOffset + 360) % 360;

      _heading = smoothedHeading;
      _sensorFusion.updateMagnetometer(smoothedHeading);
      notifyListeners();
    });

    // Gyroscope (optional)
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      // For future use
    });

    notifyListeners();
  }

  void stopSensors() {
    _sensorsActive = false;
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    notifyListeners();
  }

  void startCalibration() {
    _isCalibrating = true;
    notifyListeners();
  }

  void setCalibrationHeading(double actualHeading) {
    _headingOffset = actualHeading - _heading;
    _isCalibrating = false;
    _isCalibrated = true;
    notifyListeners();
  }

  void autoCalibrate() {
    _isCalibrated = true;
    _isCalibrating = false;
    _headingOffset = 0;
    notifyListeners();
  }

  void performEnhancedCalibration() {
    _calibrationReadings.clear();
    _isCalibrating = true;
    notifyListeners();

    // Wait a bit for sensors to start collecting data, then begin calibration
    Timer(const Duration(milliseconds: 500), () {
      int attempts = 0;
      const maxAttempts = 30; // Max 3 seconds wait

      Timer.periodic(const Duration(milliseconds: 100), (timer) {
        attempts++;

        // Only add valid readings (non-zero means sensor is active)
        if (_rawMagnetometerHeading != 0 || attempts > 5) {
          if (_calibrationReadings.length < _calibrationSampleCount) {
            _calibrationReadings.add(_rawMagnetometerHeading);
          } else {
            timer.cancel();
            _finishEnhancedCalibration();
            return;
          }
        }

        // Timeout protection
        if (attempts >= maxAttempts) {
          timer.cancel();
          _finishEnhancedCalibration();
        }
      });
    });
  }

  void _finishEnhancedCalibration() {
    if (_calibrationReadings.isEmpty) {
      _isCalibrating = false;
      _isCalibrated = true;
      notifyListeners();
      return;
    }

    final meanHeading = _calculateCircularMean(_calibrationReadings);
    _headingOffset = -meanHeading;
    _isCalibrating = false;
    _isCalibrated = true;
    _calibrationReadings.clear();
    notifyListeners();
  }

  double _calculateCircularMean(List<double> angles) {
    if (angles.isEmpty) return 0;

    double sumSin = 0;
    double sumCos = 0;

    for (final angle in angles) {
      final rad = angle * pi / 180;
      sumSin += sin(rad);
      sumCos += cos(rad);
    }

    final meanAngle = atan2(sumSin / angles.length, sumCos / angles.length);
    return (meanAngle * 180 / pi + 360) % 360;
  }

  void _updatePosition(double x, double y) {
    _currentX = x.clamp(0, AppConstants.mapWidth);
    _currentY = y.clamp(0, AppConstants.mapHeight);

    if (_isNavigating && hasReachedDestination) {
      HapticFeedback.heavyImpact();
    }

    if (_isNavigating && _targetRoom != null) {
      _computePath();
    }

    notifyListeners();
  }

  void simulateStep() {
    if (!_positionSet) return;
    _stepCount++;
    final (x, y) = _sensorFusion.processStep();
    _updatePosition(x, y);
  }

  void simulateHeading(double heading) {
    _heading = heading;
    _sensorFusion.updateMagnetometer(heading);
    notifyListeners();
  }

  void updatePositionManual(double x, double y) {
    _currentX = x;
    _currentY = y;
    _sensorFusion.setPosition(x, y);
    notifyListeners();
  }

  void resetPosition() {
    _currentX = 0;
    _currentY = 0;
    _positionSet = false;
    _stepCount = 0;
    _computedPath = [];
    _sensorFusion.reset(0, 0);
    notifyListeners();
  }

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

  void _computePath() {
    if (!_positionSet || _targetRoom == null) {
      _computedPath = [];
      return;
    }

    if (_waypoints.isEmpty) {
      _computedPath = [
        Offset(_currentX, _currentY),
        Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
      ];
      return;
    }

    _computedPath = _findPath(
      Offset(_currentX, _currentY),
      Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
    );
  }

  List<Offset> _findPath(Offset start, Offset end) {
    NavigationWaypoint? startWaypoint =
        _findNearestWaypoint(start.dx, start.dy);
    NavigationWaypoint? endWaypoint = _findNearestWaypoint(end.dx, end.dy);

    if (startWaypoint == null || endWaypoint == null) {
      return [start, end];
    }

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
      String current = openSet.reduce((a, b) =>
          (fScore[a] ?? double.infinity) < (fScore[b] ?? double.infinity)
              ? a
              : b);

      if (current == endWaypoint.id) {
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

  String getNavigationInstructions() {
    if (!_positionSet) return 'Tap on the map to set your starting position';
    if (_targetRoom == null) return 'Select a destination to navigate';

    final distance = distanceToTarget;
    if (distance < 30) {
      return '🎉 You have arrived at ${_targetRoom!.name}!';
    }

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

    final meters = (distance / 10).round();
    return '$emoji $direction\n${meters}m to ${_targetRoom!.name} (${_targetRoom!.roomNumber})';
  }

  String getEstimatedTime() {
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
