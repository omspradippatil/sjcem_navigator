import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../utils/kalman_filter.dart';
import '../utils/constants.dart';

class NavigationProvider extends ChangeNotifier {
  // Current position
  double _currentX = 0;
  double _currentY = 0;
  double _heading = 0;
  
  // Target room for navigation
  Room? _targetRoom;
  
  // All rooms
  List<Room> _rooms = [];
  
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

  // Getters
  double get currentX => _currentX;
  double get currentY => _currentY;
  double get heading => _heading;
  Room? get targetRoom => _targetRoom;
  List<Room> get rooms => _rooms;
  bool get positionSet => _positionSet;
  bool get isNavigating => _isNavigating;
  bool get sensorsActive => _sensorsActive;
  bool get isAdminMode => _isAdminMode;
  int get stepCount => _stepCount;
  
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
  }

  Future<void> _loadRooms() async {
    _rooms = await SupabaseService.getRooms();
    notifyListeners();
  }

  Future<void> refreshRooms() async {
    await _loadRooms();
  }

  void setInitialPosition(double x, double y) {
    _currentX = x;
    _currentY = y;
    _positionSet = true;
    _sensorFusion.setPosition(x, y);
    notifyListeners();
  }

  void setTargetRoom(Room? room) {
    _targetRoom = room;
    _isNavigating = room != null;
    notifyListeners();
  }

  void navigateToRoom(Room room) {
    _targetRoom = room;
    _isNavigating = true;
    if (!_positionSet) {
      // Default starting position if not set
      setInitialPosition(350, 550);
    }
    notifyListeners();
  }

  void stopNavigation() {
    _targetRoom = null;
    _isNavigating = false;
    notifyListeners();
  }

  void startSensors() {
    if (_sensorsActive) return;
    _sensorsActive = true;
    
    // Accelerometer for step detection
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      _sensorFusion.updateAccelerometer(event.x, event.y, event.z);
      
      if (_positionSet && _sensorFusion.detectStep()) {
        _stepCount++;
        final (x, y) = _sensorFusion.processStep();
        _updatePosition(x, y);
      }
    });
    
    // Magnetometer for heading
    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      // Calculate heading from magnetometer
      final heading = atan2(event.y, event.x) * 180 / pi;
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
    
    notifyListeners();
  }

  void stopSensors() {
    _sensorsActive = false;
    _accelerometerSubscription?.cancel();
    _magnetometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    notifyListeners();
  }

  void _updatePosition(double x, double y) {
    // Clamp to map bounds
    _currentX = x.clamp(0, AppConstants.mapWidth);
    _currentY = y.clamp(0, AppConstants.mapHeight);
    
    // Check if reached destination
    if (_isNavigating && hasReachedDestination) {
      // Could trigger a notification or haptic feedback
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
        pow(room.xCoordinate - x, 2) +
        pow(room.yCoordinate - y, 2),
      );
      if (distance < threshold && distance < minDistance) {
        nearest = room;
        minDistance = distance;
      }
    }
    
    return nearest;
  }

  // Get path points for navigation (simple straight line)
  List<Offset> getNavigationPath() {
    if (!_positionSet || _targetRoom == null) return [];
    
    return [
      Offset(_currentX, _currentY),
      Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
    ];
  }

  @override
  void dispose() {
    stopSensors();
    super.dispose();
  }
}
