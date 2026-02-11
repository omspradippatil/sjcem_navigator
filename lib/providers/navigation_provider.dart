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

  // Admin edit mode: 'normal', 'quickAdd', 'connect', 'delete'
  String _adminEditMode = 'normal';

  // Selected waypoint for connecting
  NavigationWaypoint? _selectedWaypointForConnect;

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
  static const int _magnetometerHistorySize = 15; // Increased for stability

  // Debug info for sensor status
  double _lastAccelMagnitude = 0;
  double _lastDeviation = 0;
  double _dynamicThreshold = 1.2;
  bool _lastStepDetected = false;

  // Gyroscope-based heading tracking
  double _gyroHeading = 0;
  DateTime _lastGyroTime = DateTime.now();
  bool _useGyroHeading = false;

  // Heading stability (prevent spinning)
  double _stableHeading = 0;
  final List<double> _headingBuffer = [];
  static const int _headingBufferSize = 20; // Large buffer for stability
  static const double _headingChangeThreshold = 8.0; // Minimum change to update

  // Movement-based calibration
  final List<Offset> _movementHistory = [];
  static const int _movementHistorySize = 5;
  double _movementBasedHeading = 0;
  bool _hasMovementHeading = false;

  // Auto-calibration state
  bool _autoCalibrationPending = false;

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
  String get adminEditMode => _adminEditMode;
  NavigationWaypoint? get selectedWaypointForConnect =>
      _selectedWaypointForConnect;
  int get stepCount => _stepCount;
  bool get isCalibrating => _isCalibrating;
  bool get isCalibrated => _isCalibrated;

  // Debug getters
  double get lastAccelMagnitude => _lastAccelMagnitude;
  double get lastDeviation => _lastDeviation;
  double get dynamicThreshold => _dynamicThreshold;
  bool get lastStepDetected => _lastStepDetected;
  bool get autoCalibrationPending => _autoCalibrationPending;
  bool get hasMovementHeading => _hasMovementHeading;

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
    // Always load from cache first for instant availability
    final cachedRooms = await OfflineCacheService.getCachedRooms();
    if (cachedRooms.isNotEmpty) {
      _rooms = cachedRooms;
      Future.microtask(() => notifyListeners());
    }

    // Then try to refresh from Supabase if online
    final isOnline = await OfflineCacheService.checkConnectivity();
    if (isOnline) {
      try {
        final freshRooms = await SupabaseService.getRooms();
        if (freshRooms.isNotEmpty) {
          _rooms = freshRooms;
          await OfflineCacheService.cacheRooms(freshRooms);
          Future.microtask(() => notifyListeners());
        }
      } catch (e) {
        debugPrint('Error fetching rooms from Supabase (using cache): $e');
      }
    } else {
      debugPrint('📴 Offline - using cached rooms (${_rooms.length} rooms)');
    }
  }

  Future<void> _loadWaypoints() async {
    // Always load from cache first for instant availability
    final cachedWaypoints = await OfflineCacheService.getCachedWaypoints();
    final cachedConnections = await OfflineCacheService.getCachedConnections();
    if (cachedWaypoints.isNotEmpty) {
      _waypoints = cachedWaypoints;
      _waypointConnections = cachedConnections;
    }

    // Then try to refresh from Supabase if online
    final isOnline = await OfflineCacheService.checkConnectivity();
    if (isOnline) {
      try {
        final freshWaypoints = await SupabaseService.getWaypoints();
        final freshConnections = await SupabaseService.getWaypointConnections();
        if (freshWaypoints.isNotEmpty) {
          _waypoints = freshWaypoints;
          _waypointConnections = freshConnections;
          await OfflineCacheService.cacheWaypoints(freshWaypoints);
          await OfflineCacheService.cacheConnections(freshConnections);
        }
      } catch (e) {
        debugPrint('Error fetching waypoints from Supabase (using cache): $e');
      }
    } else {
      debugPrint(
          '📴 Offline - using cached waypoints (${_waypoints.length} waypoints, ${_waypointConnections.length} connections)');
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

    // Magnetometer for heading - with heavy stabilization
    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod:
          const Duration(milliseconds: 100), // Lower rate for stability
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

      // Apply stability filter to prevent spinning
      _heading = _stabilizeHeading(smoothedHeading);
      _sensorFusion.updateMagnetometer(_heading);
      notifyListeners();
    });

    // Gyroscope for heading drift correction
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      final now = DateTime.now();
      final dt = now.difference(_lastGyroTime).inMilliseconds / 1000.0;
      _lastGyroTime = now;

      if (dt > 0 && dt < 0.5) {
        // Integrate gyroscope Z-axis (yaw) rotation
        // Convert rad/s to degrees and accumulate
        final rotationZ = event.z * 180 / pi * dt;
        _gyroHeading = (_gyroHeading - rotationZ + 360) % 360;

        // Use gyroscope for more stable heading when movement detected
        if (_useGyroHeading && _lastStepDetected) {
          // Blend magnetometer and gyroscope (complementary filter)
          // 95% gyro + 5% mag for maximum stability during movement
          final magHeading =
              (_rawMagnetometerHeading + _headingOffset + 360) % 360;
          final blendedHeading =
              _complementaryFilter(_gyroHeading, magHeading, 0.95);
          _heading = _stabilizeHeading(blendedHeading);
          _sensorFusion.updateMagnetometer(_heading);
        }
      }
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
    // Smart auto-calibration: if we have movement data, use it
    if (_hasMovementHeading) {
      _completeAutoCalibration();
      return;
    }

    // Otherwise, start smart calibration (will complete when user moves)
    startSmartAutoCalibration();
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

  // Complementary filter for blending gyro and magnetometer headings
  double _complementaryFilter(double gyro, double mag, double alpha) {
    // Handle wraparound at 360/0 degrees
    double diff = mag - gyro;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    return (gyro + (1 - alpha) * diff + 360) % 360;
  }

  // Stabilize heading to prevent spinning/jittery direction
  double _stabilizeHeading(double newHeading) {
    _headingBuffer.add(newHeading);
    if (_headingBuffer.length > _headingBufferSize) {
      _headingBuffer.removeAt(0);
    }

    // Calculate stable heading from buffer
    final bufferedHeading = _calculateCircularMean(_headingBuffer);

    // Only update if change is significant
    double diff = (bufferedHeading - _stableHeading + 540) % 360 - 180;
    if (diff.abs() > _headingChangeThreshold) {
      // Smooth transition instead of jump
      _stableHeading = (_stableHeading + diff * 0.3 + 360) % 360;
    }

    return _stableHeading;
  }

  // Track movement for movement-based calibration
  void _trackMovement(double x, double y) {
    _movementHistory.add(Offset(x, y));
    if (_movementHistory.length > _movementHistorySize) {
      _movementHistory.removeAt(0);
    }

    // Calculate heading from movement direction
    if (_movementHistory.length >= 2) {
      final first = _movementHistory.first;
      final last = _movementHistory.last;
      final dx = last.dx - first.dx;
      final dy = last.dy - first.dy;
      final distance = sqrt(dx * dx + dy * dy);

      // Only calculate if significant movement (> 20 pixels)
      if (distance > 20) {
        // Map coordinates: Y increases downward, so we negate
        _movementBasedHeading = (atan2(-dy, dx) * 180 / pi + 90 + 360) % 360;
        _hasMovementHeading = true;

        // If auto-calibration is pending, complete it
        if (_autoCalibrationPending) {
          _completeAutoCalibration();
        }
      }
    }
  }

  // Smart auto-calibration that uses movement direction
  void startSmartAutoCalibration() {
    _autoCalibrationPending = true;
    _movementHistory.clear();
    _hasMovementHeading = false;
    _isCalibrating = true;
    notifyListeners();
  }

  void _completeAutoCalibration() {
    if (!_hasMovementHeading) return;

    // Calculate offset: difference between sensor heading and movement-based map heading
    // The movement direction tells us the actual map direction we're moving
    // So we adjust the compass to match
    final sensorHeading = _rawMagnetometerHeading;
    _headingOffset = (_movementBasedHeading - sensorHeading + 360) % 360;

    // Sync gyroscope heading
    _gyroHeading = _movementBasedHeading;
    _useGyroHeading = true;

    _autoCalibrationPending = false;
    _isCalibrating = false;
    _isCalibrated = true;
    _movementHistory.clear();
    notifyListeners();
  }

  // Quick calibration: face a known direction and calibrate instantly
  void calibrateToDirection(double mapDirection) {
    // mapDirection is where you're facing on the map (0=North, 90=East, etc)
    // _rawMagnetometerHeading is the sensor's current reading
    _headingOffset = (mapDirection - _rawMagnetometerHeading + 360) % 360;
    _gyroHeading = mapDirection;
    _useGyroHeading = true;
    _isCalibrating = false;
    _isCalibrated = true;
    notifyListeners();
  }

  // Cancel auto-calibration
  void cancelAutoCalibration() {
    _autoCalibrationPending = false;
    _isCalibrating = false;
    _movementHistory.clear();
    notifyListeners();
  }

  void _updatePosition(double x, double y) {
    // Constrain to walkable area (near waypoints/paths)
    final constrainedPos = _constrainToWalkableArea(x, y);
    _currentX = constrainedPos.dx.clamp(0, AppConstants.mapWidth);
    _currentY = constrainedPos.dy.clamp(0, AppConstants.mapHeight);

    // Track movement for auto-calibration
    _trackMovement(_currentX, _currentY);

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
    if (!_isAdminMode) {
      // Reset edit mode when exiting admin mode
      _adminEditMode = 'normal';
      _selectedWaypointForConnect = null;
    }
    notifyListeners();
  }

  void setAdminEditMode(String mode) {
    _adminEditMode = mode;
    if (mode != 'connect') {
      _selectedWaypointForConnect = null;
    }
    notifyListeners();
  }

  void selectWaypointForConnect(NavigationWaypoint waypoint) {
    if (_selectedWaypointForConnect?.id == waypoint.id) {
      // Deselect if same waypoint
      _selectedWaypointForConnect = null;
    } else if (_selectedWaypointForConnect != null) {
      // Connect the two waypoints
      createWaypointConnection(
        fromWaypointId: _selectedWaypointForConnect!.id,
        toWaypointId: waypoint.id,
        isBidirectional: true,
      );
      _selectedWaypointForConnect = null;
    } else {
      // Select the first waypoint
      _selectedWaypointForConnect = waypoint;
    }
    notifyListeners();
  }

  void clearSelectedWaypoint() {
    _selectedWaypointForConnect = null;
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

  // =============================================
  // WAYPOINT MANAGEMENT
  // =============================================

  List<NavigationWaypoint> get waypoints => _waypoints;
  List<WaypointConnection> get waypointConnections => _waypointConnections;

  Future<NavigationWaypoint?> createWaypoint({
    required String name,
    required int floor,
    required double x,
    required double y,
    String waypointType = 'junction',
    String? description,
    String? photoUrl,
  }) async {
    final waypoint = NavigationWaypoint(
      id: '',
      name: name,
      floor: floor,
      xCoordinate: x,
      yCoordinate: y,
      waypointType: waypointType,
      description: description,
      photoUrl: photoUrl,
    );

    final savedWaypoint = await SupabaseService.createWaypoint(waypoint);
    if (savedWaypoint != null) {
      await _loadWaypoints();
    }
    return savedWaypoint;
  }

  Future<bool> deleteWaypoint(String waypointId) async {
    final success = await SupabaseService.deleteWaypoint(waypointId);
    if (success) {
      await _loadWaypoints();
      _computePath();
    }
    return success;
  }

  Future<WaypointConnection?> createWaypointConnection({
    required String fromWaypointId,
    required String toWaypointId,
    double? distance,
    bool isBidirectional = true,
  }) async {
    // Calculate distance if not provided
    double calculatedDistance = distance ?? 0;
    if (distance == null) {
      final fromWp = _waypoints.firstWhere((w) => w.id == fromWaypointId,
          orElse: () => _waypoints.first);
      final toWp = _waypoints.firstWhere((w) => w.id == toWaypointId,
          orElse: () => _waypoints.first);
      calculatedDistance = sqrt(
        pow(fromWp.xCoordinate - toWp.xCoordinate, 2) +
            pow(fromWp.yCoordinate - toWp.yCoordinate, 2),
      );
    }

    final connection = WaypointConnection(
      id: '',
      fromWaypointId: fromWaypointId,
      toWaypointId: toWaypointId,
      distance: calculatedDistance,
      isBidirectional: isBidirectional,
    );

    final savedConnection =
        await SupabaseService.createWaypointConnection(connection);
    if (savedConnection != null) {
      await _loadWaypoints();
    }
    return savedConnection;
  }

  Future<bool> deleteWaypointConnection(String connectionId) async {
    final success =
        await SupabaseService.deleteWaypointConnection(connectionId);
    if (success) {
      await _loadWaypoints();
    }
    return success;
  }

  NavigationWaypoint? getWaypointAtPosition(double x, double y,
      {double threshold = 30}) {
    NavigationWaypoint? nearest;
    double minDistance = double.infinity;

    for (final waypoint in _waypoints) {
      final distance = sqrt(
        pow(waypoint.xCoordinate - x, 2) + pow(waypoint.yCoordinate - y, 2),
      );
      if (distance < threshold && distance < minDistance) {
        nearest = waypoint;
        minDistance = distance;
      }
    }

    return nearest;
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

  // Constrain position to walkable areas (waypoint paths) - STRICT MODE
  // User position moves ONLY along defined waypoint paths like a car on a road
  Offset _constrainToWalkableArea(double x, double y) {
    if (_waypoints.isEmpty || _waypointConnections.isEmpty) {
      return Offset(x, y); // No waypoints, allow free movement
    }

    final pos = Offset(x, y);
    Offset nearestPoint = pos;
    double minDistance = double.infinity;

    // First, find the nearest point on any path segment
    for (final conn in _waypointConnections) {
      final fromWp = _waypoints.firstWhere(
        (w) => w.id == conn.fromWaypointId,
        orElse: () => _waypoints.first,
      );
      final toWp = _waypoints.firstWhere(
        (w) => w.id == conn.toWaypointId,
        orElse: () => _waypoints.first,
      );

      // Only consider paths on current floor
      if (fromWp.floor != _currentFloor && toWp.floor != _currentFloor) {
        continue;
      }

      final from = Offset(fromWp.xCoordinate, fromWp.yCoordinate);
      final to = Offset(toWp.xCoordinate, toWp.yCoordinate);

      // Find nearest point on line segment
      final nearest = _nearestPointOnSegment(pos, from, to);
      final dist = (pos - nearest).distance;

      if (dist < minDistance) {
        minDistance = dist;
        nearestPoint = nearest;
      }
    }

    // Also check distance to individual waypoints (for better snapping at junctions)
    for (final wp in _waypoints) {
      if (wp.floor != _currentFloor) continue;

      final wpPos = Offset(wp.xCoordinate, wp.yCoordinate);
      final dist = (pos - wpPos).distance;

      // Prefer snapping to waypoint nodes when very close (junction priority)
      if (dist < 25 && dist < minDistance) {
        minDistance = dist;
        nearestPoint = wpPos;
      }
    }

    // STRICT MODE: Always snap to the nearest path point
    // The user's red dot will ONLY move along defined waypoint paths
    return nearestPoint;
  }

  // Get the list of connected waypoints from current position
  List<NavigationWaypoint> getConnectedWaypoints(String waypointId) {
    final connectedIds = <String>[];

    for (final conn in _waypointConnections) {
      if (conn.fromWaypointId == waypointId) {
        connectedIds.add(conn.toWaypointId);
      }
      if (conn.isBidirectional && conn.toWaypointId == waypointId) {
        connectedIds.add(conn.fromWaypointId);
      }
    }

    return _waypoints.where((w) => connectedIds.contains(w.id)).toList();
  }

  // Check if position is on a valid path
  bool isPositionOnPath(double x, double y) {
    if (_waypoints.isEmpty || _waypointConnections.isEmpty) return true;

    final pos = Offset(x, y);
    const maxDeviation = 30.0; // Maximum allowed distance from path

    for (final conn in _waypointConnections) {
      final fromWp = _waypoints.firstWhere((w) => w.id == conn.fromWaypointId,
          orElse: () => _waypoints.first);
      final toWp = _waypoints.firstWhere((w) => w.id == conn.toWaypointId,
          orElse: () => _waypoints.first);

      if (fromWp.floor != _currentFloor && toWp.floor != _currentFloor) {
        continue;
      }

      final from = Offset(fromWp.xCoordinate, fromWp.yCoordinate);
      final to = Offset(toWp.xCoordinate, toWp.yCoordinate);
      final nearest = _nearestPointOnSegment(pos, from, to);

      if ((pos - nearest).distance < maxDeviation) {
        return true;
      }
    }

    return false;
  }

  // Find nearest point on a line segment
  Offset _nearestPointOnSegment(
      Offset point, Offset lineStart, Offset lineEnd) {
    final dx = lineEnd.dx - lineStart.dx;
    final dy = lineEnd.dy - lineStart.dy;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      return lineStart; // Line segment is a point
    }

    // Parameter t determines where on the segment the nearest point is
    var t = ((point.dx - lineStart.dx) * dx + (point.dy - lineStart.dy) * dy) /
        lengthSquared;
    t = t.clamp(0.0, 1.0); // Clamp to segment

    return Offset(
      lineStart.dx + t * dx,
      lineStart.dy + t * dy,
    );
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
