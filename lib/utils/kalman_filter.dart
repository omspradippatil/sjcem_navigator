import 'dart:math';

import 'constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1-D Kalman Filter
// ─────────────────────────────────────────────────────────────────────────────

/// Standard 1-D Kalman Filter for smoothing scalar estimates.
class KalmanFilter {
  double _estimate;
  double _errorEstimate;
  final double _processNoise;
  final double _measurementNoise;

  KalmanFilter({
    double initialEstimate = 0.0,
    double initialErrorEstimate = 1.0,
    double processNoise = 0.01,
    double measurementNoise = 0.1,
  })  : _estimate = initialEstimate,
        _errorEstimate = initialErrorEstimate,
        _processNoise = processNoise,
        _measurementNoise = measurementNoise;

  double get estimate => _estimate;
  double get errorEstimate => _errorEstimate;

  double update(double measurement) {
    // Predict
    final predictedError = _errorEstimate + _processNoise;
    // Update
    final kalmanGain = predictedError / (predictedError + _measurementNoise);
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _errorEstimate = (1 - kalmanGain) * predictedError;
    return _estimate;
  }

  void reset(double initialEstimate, [double initialErrorEstimate = 1.0]) {
    _estimate = initialEstimate;
    _errorEstimate = initialErrorEstimate;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Angular Kalman Filter (handles 0°/360° wraparound correctly)
// ─────────────────────────────────────────────────────────────────────────────

/// Kalman filter that correctly handles circular angle measurements (degrees).
/// Measurements and estimates are always normalised to [0, 360).
class AngularKalmanFilter {
  double _estimate; // degrees [0,360)
  double _errorEstimate;
  final double _processNoise;
  final double _measurementNoise;

  AngularKalmanFilter({
    double initialEstimate = 0.0,
    double initialErrorEstimate = 100.0, // start uncertain
    double processNoise = 1.0,           // heading can drift fast
    double measurementNoise = 10.0,      // magnetometer is noisy
  })  : _estimate = initialEstimate,
        _errorEstimate = initialErrorEstimate,
        _processNoise = processNoise,
        _measurementNoise = measurementNoise;

  double get estimate => _estimate;

  /// Update with a new angle measurement (degrees).
  double update(double measurement) {
    // Predict
    final predictedError = _errorEstimate + _processNoise;
    // Compute shortest angular difference measurement → estimate
    double innovation = measurement - _estimate;
    // Wrap to [-180, 180]
    innovation = _wrapAngle(innovation);
    // Kalman gain
    final kalmanGain = predictedError / (predictedError + _measurementNoise);
    // Update estimate
    _estimate = _normalise(_estimate + kalmanGain * innovation);
    _errorEstimate = (1 - kalmanGain) * predictedError;
    return _estimate;
  }

  void reset(double degrees) {
    _estimate = _normalise(degrees);
    _errorEstimate = 100.0;
  }

  static double _wrapAngle(double d) {
    d = d % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  static double _normalise(double d) => (d % 360 + 360) % 360;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2-D Kalman Filter (position)
// ─────────────────────────────────────────────────────────────────────────────

class KalmanFilter2D {
  final KalmanFilter _xFilter;
  final KalmanFilter _yFilter;

  KalmanFilter2D({
    double initialX = 0.0,
    double initialY = 0.0,
    double processNoise = 0.01,
    double measurementNoise = 0.1,
  })  : _xFilter = KalmanFilter(
          initialEstimate: initialX,
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        ),
        _yFilter = KalmanFilter(
          initialEstimate: initialY,
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        );

  double get x => _xFilter.estimate;
  double get y => _yFilter.estimate;

  (double, double) update(double measurementX, double measurementY) {
    return (
      _xFilter.update(measurementX),
      _yFilter.update(measurementY),
    );
  }

  void reset(double initialX, double initialY) {
    _xFilter.reset(initialX);
    _yFilter.reset(initialY);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dead Reckoning
// ─────────────────────────────────────────────────────────────────────────────

/// Dead Reckoning calculator for indoor navigation.
class DeadReckoning {
  double _x;
  double _y;
  double _heading; // radians
  final double _stepLength;

  DeadReckoning({
    double initialX = 0.0,
    double initialY = 0.0,
    double initialHeading = 0.0,
    double stepLength = 15.0,
  })  : _x = initialX,
        _y = initialY,
        _heading = initialHeading,
        _stepLength = stepLength;

  double get x => _x;
  double get y => _y;
  double get heading => _heading;
  double get headingDegrees => _heading * 180 / pi;

  void updateHeading(double headingDegrees) {
    _heading = headingDegrees * pi / 180;
  }

  (double, double) step() {
    _x += _stepLength * sin(_heading);
    _y -= _stepLength * cos(_heading);
    return (_x, _y);
  }

  (double, double) steps(int count) {
    for (int i = 0; i < count; i++) {
      step();
    }
    return (_x, _y);
  }

  void setPosition(double x, double y) {
    _x = x;
    _y = y;
  }

  void reset(double x, double y, [double heading = 0.0]) {
    _x = x;
    _y = y;
    _heading = heading;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extended Kalman Filter (2D + heading + gyro bias)
// ─────────────────────────────────────────────────────────────────────────────

/// 5D Extended Kalman Filter for indoor navigation with AUTOMATIC FLOOR DETECTION.
/// State: [x, y, z, theta, omega_bias]
///   - x, y: position (pixels on floor map)
///   - z: accumulated vertical height (meters) - used for floor change detection
///   - theta: heading (degrees)
///   - omega_bias: gyroscope z-axis bias (rad/s) - estimates drift
///
/// Motion Model (nonlinear):
///   x_k = x_{k-1} + (v * cos(theta) * dt)
///   y_k = y_{k-1} + (v * sin(theta) * dt)
///   z_k = z_{k-1} + a_z_filtered * dt  (integrate vertical acceleration)
///   theta_k = theta_{k-1} + ((omega - omega_bias) * dt * 180/pi)
///   omega_bias_k = omega_bias_{k-1}  (slowly drifting bias)
///
/// Measurement Model:
///   z_x = x (dead reckoning gives us position)
///   z_y = y
///   z_z = z (vertical accelerometer gives height)
///   z_theta = theta (magnetometer gives heading)
class ExtendedKalmanFilter2D {
  // State vector: [x, y, z (meters), theta (deg), omega_bias (rad/s)]
  late List<double> _x;  // state estimate (5D)
  late List<List<double>> p;  // state covariance (5x5)

  // Process noise covariance Q (5x5)
  final double _qX;
  final double _qY;
  final double _qZ;  // NEW: vertical position drift
  final double _qTheta;
  final double _qBias;

  // Measurement noise covariance R (4x4) for [x, y, z, theta]
  final double _rX;
  final double _rY;
  final double _rZ;  // NEW: vertical measurement noise
  final double _rTheta;

  // Time tracking for gyro integration
  DateTime _lastUpdateTime = DateTime.now();
  
  // NEW: Floor detection state
  int _estimatedFloor = 0;
  double _accumulatedZ = 0.0;
  int _floorChangeCandidate = 0;
  int _floorChangeConfirmCount = 0;

  ExtendedKalmanFilter2D({
    double initialX = 0.0,
    double initialY = 0.0,
    double initialZ = 0.0,
    double initialTheta = 0.0,
    double qX = 1.0,
    double qY = 1.0,
    double qZ = 0.05,
    double qTheta = 0.5,
    double qBias = 0.01,
    double rX = 0.2,
    double rY = 0.2,
    double rZ = 0.1,
    double rTheta = 5.0,
  })  : _qX = qX,
        _qY = qY,
        _qZ = qZ,
        _qTheta = qTheta,
        _qBias = qBias,
        _rX = rX,
        _rY = rY,
        _rZ = rZ,
        _rTheta = rTheta {
    _initializeState(initialX, initialY, initialZ, initialTheta);
  }

  void _initializeState(double x, double y, double z, double theta) {
    // 5D state: [x, y, z, theta, bias]
    _x = [x, y, z, (theta % 360 + 360) % 360, 0.0];
    _accumulatedZ = z;
    // Initialize covariance to high uncertainty
    p = [
      [10.0, 0.0, 0.0, 0.0, 0.0],
      [0.0, 10.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 10.0, 0.0, 0.0],
      [0.0, 0.0, 0.0, 100.0, 0.0],
      [0.0, 0.0, 0.0, 0.0, 0.01],
    ];
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  double get x => _x[0];
  double get y => _x[1];
  double get z => _x[2];  // height in meters
  double get theta => _x[3];  // heading in degrees
  double get gyroBias => _x[4];  // gyro bias in rad/s
  int get estimatedFloor => _estimatedFloor;  // NEW: auto-detected floor

  /// Perform prediction step with gyroscope measurement and vertical acceleration
  /// omega: angular velocity in rad/s
  /// velocity: horizontal movement speed in pixels/step
  /// accelZ: vertical acceleration in m/s² (positive = up, negative = down)
  void predictWithGyro(double omega, double velocity, {double accelZ = 0.0}) {
    final now = DateTime.now();
    final dt = now.difference(_lastUpdateTime).inMilliseconds / 1000.0;
    _lastUpdateTime = now;

    if (dt <= 0 || dt > 0.5) return; // Ignore invalid time deltas

    // Extract state
    final x = _x[0];
    final y = _x[1];
    final z = _x[2];  // NEW: current height
    final theta = _x[3] * pi / 180.0;  // convert to radians for computation
    final bias = _x[4];

    // NEW: Integrate vertical acceleration into height estimate
    // z_new = z + a_z * dt^2 / 2  (constant acceleration model)
    final zNew = z + accelZ * dt * dt / 2.0;
    _accumulatedZ += accelZ * dt * dt / 2.0;

    // Prediction: constant velocity motion model with heading
    final xNew = x + velocity * cos(theta) * dt;
    final yNew = y + velocity * sin(theta) * dt;
    final thetaNew = (theta + (-omega - bias) * dt) * 180.0 / pi;
    final biasNew = bias;  // bias changes very slowly

    // Linearized Jacobian F (state transition matrix) - now 5x5
    final F = _computeJacobianF(theta, velocity, dt);

    // Predicted covariance: P = F*P*F^T + Q
    final Q = [
      [_qX, 0.0, 0.0, 0.0, 0.0],
      [0.0, _qY, 0.0, 0.0, 0.0],
      [0.0, 0.0, _qZ, 0.0, 0.0],
      [0.0, 0.0, 0.0, _qTheta, 0.0],
      [0.0, 0.0, 0.0, 0.0, _qBias],
    ];

    p = _matrixAdd(
      _matrixMult(_matrixMult(F, p), _matrixTranspose(F)),
      Q,
    );

    // Update state estimate
    _x[0] = xNew;
    _x[1] = yNew;
    _x[2] = zNew;  // NEW: update height
    _x[3] = (_normalizeAngleDeg(thetaNew) % 360 + 360) % 360;
    _x[4] = biasNew;
  }

  /// Measurement update with dead-reckoned position, magnetometer heading, and height
  /// NEW: Supports 4D measurements [x, y, z, theta] for height-aware orientation
  void updateMeasurement(
    double measX,
    double measY,
    double measTheta, {
    double measZ = 0.0,
  }) {
    // Measurement matrix H - maps 5D state to 4D measurements [x, y, z, theta]
    // NEW: Now 4x5 (4 measurements, 5 states)
    final H = [
      [1.0, 0.0, 0.0, 0.0, 0.0],  // x measurement
      [0.0, 1.0, 0.0, 0.0, 0.0],  // y measurement
      [0.0, 0.0, 1.0, 0.0, 0.0],  // z measurement (NEW)
      [0.0, 0.0, 0.0, 1.0, 0.0],  // theta measurement
    ];

    // Measurement covariance R - now 4x4
    final R = [
      [_rX, 0.0, 0.0, 0.0],
      [0.0, _rY, 0.0, 0.0],
      [0.0, 0.0, _rZ, 0.0],
      [0.0, 0.0, 0.0, _rTheta],
    ];

    // Innovation (measurement residual) - now 4D
    final innovation = [
      measX - _x[0],
      measY - _x[1],
      measZ - _x[2],  // NEW: z residual
      _normalizeAngleDeg(measTheta - _x[3]),  // wrap heading to [-180, 180]
    ];

    // Innovation covariance: S = H*P*H^T + R (now 4x4)
    final S = _matrixAdd(
      _matrixMult(_matrixMult(H, p), _matrixTranspose(H)),
      R,
    );

    // Kalman gain: K = P*H^T*S^{-1}
    final K = _matrixMult(
      _matrixMult(p, _matrixTranspose(H)),
      _matrixInverse4x4(S),
    );

    // State update: x = x + K*innovation (5D state)
    final stateUpdate = _matrixMultVector(K, innovation);
    _x[0] += stateUpdate[0];
    _x[1] += stateUpdate[1];
    _x[2] += stateUpdate[2];  // NEW: update height
    _x[3] = (_normalizeAngleDeg(_x[3] + stateUpdate[3]) % 360 + 360) % 360;
    _x[4] += stateUpdate[4];

    // Covariance update: P = (I - K*H)*P
    final i5 = [
      [1.0, 0.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0, 0.0],
      [0.0, 0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 0.0, 1.0],
    ];
    final kh = _matrixMult(K, H);
    final ikh = _matrixSubtract(i5, kh);
    p = _matrixMult(ikh, p);

    // NEW: Check for floor transition
    checkFloorTransition(measZ);
  }

  void reset(double x, double y, [double theta = 0.0, double z = 0.0]) {
    _initializeState(x, y, z, theta);
    _lastUpdateTime = DateTime.now();
  }

  // ── Matrix utilities ───────────────────────────────────────────────────────

  List<List<double>> _computeJacobianF(
    double theta,
    double velocity,
    double dt,
  ) {
    // Jacobian of motion model with respect to state [x, y, z, theta, bias]
    // NEW: Now 5x5 (added z row)
    return [
      [1.0, 0.0, 0.0, -velocity * sin(theta) * dt, 0.0],  // dx/d(·)
      [0.0, 1.0, 0.0, velocity * cos(theta) * dt, 0.0],   // dy/d(·)
      [0.0, 0.0, 1.0, 0.0, 0.0],                          // dz/d(·) - z is self-integrated
      [0.0, 0.0, 0.0, 1.0, -dt * 180.0 / pi],             // dtheta/d(·)
      [0.0, 0.0, 0.0, 0.0, 1.0],                          // dbias/d(·) - bias constant
    ];
  }

  List<List<double>> _matrixMult(
    List<List<double>> A,
    List<List<double>> B,
  ) {
    final n = A.length;
    final m = B[0].length;
    final result = List.generate(n, (_) => List<double>.filled(m, 0.0));
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < m; j++) {
        for (int k = 0; k < B.length; k++) {
          result[i][j] += A[i][k] * B[k][j];
        }
      }
    }
    return result;
  }

  List<double> _matrixMultVector(
    List<List<double>> A,
    List<double> v,
  ) {
    return A.map((row) => row.asMap().entries.fold<double>(0, (sum, e) => sum + e.value * v[e.key])).toList();
  }

  List<List<double>> _matrixTranspose(List<List<double>> A) {
    final rows = A.length;
    final cols = A[0].length;
    return List.generate(
      cols,
      (j) => List.generate(rows, (i) => A[i][j]),
    );
  }

  List<List<double>> _matrixAdd(
    List<List<double>> A,
    List<List<double>> B,
  ) {
    return List.generate(
      A.length,
      (i) => List.generate(A[0].length, (j) => A[i][j] + B[i][j]),
    );
  }

  List<List<double>> _matrixSubtract(
    List<List<double>> A,
    List<List<double>> B,
  ) {
    return List.generate(
      A.length,
      (i) => List.generate(A[0].length, (j) => A[i][j] - B[i][j]),
    );
  }

  /// Invert 4x4 matrix (for S = H*P*H^T + R in 5D system)
  /// NEW: Used for measurement update with z-dimension
  List<List<double>> _matrixInverse4x4(List<List<double>> M) {
    // Use Gaussian elimination with partial pivoting
    const int n = 4;
    final A = [
      [...M[0]],
      [...M[1]],
      [...M[2]],
      [...M[3]],
    ];
    final B = [
      [1.0, 0.0, 0.0, 0.0],
      [0.0, 1.0, 0.0, 0.0],
      [0.0, 0.0, 1.0, 0.0],
      [0.0, 0.0, 0.0, 1.0],
    ];

    for (int i = 0; i < n; i++) {
      // Find pivot
      int pivot = i;
      for (int j = i + 1; j < n; j++) {
        if (A[j][i].abs() > A[pivot][i].abs()) {
          pivot = j;
        }
      }

      if (A[pivot][i].abs() < 1e-9) continue; // Singular

      // Swap rows
      final tempA = A[i];
      A[i] = A[pivot];
      A[pivot] = tempA;
      final tempB = B[i];
      B[i] = B[pivot];
      B[pivot] = tempB;

      // Eliminate column
      final scale = A[i][i];
      for (int j = 0; j < n; j++) {
        A[i][j] /= scale;
        B[i][j] /= scale;
      }

      for (int j = 0; j < n; j++) {
        if (j == i) continue;
        final factor = A[j][i];
        for (int k = 0; k < n; k++) {
          A[j][k] -= factor * A[i][k];
          B[j][k] -= factor * B[i][k];
        }
      }
    }

    return B;
  }

  /// Check for floor transitions based on accumulated height
  /// NEW: Automatic floor detection when threshold crossed
  void checkFloorTransition(double measZ) {
    // Track vertical displacement to detect floor changes
    final heightChange = (measZ - _accumulatedZ).abs();
    
    if (heightChange > AppConstants.verticalThresholdMeters) {
      // Accumulate confidence for this floor transition
      _floorChangeConfirmCount++;
      
      // Determine candidate floor based on accumulated height
      _floorChangeCandidate = (_accumulatedZ / AppConstants.floorHeightMeters).round();
      
      // If confidence threshold met, confirm the floor change
      if (_floorChangeConfirmCount > 5) {
        _estimatedFloor = _floorChangeCandidate;
        _floorChangeConfirmCount = 0;
      }
    } else {
      // Reset confidence counter if no significant height change
      _floorChangeConfirmCount = 0;
    }
    
    // Update accumulated z-height
    _accumulatedZ = measZ;
  }

  double _normalizeAngleDeg(double deg) {
    deg = deg % 360;
    if (deg > 180) deg -= 360;
    if (deg < -180) deg += 360;
    return deg;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sensor Fusion  (Accel + Magnetometer + Gyroscope → heading + position)
// ─────────────────────────────────────────────────────────────────────────────

/// Full sensor fusion pipeline:
///   • Accelerometer  → step detection (adaptive peak/valley)
///   • Magnetometer   → absolute heading reference (Kalman-filtered)
///   • Gyroscope      → fast heading tracking (complementary filter)
///   • Angular Kalman → fused heading used for dead reckoning
///   • Position Kalman → smooth X/Y output
///   • (NEW) Extended Kalman Filter → unified 2D state with gyro bias estimation
class SensorFusion {
  final KalmanFilter2D _positionFilter;
  final DeadReckoning _deadReckoning;
  final ExtendedKalmanFilter2D _ekf2d;  // NEW: 2D EKF for joint state estimation

  // ── Heading pipeline ───────────────────────────────────────────────────────
  /// Kalman filter on the raw magnetometer reading.
  final AngularKalmanFilter _magKalman;

  /// Gyro-integrated heading (fast, drifts over time).
  double _gyroHeading = 0.0;
  bool _gyroInitialised = false;
  DateTime _lastGyroTime = DateTime.now();

  /// Complementary filter alpha: weight for gyro vs. mag (0=all mag, 1=all gyro).
  static const double _compAlpha = 0.85;
  
  /// Last gyro reading (rad/s) for EKF prediction
  double _lastGyroZ = 0.0;

  /// Final fused heading (degrees, [0,360)).
  double _fusedHeading = 0.0;

  // ── Accelerometer filtering ────────────────────────────────────────────────
  double _filteredAccelX = 0.0;
  double _filteredAccelY = 0.0;
  double _filteredAccelZ = 0.0;
  static const double _accelFilterAlpha = 0.25; // slightly more aggressive

  // ── Step detection ─────────────────────────────────────────────────────────
  final List<double> _accelHistory = [];
  static const int _historySize = 50;
  double _dynamicThreshold = 1.2;
  DateTime _lastStepTime = DateTime.now();
  static const int _minStepIntervalMs = 280; // ≤3.5 steps/sec

  bool _lookingForPeak = true;
  double _lastPeakValue = 0;
  double _lastValleyValue = 0;
  
  // ── EKF blend mode ─────────────────────────────────────────────────────────
  /// Enable/disable EKF fusion; currently runs in parallel with existing filters
  bool _useEKF = true;
  /// Step length used for EKF velocity estimate
  final double _stepLength;

  // ── Debug ──────────────────────────────────────────────────────────────────
  double _lastMagnitude = 0;
  double _lastDeviation = 0;
  bool _lastStepDetected = false;

  SensorFusion({
    double initialX = 0.0,
    double initialY = 0.0,
    double stepLength = 8.97,
  })  : _positionFilter = KalmanFilter2D(
          initialX: initialX,
          initialY: initialY,
          processNoise: 0.05,
          measurementNoise: 0.1,
        ),
        _deadReckoning = DeadReckoning(
          initialX: initialX,
          initialY: initialY,
          stepLength: stepLength,
        ),
        _magKalman = AngularKalmanFilter(
          processNoise: 0.8,
          measurementNoise: 8.0,
        ),
        _ekf2d = ExtendedKalmanFilter2D(
          initialX: initialX,
          initialY: initialY,
        ),
        _stepLength = stepLength;

  // ── Public getters ─────────────────────────────────────────────────────────
  double get x => _positionFilter.x;
  double get y => _positionFilter.y;
  double get fusedHeading => _fusedHeading;
  double get lastMagnitude => _lastMagnitude;
  double get lastDeviation => _lastDeviation;
  double get dynamicThreshold => _dynamicThreshold;
  bool get lastStepDetected => _lastStepDetected;

  // ── Sensor updates ─────────────────────────────────────────────────────────

  /// Feed raw accelerometer values (m/s²).
  void updateAccelerometer(double x, double y, double z) {
    _filteredAccelX = _accelFilterAlpha * x + (1 - _accelFilterAlpha) * _filteredAccelX;
    _filteredAccelY = _accelFilterAlpha * y + (1 - _accelFilterAlpha) * _filteredAccelY;
    _filteredAccelZ = _accelFilterAlpha * z + (1 - _accelFilterAlpha) * _filteredAccelZ;
  }

  /// Feed raw magnetometer heading (degrees, [0,360)).
  /// Runs the full mag → Kalman → complementary fusion pipeline.
  double updateMagnetometer(double rawHeadingDegrees) {
    // 1. Kalman-filter the raw magnetometer reading
    final magFiltered = _magKalman.update(rawHeadingDegrees);

    // 2. Complementary blend: gyro (fast, drift-prone) + mag (slow, stable)
    if (!_gyroInitialised) {
      // Bootstrap gyro to mag on first reading
      _gyroHeading = magFiltered;
      _gyroInitialised = true;
      _fusedHeading = magFiltered;
    } else {
      // Blend: fused = alpha*gyro + (1-alpha)*mag  (handle wrap-around)
      double diff = magFiltered - _gyroHeading;
      if (diff > 180) diff -= 360;
      if (diff < -180) diff += 360;
      _fusedHeading = (_gyroHeading + (1 - _compAlpha) * diff + 360) % 360;
    }

    // 3. Feed fused heading into dead reckoning
    _deadReckoning.updateHeading(_fusedHeading);

    return _fusedHeading;
  }

  /// Feed raw gyroscope Z-axis rotation (rad/s).
  void updateGyroscope(double rotZ) {
    final now = DateTime.now();
    final dt = now.difference(_lastGyroTime).inMilliseconds / 1000.0;
    _lastGyroTime = now;

    if (!_gyroInitialised || dt <= 0 || dt > 0.5) return;

    // Store for EKF prediction
    _lastGyroZ = rotZ;

    // Integrate gyro (yaw): subtract because positive Z rotates counter-clockwise on Android
    final delta = rotZ * 180 / pi * dt;
    _gyroHeading = (_gyroHeading - delta + 360) % 360;
    
    // EKF prediction step: use gyro to predict heading and bias evolution
    if (_useEKF) {
      _ekf2d.predictWithGyro(rotZ, 0.0, accelZ: _filteredAccelZ);  // velocity will be updated on step
    }
  }

  // ── Step detection ─────────────────────────────────────────────────────────

  bool detectStep() {
    _lastStepDetected = false;

    final magnitude = sqrt(
      _filteredAccelX * _filteredAccelX +
      _filteredAccelY * _filteredAccelY +
      _filteredAccelZ * _filteredAccelZ,
    );
    _lastMagnitude = magnitude;

    _accelHistory.add(magnitude);
    if (_accelHistory.length > _historySize) _accelHistory.removeAt(0);
    if (_accelHistory.length < 10) return false;

    final baseline = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
    final deviation = magnitude - baseline;
    _lastDeviation = deviation;

    _updateAdaptiveThreshold();

    final now = DateTime.now();
    if (now.difference(_lastStepTime).inMilliseconds < _minStepIntervalMs) {
      return false;
    }

    // Peak-valley walking pattern
    if (_lookingForPeak) {
      if (deviation > _dynamicThreshold && deviation > _lastPeakValue) {
        _lastPeakValue = deviation;
      } else if (_lastPeakValue > _dynamicThreshold && deviation < _lastPeakValue * 0.7) {
        _lookingForPeak = false;
        _lastValleyValue = deviation;
      }
    } else {
      if (deviation < _lastValleyValue) {
        _lastValleyValue = deviation;
      } else if (_lastValleyValue < 0 && deviation > _lastValleyValue + 0.3) {
        final peakToValley = _lastPeakValue - _lastValleyValue;
        if (peakToValley > _dynamicThreshold * 0.8) {
          _lastStepTime = now;
          _lookingForPeak = true;
          _lastPeakValue = 0;
          _lastValleyValue = 0;
          _lastStepDetected = true;
          return true;
        }
        _lookingForPeak = true;
        _lastPeakValue = 0;
        _lastValleyValue = 0;
      }
    }

    return false;
  }

  void _updateAdaptiveThreshold() {
    if (_accelHistory.length < 20) return;
    final mean = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
    double variance = 0;
    for (final v in _accelHistory) {
      variance += (v - mean) * (v - mean);
    }
    variance /= _accelHistory.length;
    _dynamicThreshold = (sqrt(variance) * 1.5).clamp(0.4, 2.0);
  }

  // ── Position step ──────────────────────────────────────────────────────────

  (double, double) processStep() {
    final (drX, drY) = _deadReckoning.step();
    final (filtered) = _positionFilter.update(drX, drY);
    
    // EKF measurement update: feed dead reckoning position and fused heading
    if (_useEKF) {
      // Estimate velocity as step_length per step (roughly 0.28 m/s = 8.97 px / 280ms)
      final velocity = _stepLength / 0.28;
      _ekf2d.predictWithGyro(_lastGyroZ, velocity, accelZ: _filteredAccelZ);
      _ekf2d.updateMeasurement(drX, drY, _fusedHeading, measZ: _filteredAccelZ);
    }
    
    return filtered;
  }

  void setPosition(double x, double y) {
    _deadReckoning.setPosition(x, y);
    _positionFilter.reset(x, y);
    if (_useEKF) {
      _ekf2d.reset(x, y, _fusedHeading);
    }
  }

  /// Override fused heading directly (e.g. after manual calibration).
  void overrideHeading(double degrees) {
    _fusedHeading = (degrees % 360 + 360) % 360;
    _gyroHeading = _fusedHeading;
    _magKalman.reset(_fusedHeading);
    _deadReckoning.updateHeading(_fusedHeading);
    if (_useEKF) {
      _ekf2d.reset(_ekf2d.x, _ekf2d.y, _fusedHeading);
    }
  }

  void reset(double x, double y, [double headingDegrees = 0.0]) {
    _deadReckoning.reset(x, y);
    _positionFilter.reset(x, y);
    if (_useEKF) {
      _ekf2d.reset(x, y, headingDegrees);
    }
    _accelHistory.clear();
    _lastPeakValue = 0;
    _lastValleyValue = 0;
    _lookingForPeak = true;
    _gyroInitialised = false;
    _fusedHeading = headingDegrees;
    _gyroHeading = headingDegrees;
  }
  
  /// Get EKF state for debugging/validation (optional)
  /// Returns [ekf_x, ekf_y, ekf_theta, ekf_gyro_bias]
  List<double> getEKFState() => [_ekf2d.x, _ekf2d.y, _ekf2d.theta, _ekf2d.gyroBias];
  
  /// Enable/disable EKF fusion for testing
  void setUseEKF(bool enable) {
    _useEKF = enable;
  }
}
