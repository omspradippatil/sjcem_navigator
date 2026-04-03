import 'dart:async';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';
import '../utils/kalman_filter.dart';
import '../utils/constants.dart';

/// Types of haptic feedback
enum HapticFeedbackType { light, medium, heavy, selection }

class _NextFloorTransition {
  final String fromWaypointId;
  final String toWaypointId;
  final String transitionWaypointId;
  final int nextFloor;

  const _NextFloorTransition({
    required this.fromWaypointId,
    required this.toWaypointId,
    required this.transitionWaypointId,
    required this.nextFloor,
  });

  String get key => '$fromWaypointId->$toWaypointId';
}

class _WaypointRouteResult {
  final List<String> waypointIds;

  const _WaypointRouteResult({
    required this.waypointIds,
  });
}

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

  // Haptic feedback control (can be disabled on logout)
  bool _vibrationEnabled = true;

  // Admin mode
  bool _isAdminMode = false;

  // Admin edit mode: 'normal', 'quickAdd', 'connect', 'delete'
  String _adminEditMode = 'normal';

  // Selected waypoint for connecting
  NavigationWaypoint? _selectedWaypointForConnect;

  // Computed path
  List<Offset> _computedPath = [];
  List<String> _computedPathWaypointIds = [];

  // Multi-floor navigation transition prompt state
  String? _pendingFloorTransitionKey;
  String? _pendingFloorTransitionWaypointId;
  int? _pendingFloorTransitionTargetFloor;
  String? _lastPromptedFloorTransitionKey;
  final Set<String> _completedFloorTransitionKeys = {};

  // Manual floor switch confirmation state (shown immediately after floor change)
  int? _pendingManualFloorConfirmationFloor;
  int _manualFloorPromptVersion = 0;

  // Calibration state
  bool _isCalibrating = false;
  bool _isCalibrated = false;
  double _headingOffset = 0;

  // Enhanced calibration
  final List<double> _calibrationReadings = [];
  static const int _calibrationSampleCount = 10;

  // Magnetometer readings
  double _rawMagnetometerHeading = 0;

  // Debug info for sensor status
  double _lastAccelMagnitude = 0;
  double _lastDeviation = 0;
  double _dynamicThreshold = 1.2;
  bool _lastStepDetected = false;

  // Gyroscope-based heading mirror (read-only, set from SensorFusion)
  double _gyroHeading = 0;

  // Heading stability (prevent UI jitter)
  double _stableHeading = 0;
  final List<double> _headingBuffer = [];
  static const int _headingBufferSize = 12;
  static const double _headingChangeThreshold = 5.0;

  // Movement-based calibration
  final List<Offset> _movementHistory = [];
  static const int _movementHistorySize = 5;
  double _movementBasedHeading = 0;
  double _movementHeadingConfidence = 0.0;
  bool _hasMovementHeading = false;
  static const double _movementSampleMinDistance = 8.0;
  static const double _movementConfidenceThreshold = 0.72;

  // Auto-calibration state
  bool _autoCalibrationPending = false;

  // ── Turn detection & post-turn recalibration ──────────────────────────────
  /// True while the device is actively turning (heading changed ≥25° from last step)
  bool _isTurning = false;
  /// Heading at the start of the last detected turn
  double _preTurnHeading = 0;
  /// How many consecutive steps we have been in 'turn' state
  int _turnStepCount = 0;
  static const double _turnAngleThreshold = 25.0; // degrees
  static const int _turnSettleSteps = 2; // steps before we recalibrate

  // ── Heading lock (after corner recalibration) ────────────────────────────
  /// Locked heading that bypass stabilization buffer smoothing
  double? _headingLocked;
  /// Steps remaining to hold the lock
  int _headingLockSteps = 0;
  static const int _headingLockDurationSteps = 5; // ~250ms at 20Hz

  // ── Indoor segment tracking ───────────────────────────────────────────────
  /// The path-segment index the user is currently locked onto
  int _currentSegmentIndex = -1;

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
  bool get vibrationEnabled => _vibrationEnabled;
  bool get isAdminMode => _isAdminMode;
  String get adminEditMode => _adminEditMode;
  NavigationWaypoint? get selectedWaypointForConnect =>
      _selectedWaypointForConnect;
  int get stepCount => _stepCount;
  bool get isCalibrating => _isCalibrating;
  bool get isCalibrated => _isCalibrated;
  bool get hasPendingFloorTransitionPrompt =>
      _pendingFloorTransitionKey != null &&
      _pendingFloorTransitionTargetFloor != null &&
      _pendingFloorTransitionWaypointId != null;
  String? get pendingFloorTransitionKey => _pendingFloorTransitionKey;
  int? get pendingFloorTransitionTargetFloor => _pendingFloorTransitionTargetFloor;
  NavigationWaypoint? get pendingFloorTransitionWaypoint =>
      _pendingFloorTransitionWaypointId == null
          ? null
          : _waypoints.firstWhereOrNull(
              (w) => w.id == _pendingFloorTransitionWaypointId,
            );
  bool get hasPendingManualFloorConfirmation =>
      _pendingManualFloorConfirmationFloor != null;
  int? get pendingManualFloorConfirmationFloor =>
      _pendingManualFloorConfirmationFloor;
  String? get pendingManualFloorConfirmationKey =>
      _pendingManualFloorConfirmationFloor == null
          ? null
          : 'manual-floor-${_pendingManualFloorConfirmationFloor!}-$_manualFloorPromptVersion';

  // Debug getters
  double get lastAccelMagnitude => _lastAccelMagnitude;
  double get lastDeviation => _lastDeviation;
  double get dynamicThreshold => _dynamicThreshold;
  bool get lastStepDetected => _lastStepDetected;
  bool get autoCalibrationPending => _autoCalibrationPending;
  bool get hasMovementHeading => _hasMovementHeading;
  bool get isTurning => _isTurning;
  double get gyroHeading => _gyroHeading; // mirror from SensorFusion

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
    _hapticFeedback(HapticFeedbackType.medium);

    if (_isNavigating && _targetRoom != null) {
      _computePath();
    }

    notifyListeners();
  }

  bool _isVerticalTransitionWaypoint(NavigationWaypoint waypoint) {
    final type = waypoint.waypointType.toLowerCase();
    return type == 'stairs' || type == 'elevator';
  }

  void setCurrentFloor(int floor) {
    if (_currentFloor == floor) return;
    final previousFloor = _currentFloor;
    _currentFloor = floor;

    // Allow cross-floor connect mode only for stairs/elevator waypoints.
    if (_selectedWaypointForConnect != null &&
        _selectedWaypointForConnect!.floor != floor &&
        !_isVerticalTransitionWaypoint(_selectedWaypointForConnect!)) {
      _selectedWaypointForConnect = null;
    }

    if (_isNavigating && _targetRoom != null) {
      _computePath();
      _evaluateFloorTransitionPrompt();

      // As soon as floor changes during active navigation, request confirmation
      // so we can recalibrate heading/path for smoother transition.
      if (!_isAdminMode && previousFloor != floor) {
        _pendingManualFloorConfirmationFloor = floor;
        _manualFloorPromptVersion++;
      }
    }
    notifyListeners();
  }

  void setTargetRoom(Room? room) {
    _targetRoom = room;
    _isNavigating = room != null;
    _pendingManualFloorConfirmationFloor = null;
    if (room != null && _positionSet) {
      _computePath();
    }
    notifyListeners();
  }

  void navigateToRoom(Room room) {
    _targetRoom = room;
    _isNavigating = true;
    _pendingManualFloorConfirmationFloor = null;
    if (!_positionSet) {
      setInitialPosition(350, 550, floor: _currentFloor);
    }
    _computePath();
    _evaluateFloorTransitionPrompt();
    notifyListeners();
  }

  void stopNavigation() {
    _targetRoom = null;
    _isNavigating = false;
    _computedPath = [];
    _computedPathWaypointIds = [];
    _pendingFloorTransitionKey = null;
    _pendingFloorTransitionWaypointId = null;
    _pendingFloorTransitionTargetFloor = null;
    _lastPromptedFloorTransitionKey = null;
    _completedFloorTransitionKeys.clear();
    _pendingManualFloorConfirmationFloor = null;
    notifyListeners();
  }

  void startSensors() {
    if (_sensorsActive) return;
    _sensorsActive = true;

    // ── Accelerometer: 50 Hz – step detection ─────────────────────────────
    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen((event) {
      _sensorFusion.updateAccelerometer(event.x, event.y, event.z);

      _lastAccelMagnitude = _sensorFusion.lastMagnitude;
      _lastDeviation     = _sensorFusion.lastDeviation;
      _dynamicThreshold  = _sensorFusion.dynamicThreshold;

      if (_positionSet && _sensorFusion.detectStep()) {
        _stepCount++;
        _lastStepDetected = true;
        final (x, y) = _sensorFusion.processStep();
        _updatePosition(x, y);
        _hapticFeedback(HapticFeedbackType.light);
        notifyListeners();
      } else {
        _lastStepDetected = false;
      }
    });

    // ── Magnetometer: 10 Hz – absolute heading reference ─────────────────
    // SensorFusion now owns the full Kalman + complementary pipeline.
    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      // Raw compass heading from X/Y field components
      double rawHeading = atan2(event.y, event.x) * 180 / pi;
      rawHeading = (rawHeading + 360) % 360;
      _rawMagnetometerHeading = rawHeading;

      // Apply user calibration offset, then feed into SensorFusion.
      // SensorFusion runs: mag → AngularKalman → complementary with gyro → fused.
      final correctedRaw = (rawHeading + _headingOffset + 360) % 360;
      final fused = _sensorFusion.updateMagnetometer(correctedRaw);

      // If heading is locked (e.g., after corner recalibration), bypass stabilization
      // and hold the exact locked value for a moment
      if (_headingLocked != null && _headingLockSteps > 0) {
        _heading = _headingLocked!;
        _headingLockSteps--;
      } else {
        // Stabilise for UI (prevents micro-jitter on the compass arrow)
        _heading = _stabilizeHeading(fused);
        _headingLocked = null;
      }
      notifyListeners();
    });

    // ── Gyroscope: 20 Hz – fast heading tracking ──────────────────────────
    // Feeds directly into SensorFusion so the complementary filter
    // stays in sync without duplicating integration logic here.
    _gyroscopeSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen((event) {
      _sensorFusion.updateGyroscope(event.z);
      // Keep _gyroHeading in sync for calibration helpers
      _gyroHeading = _sensorFusion.fusedHeading;
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

  /// Enable or disable haptic feedback vibrations
  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
    notifyListeners();
  }

  /// Perform haptic feedback if vibration is enabled
  void _hapticFeedback(HapticFeedbackType type) {
    if (!_vibrationEnabled) return;
    switch (type) {
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
        break;
    }
  }

  void startCalibration() {
    _isCalibrating = true;
    notifyListeners();
  }

  void setCalibrationHeading(double actualHeading) {
    _headingOffset = (actualHeading - _rawMagnetometerHeading + 360) % 360;
    _sensorFusion.overrideHeading(actualHeading);
    _heading = actualHeading;
    _stableHeading = actualHeading;
    _headingBuffer.clear();
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

    // Average of samples → this is our "zero" reference for north
    final meanHeading = _calculateCircularMean(_calibrationReadings);
    // Offset so that the corrected heading = 0 (north) on startup
    _headingOffset = (360 - meanHeading) % 360;
    // Bootstrap SensorFusion to the corrected starting heading
    _sensorFusion.overrideHeading(0);
    _heading = 0;
    _stableHeading = 0;
    _headingBuffer.clear();
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

    // Calculate heading from multiple recent movement segments instead of a
    // single start-to-end vector. This is more stable in corners and zig-zags.
    if (_movementHistory.length >= 3) {
      final headings = <double>[];
      double totalDistance = 0.0;

      for (int i = 1; i < _movementHistory.length; i++) {
        final previous = _movementHistory[i - 1];
        final current = _movementHistory[i];
        final dx = current.dx - previous.dx;
        final dy = current.dy - previous.dy;
        final distance = sqrt(dx * dx + dy * dy);

        if (distance < _movementSampleMinDistance) continue;

        totalDistance += distance;
        headings.add((atan2(-dy, dx) * 180 / pi + 90 + 360) % 360);
      }

      if (headings.isNotEmpty && totalDistance > 20) {
        final meanHeading = _calculateCircularMean(headings);
        double meanDeviation = 0.0;

        for (final heading in headings) {
          meanDeviation += _angleDiff(heading, meanHeading).abs();
        }
        meanDeviation /= headings.length;

        _movementBasedHeading = meanHeading;
        _movementHeadingConfidence = (1.0 - (meanDeviation / 45.0)).clamp(0.0, 1.0).toDouble();
        _hasMovementHeading = _movementHeadingConfidence >= _movementConfidenceThreshold;

        // If auto-calibration is pending, complete it only when confidence is high.
        if (_autoCalibrationPending && _hasMovementHeading) {
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
    _movementHeadingConfidence = 0.0;
    _isCalibrating = true;
    notifyListeners();
  }

  void _completeAutoCalibration() {
    if (!_hasMovementHeading || _movementHeadingConfidence < _movementConfidenceThreshold) {
      return;
    }

    // Offset: make sensor match map movement direction
    _headingOffset = (_movementBasedHeading - _rawMagnetometerHeading + 360) % 360;

    // Override the full SensorFusion pipeline to the calibrated heading
    _sensorFusion.overrideHeading(_movementBasedHeading);
    _gyroHeading = _movementBasedHeading;
    _heading = _movementBasedHeading;
    _stableHeading = _movementBasedHeading;
    _headingBuffer.clear();

    _autoCalibrationPending = false;
    _isCalibrating = false;
    _isCalibrated = true;
    _movementHistory.clear();
    _movementHeadingConfidence = 0.0;
    notifyListeners();
  }

  // Quick calibration: face a known direction and calibrate instantly
  void calibrateToDirection(double mapDirection) {
    _headingOffset = (mapDirection - _rawMagnetometerHeading + 360) % 360;
    _sensorFusion.overrideHeading(mapDirection);
    _gyroHeading = mapDirection;
    _heading = mapDirection;
    _stableHeading = mapDirection;
    _headingBuffer.clear();
    _movementHistory.clear();
    _movementBasedHeading = mapDirection;
    _movementHeadingConfidence = 1.0;
    _autoCalibrationPending = false;
    _isCalibrating = false;
    _isCalibrated = true;
    notifyListeners();
  }

  // Cancel auto-calibration
  void cancelAutoCalibration() {
    _autoCalibrationPending = false;
    _isCalibrating = false;
    _movementHistory.clear();
    _movementHeadingConfidence = 0.0;
    notifyListeners();
  }

  void _updatePosition(double x, double y) {
    // ── 1. Detect turn before constraining ──────────────────────────────────
    _detectAndHandleTurn();

    // ── 2. Constrain to walkable area with junction detection ───────────────
    final (constrainedPos, passedJunction) = _constrainWithJunctionDetection(x, y);
    _currentX = constrainedPos.dx.clamp(0, AppConstants.mapWidth);
    _currentY = constrainedPos.dy.clamp(0, AppConstants.mapHeight);

    // ── 3. If we just passed through a corner junction, recalibrate ─────────
    if (passedJunction != null) {
      _cornerRecalibrate(passedJunction);
    }

    // ── 4. Track movement for auto-calibration ───────────────────────────────
    _trackMovement(_currentX, _currentY);

    if (_isNavigating && hasReachedDestination) {
      _hapticFeedback(HapticFeedbackType.heavy);
    }

    if (_isNavigating && _targetRoom != null) {
      _computePath();
      _evaluateFloorTransitionPrompt();
    }

    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TURN DETECTION & POST-TURN RECALIBRATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Called once per step. Detects significant heading changes (turns) and
  /// when the heading stabilises after a turn, recalibrates heading + path
  /// segment to match the actual corridor direction.
  void _detectAndHandleTurn() {
    if (!_isNavigating) return;

    final currentHeading = _heading;
    final diff = _angleDiff(currentHeading, _preTurnHeading);

    if (diff.abs() >= _turnAngleThreshold) {
      // We are currently turning
      _turnStepCount++;
      if (!_isTurning) {
        _isTurning = true;
        debugPrint('🔄 Turn detected (diff=${diff.toStringAsFixed(1)}°)');
      }
    } else {
      if (_isTurning && _turnStepCount >= _turnSettleSteps) {
        // Turn has settled – recalibrate to nearest corridor direction
        _postTurnRecalibrate();
      }
      _isTurning = false;
      _turnStepCount = 0;
      _preTurnHeading = currentHeading;
    }
  }

  /// After a turn settles, snap the heading to the nearest valid path-segment
  /// direction and reset calibration so subsequent steps stay aligned.
  void _postTurnRecalibrate() {
    if (!_isNavigating || _waypoints.isEmpty || _waypointConnections.isEmpty) {
      debugPrint('↩️ Post-turn recalibrate: path unavailable, skipping');
      return;
    }

    final pos = Offset(_currentX, _currentY);
    double? bestSegmentHeading;
    double minDist = double.infinity;

    for (final conn in _waypointConnections) {
      final fromWp = _waypoints.firstWhereOrNull((w) => w.id == conn.fromWaypointId);
      final toWp = _waypoints.firstWhereOrNull((w) => w.id == conn.toWaypointId);
      if (fromWp == null || toWp == null) continue;
      if (fromWp.floor != _currentFloor && toWp.floor != _currentFloor) continue;

      final from = Offset(fromWp.xCoordinate, fromWp.yCoordinate);
      final to = Offset(toWp.xCoordinate, toWp.yCoordinate);
      final nearest = _nearestPointOnSegment(pos, from, to);
      final dist = (pos - nearest).distance;

      if (dist < minDist) {
        minDist = dist;
        final dx = to.dx - from.dx;
        final dy = to.dy - from.dy;
        // Map heading: 0=up(-Y), 90=right(+X)
        bestSegmentHeading = (atan2(dx, -dy) * 180 / pi + 360) % 360;

        // Choose forward vs backward based on current heading
        final reverseHeading = (bestSegmentHeading + 180) % 360;
        if (_angleDiff(reverseHeading, _heading).abs() <
            _angleDiff(bestSegmentHeading, _heading).abs()) {
          bestSegmentHeading = reverseHeading;
        }
      }
    }

    if (bestSegmentHeading != null) {
      debugPrint(
          '↩️ Post-turn recalibrate: snapping heading to ${bestSegmentHeading.toStringAsFixed(1)}°');

      _headingBuffer.clear();
      _stableHeading = bestSegmentHeading;
      _headingOffset = (bestSegmentHeading - _rawMagnetometerHeading + 360) % 360;
      _sensorFusion.overrideHeading(bestSegmentHeading);
      _gyroHeading = bestSegmentHeading;
      _heading = bestSegmentHeading;
      _isCalibrated = true;

      _hapticFeedback(HapticFeedbackType.medium);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CORNER / JUNCTION RECALIBRATION  (map-based, position-authoritative)
  // ─────────────────────────────────────────────────────────────────────────

  /// Last waypoint junction that we recalibrated at (avoid re-firing)
  String? _lastRecalibratedJunctionId;

  /// Combined constraint + junction detection. Returns the constrained position
  /// and, if a corner junction was just entered, the junction waypoint.
  (Offset, NavigationWaypoint?) _constrainWithJunctionDetection(double x, double y) {
    if (_waypoints.isEmpty || _waypointConnections.isEmpty) {
      return (Offset(x, y), null);
    }

    final pos = Offset(x, y);
    final floorConnections = _waypointConnections.where((conn) {
      final fw = _waypoints.firstWhereOrNull((w) => w.id == conn.fromWaypointId);
      final tw = _waypoints.firstWhereOrNull((w) => w.id == conn.toWaypointId);
      return fw != null && tw != null &&
          (fw.floor == _currentFloor || tw.floor == _currentFloor);
    }).toList();

    if (floorConnections.isEmpty) return (Offset(x, y), null);

    // Find best path segment
    double minDistance = double.infinity;
    Offset bestPoint = pos;
    int bestSegIdx = -1;

    for (int i = 0; i < floorConnections.length; i++) {
      final conn = floorConnections[i];
      final fromWp = _waypoints.firstWhereOrNull((w) => w.id == conn.fromWaypointId);
      final toWp = _waypoints.firstWhereOrNull((w) => w.id == conn.toWaypointId);
      if (fromWp == null || toWp == null) continue;
      final from = Offset(fromWp.xCoordinate, fromWp.yCoordinate);
      final to = Offset(toWp.xCoordinate, toWp.yCoordinate);
      final nearest = _nearestPointOnSegment(pos, from, to);
      final dist = (pos - nearest).distance;
      final biasedDist = (i == _currentSegmentIndex) ? dist - 15.0 : dist;
      if (biasedDist < minDistance) {
        minDistance = biasedDist;
        bestPoint = nearest;
        bestSegIdx = i;
      }
    }
    _currentSegmentIndex = bestSegIdx;

    // Check junction snapping – also check if it is a real CORNER
    NavigationWaypoint? passedCorner;
    bool nearAnyJunction = false;

    for (final wp in _waypoints.where((w) => w.floor == _currentFloor)) {
      final wpPos = Offset(wp.xCoordinate, wp.yCoordinate);
      final dist = (pos - wpPos).distance;

      if (dist < 28 && dist < minDistance + 15) {
        nearAnyJunction = true;
        bestPoint = wpPos;
        _currentSegmentIndex = -1; // re-evaluate segment at next step

        // Is this a CORNER junction (direction change)?
        if (wp.id != _lastRecalibratedJunctionId && _isCornerJunction(wp)) {
          passedCorner = wp;
        }
        break;
      }
    }

    // Once we move far enough away from all junctions, reset the guard
    // so revisiting the same junction later re-fires recalibration.
    if (!nearAnyJunction && _lastRecalibratedJunctionId != null) {
      final lastJunction = _waypoints.firstWhereOrNull(
          (w) => w.id == _lastRecalibratedJunctionId);
      if (lastJunction != null) {
        final junctionPos = Offset(
            lastJunction.xCoordinate, lastJunction.yCoordinate);
        if ((pos - junctionPos).distance > 45) {
          _lastRecalibratedJunctionId = null;
        }
      }
    }

    return (bestPoint, passedCorner);
  }

  /// Returns true when this waypoint is a corner – meaning it connects two or
  /// more segments whose directions differ by more than 20°, i.e. it's not
  /// just a straight-line mid-point.
  bool _isCornerJunction(NavigationWaypoint wp) {
    final connectedSegmentDirections = <double>[];

    for (final conn in _waypointConnections) {
      NavigationWaypoint? other;
      if (conn.fromWaypointId == wp.id) {
        other = _waypoints.firstWhereOrNull((w) => w.id == conn.toWaypointId);
      } else if (conn.toWaypointId == wp.id) {
        other = _waypoints.firstWhereOrNull((w) => w.id == conn.fromWaypointId);
      }
      if (other == null || other.floor != _currentFloor) continue;

      final dx = other.xCoordinate - wp.xCoordinate;
      final dy = other.yCoordinate - wp.yCoordinate;
      // Map heading: 0=up(-Y), 90=right(+X)
      connectedSegmentDirections.add((atan2(dx, -dy) * 180 / pi + 360) % 360);
    }

    if (connectedSegmentDirections.length < 2) return false;

    // If any two connected directions differ by more than 20° it's a corner
    for (int i = 0; i < connectedSegmentDirections.length; i++) {
      for (int j = i + 1; j < connectedSegmentDirections.length; j++) {
        final delta = _angleDiff(
            connectedSegmentDirections[i], connectedSegmentDirections[j]);
        if (delta.abs() > 20) return true;
      }
    }
    return false;
  }

  /// Position-based recalibration triggered when the user passes through a
  /// waypoint junction that changes direction (a real corner / turn).
  /// Picks the outgoing segment on the computed navigation path and snaps
  /// the heading + magnetometer offset + gyro to that corridor direction.
  void _cornerRecalibrate(NavigationWaypoint junction) {
    _lastRecalibratedJunctionId = junction.id;
    debugPrint(
        '🞧 Corner recalibrate at "${junction.name ?? junction.id}"');

    // Determine the outgoing direction from the computed path
    double? outgoingHeading;

    if (_computedPath.length >= 2) {
      // Find the path node immediately after the junction position
      final junctionPos = Offset(junction.xCoordinate, junction.yCoordinate);
      int junctionIndex = -1;
      double minDist = double.infinity;
      for (int i = 0; i < _computedPath.length; i++) {
        final d = (_computedPath[i] - junctionPos).distance;
        if (d < minDist) {
          minDist = d;
          junctionIndex = i;
        }
      }

      if (junctionIndex >= 0 && junctionIndex < _computedPath.length - 1) {
        final next = _computedPath[junctionIndex + 1];
        final dx = next.dx - junctionPos.dx;
        final dy = next.dy - junctionPos.dy;
        if (dx.abs() + dy.abs() > 1) {
          outgoingHeading = (atan2(dx, -dy) * 180 / pi + 360) % 360;
          debugPrint('   ✓ Outgoing from path: ${outgoingHeading.toStringAsFixed(1)}°');
        }
      }
    }

    // Fall back to nearest corridor direction if path lookup fails
    if (outgoingHeading == null) {
      outgoingHeading = _nearestCorridorHeading(junction);
      if (outgoingHeading != null) {
        debugPrint('   ⟲ Fallback to nearest corridor: ${outgoingHeading.toStringAsFixed(1)}°');
      }
    }

    if (outgoingHeading == null) {
      debugPrint('   ✗ No outgoing corridor found');
      return;
    }

    debugPrint(
        '🞧 Snapping heading to outgoing corridor: ${outgoingHeading.toStringAsFixed(1)}°');

    // Flush stabilisation buffer so change takes effect immediately
    _headingBuffer.clear();
    _stableHeading = outgoingHeading;

    // Recalibrate magnetometer offset & override SensorFusion pipeline
    _headingOffset = (outgoingHeading - _rawMagnetometerHeading + 360) % 360;
    _sensorFusion.overrideHeading(outgoingHeading);

    // Sync gyro mirror
    _gyroHeading = outgoingHeading;
    _heading = outgoingHeading;
    _isCalibrated = true;

    // LOCK heading to prevent stabilization buffer from smoothing it away
    _headingLocked = outgoingHeading;
    _headingLockSteps = _headingLockDurationSteps;

    // Pulse haptic to signal the recalibration event
    _hapticFeedback(HapticFeedbackType.medium);

    // Clear turn state so we don't double-fire from heading-based logic
    _isTurning = false;
    _turnStepCount = 0;
    _preTurnHeading = outgoingHeading;
  }

  /// Among all segments connected to [junction], return the heading of
  /// the one that is closest to the current movement direction.
  /// Prioritizes the next waypoint in _computedPath if available.
  double? _nearestCorridorHeading(NavigationWaypoint junction) {
    // Try to find the next waypoint in the path for this junction
    if (_computedPathWaypointIds.length >= 2) {
      final junctionIdx = _computedPathWaypointIds.indexOf(junction.id);
      if (junctionIdx >= 0 && junctionIdx < _computedPathWaypointIds.length - 1) {
        final nextWaypointId = _computedPathWaypointIds[junctionIdx + 1];
        final nextWaypoint = _waypoints.firstWhereOrNull((w) => w.id == nextWaypointId);
        if (nextWaypoint != null && nextWaypoint.floor == _currentFloor) {
          final dx = nextWaypoint.xCoordinate - junction.xCoordinate;
          final dy = nextWaypoint.yCoordinate - junction.yCoordinate;
          final pathHeading = (atan2(dx, -dy) * 180 / pi + 360) % 360;
          debugPrint('   ✓ Next waypoint in path: ${nextWaypoint.name ?? nextWaypoint.id} → $pathHeading°');
          return pathHeading;
        }
      }
    }

    // Fallback: find corridor closest to current heading
    double? best;
    double bestDiff = double.infinity;

    for (final conn in _waypointConnections) {
      NavigationWaypoint? other;
      if (conn.fromWaypointId == junction.id) {
        other = _waypoints.firstWhereOrNull((w) => w.id == conn.toWaypointId);
      } else if (conn.toWaypointId == junction.id && conn.isBidirectional) {
        other = _waypoints.firstWhereOrNull((w) => w.id == conn.fromWaypointId);
      }
      if (other == null || other.floor != _currentFloor) continue;

      final dx = other.xCoordinate - junction.xCoordinate;
      final dy = other.yCoordinate - junction.yCoordinate;
      final segHeading = (atan2(dx, -dy) * 180 / pi + 360) % 360;
      final diff = _angleDiff(segHeading, _heading).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = segHeading;
      }
    }
    return best;
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
    _computedPathWaypointIds = [];
    _pendingFloorTransitionKey = null;
    _pendingFloorTransitionWaypointId = null;
    _pendingFloorTransitionTargetFloor = null;
    _lastPromptedFloorTransitionKey = null;
    _completedFloorTransitionKeys.clear();
    _pendingManualFloorConfirmationFloor = null;
    _headingLocked = null;
    _headingLockSteps = 0;
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

  Future<NavigationWaypoint?> updateWaypoint({
    required String waypointId,
    required String name,
    required int floor,
    required double x,
    required double y,
    String waypointType = 'junction',
    String? description,
    String? photoUrl,
  }) async {
    final waypoint = NavigationWaypoint(
      id: waypointId,
      name: name,
      floor: floor,
      xCoordinate: x,
      yCoordinate: y,
      waypointType: waypointType,
      description: description,
      photoUrl: photoUrl,
    );

    final updatedWaypoint = await SupabaseService.updateWaypoint(waypoint);
    if (updatedWaypoint != null) {
      await _loadWaypoints();
      _computePath();
    }
    return updatedWaypoint;
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
    final fromWp = _waypoints.firstWhereOrNull((w) => w.id == fromWaypointId);
    final toWp = _waypoints.firstWhereOrNull((w) => w.id == toWaypointId);
    if (fromWp == null || toWp == null || fromWp.id == toWp.id) {
      return null;
    }

    // Cross-floor links are only valid for same-type vertical transitions.
    if (fromWp.floor != toWp.floor) {
      final fromType = fromWp.waypointType.toLowerCase();
      final toType = toWp.waypointType.toLowerCase();
      final isValidVerticalPair =
          (fromType == 'stairs' || fromType == 'elevator') &&
              fromType == toType;
      if (!isValidVerticalPair) {
        return null;
      }
    }

    // Calculate distance if not provided
    double calculatedDistance = distance ?? 0;
    if (distance == null) {
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

  NavigationWaypoint? getWaypointAtPosition(
    double x,
    double y, {
    double threshold = 30,
    int? floor,
  }) {
    NavigationWaypoint? nearest;
    double minDistance = double.infinity;

    final candidateWaypoints = floor == null
        ? _waypoints
        : _waypoints.where((waypoint) => waypoint.floor == floor);

    for (final waypoint in candidateWaypoints) {
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

  Room? getRoomAtPosition(
    double x,
    double y, {
    double threshold = 50,
    int? floor,
  }) {
    Room? nearest;
    double minDistance = double.infinity;

    final candidateRooms = floor == null
        ? _rooms
        : _rooms.where((room) => room.floor == floor);

    for (final room in candidateRooms) {
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
      _computedPathWaypointIds = [];
      return;
    }

    if (_waypoints.isEmpty) {
      _computedPathWaypointIds = [];
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
    final startCandidates = _findNearestWaypoints(
      start.dx,
      start.dy,
      preferredFloor: _currentFloor,
      maxCandidates: 6,
    );
    final endCandidates = _findNearestWaypoints(
      end.dx,
      end.dy,
      preferredFloor: _targetRoom?.floor,
      maxCandidates: 6,
    );

    if (startCandidates.isEmpty || endCandidates.isEmpty) {
      _computedPathWaypointIds = [];
      return [start, end];
    }

    final best = _findBestWaypointRoute(
      start: start,
      end: end,
      startCandidates: startCandidates,
      endCandidates: endCandidates,
    );

    if (best == null) {
      _computedPathWaypointIds = [];
      return [start, end];
    }

    _computedPathWaypointIds = best.waypointIds;
    return _buildOffsetPathFromWaypointIds(start, end, best.waypointIds);
  }

  _WaypointRouteResult? _findBestWaypointRoute({
    required Offset start,
    required Offset end,
    required List<NavigationWaypoint> startCandidates,
    required List<NavigationWaypoint> endCandidates,
  }) {
    double bestCost = double.infinity;
    List<String>? bestPathIds;

    for (final startWp in startCandidates) {
      for (final endWp in endCandidates) {
        final waypointIds = _runAStar(startWp.id, endWp.id);
        if (waypointIds.isEmpty) continue;

        final graphCost = _polylineLengthFromWaypointIds(waypointIds);
        final first = Offset(startWp.xCoordinate, startWp.yCoordinate);
        final last = Offset(endWp.xCoordinate, endWp.yCoordinate);
        final attachCost = (start - first).distance + (end - last).distance;
        final totalCost = graphCost + attachCost;

        if (totalCost < bestCost) {
          bestCost = totalCost;
          bestPathIds = waypointIds;
        }
      }
    }

    if (bestPathIds == null) return null;
    return _WaypointRouteResult(waypointIds: bestPathIds);
  }

  /// A* pathfinding on the waypoint graph.
  /// Floor transitions (stair/elevator connections) incur an extra cost
  /// penalty so that same-floor routes are always preferred unless the
  /// destination is genuinely on another floor.
  List<String> _runAStar(String startWaypointId, String endWaypointId) {
    if (startWaypointId == endWaypointId) {
      return [startWaypointId];
    }

    final wpById = {for (final wp in _waypoints) wp.id: wp};

    // Build adjacency: each edge carries its Euclidean distance plus any
    // floor-transition penalty.
    // A floor jump costs an extra 200 px-equivalent so the planner strongly
    // prefers same-floor travel until it genuinely has to change floors.
    const double floorChangePenalty = 200.0;

    final Map<String, List<(String, double)>> adjacency = {
      for (final wp in _waypoints) wp.id: <(String, double)>[],
    };

    for (final conn in _waypointConnections) {
      if (!adjacency.containsKey(conn.fromWaypointId) ||
          !adjacency.containsKey(conn.toWaypointId)) {
        continue;
      }

      final fromWp = wpById[conn.fromWaypointId]!;
      final toWp   = wpById[conn.toWaypointId]!;
      final euclidean = _distance(fromWp, toWp);
      final floorPenalty = fromWp.floor != toWp.floor ? floorChangePenalty : 0.0;
      final edgeCost = euclidean + floorPenalty;

      adjacency[conn.fromWaypointId]!.add((conn.toWaypointId, edgeCost));
      if (conn.isBidirectional) {
        adjacency[conn.toWaypointId]!.add((conn.fromWaypointId, edgeCost));
      }
    }

    final gScore  = <String, double>{for (final wp in _waypoints) wp.id: double.infinity};
    final fScore  = <String, double>{for (final wp in _waypoints) wp.id: double.infinity};
    final cameFrom = <String, String?>{};
    final openSet  = <String>{startWaypointId};
    final closedSet = <String>{};

    final endWp   = wpById[endWaypointId];
    final startWp = wpById[startWaypointId];
    if (startWp == null || endWp == null) return [];

    gScore[startWaypointId] = 0;
    fScore[startWaypointId] = _heuristic(startWp, endWp);

    while (openSet.isNotEmpty) {
      final current = openSet.reduce((a, b) =>
          (fScore[a] ?? double.infinity) < (fScore[b] ?? double.infinity) ? a : b);

      if (current == endWaypointId) {
        final path = <String>[];
        String? node = current;
        while (node != null) {
          path.insert(0, node);
          node = cameFrom[node];
        }
        return path;
      }

      openSet.remove(current);
      closedSet.add(current);

      for (final (neighborId, edgeCost) in adjacency[current] ?? const <(String,double)>[]) {
        if (closedSet.contains(neighborId)) continue;
        final neighborWp = wpById[neighborId];
        if (neighborWp == null) continue;

        final tentativeG = (gScore[current] ?? double.infinity) + edgeCost;

        if (!openSet.contains(neighborId)) {
          openSet.add(neighborId);
        } else if (tentativeG >= (gScore[neighborId] ?? double.infinity)) {
          continue;
        }

        cameFrom[neighborId] = current;
        gScore[neighborId]   = tentativeG;
        fScore[neighborId]   = tentativeG + _heuristic(neighborWp, endWp);
      }
    }

    return [];
  }

  List<Offset> _buildOffsetPathFromWaypointIds(
    Offset start,
    Offset end,
    List<String> waypointIds,
  ) {
    final path = <Offset>[start];

    for (final waypointId in waypointIds) {
      final wp = _waypoints.firstWhereOrNull((w) => w.id == waypointId);
      if (wp == null) continue;
      final point = Offset(wp.xCoordinate, wp.yCoordinate);
      if ((path.last - point).distance > 0.5) {
        path.add(point);
      }
    }

    if ((path.last - end).distance > 0.5) {
      path.add(end);
    }

    return path;
  }

  double _polylineLengthFromWaypointIds(List<String> waypointIds) {
    if (waypointIds.length < 2) return 0;

    double total = 0;
    for (int i = 0; i < waypointIds.length - 1; i++) {
      final a = _waypoints.firstWhereOrNull((w) => w.id == waypointIds[i]);
      final b = _waypoints.firstWhereOrNull((w) => w.id == waypointIds[i + 1]);
      if (a == null || b == null) continue;
      total += _distance(a, b);
    }
    return total;
  }

  List<NavigationWaypoint> _findNearestWaypoints(
    double x,
    double y, {
    int? preferredFloor,
    int maxCandidates = 4,
  }) {
    final candidateWaypoints = preferredFloor == null
        ? _waypoints
        : _waypoints.where((wp) => wp.floor == preferredFloor).toList();

    final pool = candidateWaypoints.isNotEmpty ? candidateWaypoints : _waypoints;

    final sorted = [...pool]
      ..sort((a, b) {
        final da = pow(a.xCoordinate - x, 2) + pow(a.yCoordinate - y, 2);
        final db = pow(b.xCoordinate - x, 2) + pow(b.yCoordinate - y, 2);
        return da.compareTo(db);
      });

    if (sorted.length <= maxCandidates) {
      return sorted;
    }
    return sorted.sublist(0, maxCandidates);
  }

  double _heuristic(NavigationWaypoint a, NavigationWaypoint b) {
    return sqrt(pow(a.xCoordinate - b.xCoordinate, 2) +
        pow(a.yCoordinate - b.yCoordinate, 2));
  }

  double _distance(NavigationWaypoint a, NavigationWaypoint b) {
    return sqrt(pow(a.xCoordinate - b.xCoordinate, 2) +
        pow(a.yCoordinate - b.yCoordinate, 2));
  }

  // Signed shortest-path angular difference in degrees (-180..180)
  double _angleDiff(double a, double b) {
    double diff = (a - b + 540) % 360 - 180;
    return diff;
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

  List<Offset> getNavigationPathForFloor(int floor) {
    if (!_positionSet || _targetRoom == null) return [];

    if (_computedPath.isEmpty) {
      if (_currentFloor == floor && _targetRoom!.floor == floor) {
        return [
          Offset(_currentX, _currentY),
          Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate),
        ];
      }
      return [];
    }

    if (_computedPathWaypointIds.isEmpty) {
      // If waypoint data exists but no route was found, avoid drawing a
      // misleading straight line through walls/courtyards.
      if (_waypoints.isNotEmpty && _waypointConnections.isNotEmpty) {
        return [];
      }
      if (_currentFloor == floor && _targetRoom!.floor == floor) {
        return _computedPath;
      }
      return [];
    }

    final floorPath = <Offset>[];

    // ── Build path segment for this specific floor ───────────────────────────
    // Filter waypoints on this floor from the computed route (in order)
    final floorWpOffsets = _computedPathWaypointIds
        .map((id) => _waypoints.firstWhereOrNull((w) => w.id == id))
        .where((wp) => wp != null && wp.floor == floor)
        .map((wp) => Offset(wp!.xCoordinate, wp.yCoordinate))
        .toList();

    // Start: if user is currently on this floor, start from their position
    if (_currentFloor == floor) {
      floorPath.add(Offset(_currentX, _currentY));
    }

    // Add all on-floor waypoints (dedup consecutive duplicates)
    for (final pt in floorWpOffsets) {
      if (floorPath.isEmpty || (floorPath.last - pt).distance > 0.5) {
        floorPath.add(pt);
      }
    }

    // End: if destination is on this floor, append it
    if (_targetRoom!.floor == floor) {
      final targetPoint = Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate);
      if (floorPath.isEmpty || (floorPath.last - targetPoint).distance > 0.5) {
        floorPath.add(targetPoint);
      }
    }

    return floorPath.length >= 2 ? floorPath : [];
  }

  void dismissPendingManualFloorConfirmation() {
    if (!hasPendingManualFloorConfirmation) return;
    _pendingManualFloorConfirmationFloor = null;
    notifyListeners();
  }

  bool confirmPendingManualFloorConfirmationAndRecalibrate() {
    if (!hasPendingManualFloorConfirmation) return false;

    _pendingManualFloorConfirmationFloor = null;

    // Force a fresh heading calibration after manual floor switch.
    _isCalibrated = false;
    _headingBuffer.clear();
    performEnhancedCalibration();

    _computePath();
    _evaluateFloorTransitionPrompt();
    notifyListeners();
    return true;
  }

  void dismissPendingFloorTransitionPrompt() {
    if (!hasPendingFloorTransitionPrompt) return;
    _pendingFloorTransitionKey = null;
    _pendingFloorTransitionWaypointId = null;
    _pendingFloorTransitionTargetFloor = null;
    notifyListeners();
  }

  bool completePendingFloorTransitionAndRecalibrate() {
    if (!hasPendingFloorTransitionPrompt) return false;

    final transitionKey = _pendingFloorTransitionKey!;
    final transitionWaypointId = _pendingFloorTransitionWaypointId!;
    final targetFloor = _pendingFloorTransitionTargetFloor!;

    final linkedOnTargetFloor =
        _findConnectedWaypointOnFloor(transitionWaypointId, targetFloor);

    _currentFloor = targetFloor;

    if (linkedOnTargetFloor != null) {
      _currentX = linkedOnTargetFloor.xCoordinate;
      _currentY = linkedOnTargetFloor.yCoordinate;
      _sensorFusion.setPosition(_currentX, _currentY);
    }

    _completedFloorTransitionKeys.add(transitionKey);
    _pendingFloorTransitionKey = null;
    _pendingFloorTransitionWaypointId = null;
    _pendingFloorTransitionTargetFloor = null;
    _pendingManualFloorConfirmationFloor = null;

    // Force a fresh heading calibration after changing floors.
    _isCalibrated = false;
    _headingBuffer.clear();
    performEnhancedCalibration();

    _computePath();
    _evaluateFloorTransitionPrompt();
    notifyListeners();
    return true;
  }

  void _evaluateFloorTransitionPrompt() {
    if (!_isNavigating ||
        _targetRoom == null ||
        _targetRoom!.floor == _currentFloor ||
        _computedPathWaypointIds.length < 2) {
      _pendingFloorTransitionKey = null;
      _pendingFloorTransitionWaypointId = null;
      _pendingFloorTransitionTargetFloor = null;
      return;
    }

    final transition = _getNextFloorTransitionFromPath();
    if (transition == null) {
      _pendingFloorTransitionKey = null;
      _pendingFloorTransitionWaypointId = null;
      _pendingFloorTransitionTargetFloor = null;
      return;
    }

    final transitionWp =
        _waypoints.firstWhereOrNull((w) => w.id == transition.transitionWaypointId);
    if (transitionWp == null) return;

    final distanceToTransition = sqrt(
      pow(transitionWp.xCoordinate - _currentX, 2) +
          pow(transitionWp.yCoordinate - _currentY, 2),
    );

    if (distanceToTransition > 80 &&
        _lastPromptedFloorTransitionKey == transition.key) {
      _lastPromptedFloorTransitionKey = null;
    }

    if (distanceToTransition <= 45 &&
        !_completedFloorTransitionKeys.contains(transition.key) &&
        _lastPromptedFloorTransitionKey != transition.key) {
      _pendingFloorTransitionKey = transition.key;
      _pendingFloorTransitionWaypointId = transition.transitionWaypointId;
      _pendingFloorTransitionTargetFloor = transition.nextFloor;
      _lastPromptedFloorTransitionKey = transition.key;
    }
  }

  _NextFloorTransition? _getNextFloorTransitionFromPath() {
    if (_computedPathWaypointIds.length < 2) return null;

    int nearestIndexOnCurrentFloor = 0;
    double nearestDistance = double.infinity;

    for (int i = 0; i < _computedPathWaypointIds.length; i++) {
      final wp = _waypoints
          .firstWhereOrNull((w) => w.id == _computedPathWaypointIds[i]);
      if (wp == null || wp.floor != _currentFloor) continue;

      final dist = sqrt(
        pow(wp.xCoordinate - _currentX, 2) + pow(wp.yCoordinate - _currentY, 2),
      );

      if (dist < nearestDistance) {
        nearestDistance = dist;
        nearestIndexOnCurrentFloor = i;
      }
    }

    for (int i = nearestIndexOnCurrentFloor;
        i < _computedPathWaypointIds.length - 1;
        i++) {
      final fromWp = _waypoints
          .firstWhereOrNull((w) => w.id == _computedPathWaypointIds[i]);
      final toWp = _waypoints
          .firstWhereOrNull((w) => w.id == _computedPathWaypointIds[i + 1]);

      if (fromWp == null || toWp == null || fromWp.floor == toWp.floor) {
        continue;
      }

      if (fromWp.floor == _currentFloor) {
        return _NextFloorTransition(
          fromWaypointId: fromWp.id,
          toWaypointId: toWp.id,
          transitionWaypointId: fromWp.id,
          nextFloor: toWp.floor,
        );
      }

      if (toWp.floor == _currentFloor) {
        return _NextFloorTransition(
          fromWaypointId: toWp.id,
          toWaypointId: fromWp.id,
          transitionWaypointId: toWp.id,
          nextFloor: fromWp.floor,
        );
      }
    }

    return null;
  }

  NavigationWaypoint? _findConnectedWaypointOnFloor(
    String waypointId,
    int floor,
  ) {
    for (final conn in _waypointConnections) {
      String? candidateId;
      if (conn.fromWaypointId == waypointId) {
        candidateId = conn.toWaypointId;
      } else if (conn.toWaypointId == waypointId) {
        candidateId = conn.fromWaypointId;
      }

      if (candidateId == null) continue;
      final candidate = _waypoints.firstWhereOrNull((w) => w.id == candidateId);
      if (candidate != null && candidate.floor == floor) {
        return candidate;
      }
    }
    return null;
  }


  /// Returns turn-by-turn navigation instruction based on the NEXT WAYPOINT
  /// on the computed path, rather than pointing straight at the destination.
  /// This ensures the user follows the corridor network correctly.
  String getNavigationInstructions() {
    if (!_positionSet) return 'Tap on the map to set your starting position';
    if (_targetRoom == null) return 'Select a destination to navigate';

    if (hasPendingManualFloorConfirmation) {
      return 'Are you reached at floor $pendingManualFloorConfirmationFloor? '
          'Confirm to recalibrate and continue.';
    }

    if (hasPendingFloorTransitionPrompt) {
      final waypoint = pendingFloorTransitionWaypoint;
      final type = waypoint?.waypointType == 'elevator' ? 'elevator' : 'stairs';
      return 'You are at ${waypoint?.name ?? type}. Change to floor '
          '$pendingFloorTransitionTargetFloor and confirm to continue.';
    }

    if (_targetRoom!.floor != _currentFloor) {
      return 'Move towards the nearest stairs/elevator to reach floor '
          '${_targetRoom!.floor}.';
    }

    final distance = distanceToTarget;
    if (distance < 30) {
      return '🎉 You have arrived at ${_targetRoom!.name}!';
    }

    // ── Waypoint-following: find the next waypoint ahead on the path ─────────
    Offset? nextTarget;
    String? nextWaypointName;
    final currentPos = Offset(_currentX, _currentY);

    if (_computedPath.length >= 2) {
      // Walk the path and pick the first point that is still ahead of us
      // (more than a small threshold away), skipping points already passed.
      for (int i = 1; i < _computedPath.length; i++) {
        final pt = _computedPath[i];
        if ((currentPos - pt).distance > 20) {
          nextTarget = pt;
          // Try to label the next waypoint
          if (i < _computedPathWaypointIds.length) {
            final wp = _waypoints.firstWhereOrNull(
                (w) => w.id == _computedPathWaypointIds[i]);
            nextWaypointName = wp?.name;
          }
          break;
        }
      }
    }

    // Fall back to direct-to-destination when no path available
    nextTarget ??= Offset(_targetRoom!.xCoordinate, _targetRoom!.yCoordinate);

    // Bearing from current position to next target
    final dx = nextTarget.dx - _currentX;
    final dy = nextTarget.dy - _currentY;
    final targetBearing = (atan2(dx, -dy) * 180 / pi + 360) % 360;
    final headingForDirections = _isCalibrated ? _stableHeading : _heading;
    final relativeDegrees = (targetBearing - headingForDirections + 360) % 360;

    String direction;
    String emoji;

    if (relativeDegrees < 20 || relativeDegrees > 340) {
      direction = 'Continue straight ahead';
      emoji = '⬆️';
    } else if (relativeDegrees >= 20 && relativeDegrees < 60) {
      direction = 'Turn slightly right';
      emoji = '↗️';
    } else if (relativeDegrees >= 60 && relativeDegrees < 120) {
      direction = 'Turn right';
      emoji = '➡️';
    } else if (relativeDegrees >= 120 && relativeDegrees < 160) {
      direction = 'Turn sharply right';
      emoji = '↘️';
    } else if (relativeDegrees >= 160 && relativeDegrees < 200) {
      direction = 'Turn around';
      emoji = '⬇️';
    } else if (relativeDegrees >= 200 && relativeDegrees < 240) {
      direction = 'Turn sharply left';
      emoji = '↙️';
    } else if (relativeDegrees >= 240 && relativeDegrees < 300) {
      direction = 'Turn left';
      emoji = '⬅️';
    } else {
      direction = 'Turn slightly left';
      emoji = '↖️';
    }

    final distToNext = (currentPos - nextTarget).distance;
    final metersToNext = (distToNext / 10).round();
    final metersTotal  = (distance / 10).round();

    final label = nextWaypointName != null
        ? 'via $nextWaypointName'
        : '${metersTotal}m to ${_targetRoom!.name}';

    return '$emoji $direction\n${metersToNext}m ahead · $label';
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
