import 'dart:math';

/// Kalman Filter for smoothing position estimates
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
    final predictedErrorEstimate = _errorEstimate + _processNoise;
    final kalmanGain =
        predictedErrorEstimate / (predictedErrorEstimate + _measurementNoise);
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _errorEstimate = (1 - kalmanGain) * predictedErrorEstimate;
    return _estimate;
  }

  void reset(double initialEstimate, [double initialErrorEstimate = 1.0]) {
    _estimate = initialEstimate;
    _errorEstimate = initialErrorEstimate;
  }
}

/// 2D Kalman Filter for X,Y position
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

/// Dead Reckoning calculator for indoor navigation
class DeadReckoning {
  double _x;
  double _y;
  double _heading;
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

/// Modern Sensor Fusion - Optimized for real device movement detection
class SensorFusion {
  final KalmanFilter2D _positionFilter;
  final DeadReckoning _deadReckoning;
  final KalmanFilter _headingFilter;

  // Accelerometer filtering
  double _filteredAccelX = 0.0;
  double _filteredAccelY = 0.0;
  double _filteredAccelZ = 0.0;
  static const double _accelFilterAlpha = 0.3;

  // Modern step detection with adaptive threshold
  final List<double> _accelHistory = [];
  static const int _historySize = 50;
  double _dynamicThreshold = 1.2;
  DateTime _lastStepTime = DateTime.now();
  static const int _minStepIntervalMs = 250; // Max 4 steps per second
  
  // Peak detection state
  bool _lookingForPeak = true;
  double _lastPeakValue = 0;
  double _lastValleyValue = 0;
  
  // Debug info
  double _lastMagnitude = 0;
  double _lastDeviation = 0;
  bool _lastStepDetected = false;

  SensorFusion({
    double initialX = 0.0,
    double initialY = 0.0,
    double stepLength = 20.0, // Increased step length for visibility
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
        _headingFilter = KalmanFilter(
          initialEstimate: 0.0,
          processNoise: 0.15,
          measurementNoise: 0.3,
        );

  double get x => _positionFilter.x;
  double get y => _positionFilter.y;
  double get heading => _deadReckoning.heading;
  
  // Debug getters
  double get lastMagnitude => _lastMagnitude;
  double get lastDeviation => _lastDeviation;
  double get dynamicThreshold => _dynamicThreshold;
  bool get lastStepDetected => _lastStepDetected;

  void updateAccelerometer(double x, double y, double z) {
    _filteredAccelX = _accelFilterAlpha * x + (1 - _accelFilterAlpha) * _filteredAccelX;
    _filteredAccelY = _accelFilterAlpha * y + (1 - _accelFilterAlpha) * _filteredAccelY;
    _filteredAccelZ = _accelFilterAlpha * z + (1 - _accelFilterAlpha) * _filteredAccelZ;
  }

  void updateMagnetometer(double headingDegrees) {
    final filteredHeading = _headingFilter.update(headingDegrees);
    _deadReckoning.updateHeading(filteredHeading);
  }

  /// Modern step detection using adaptive peak detection
  bool detectStep() {
    _lastStepDetected = false;
    
    // Calculate acceleration magnitude
    final magnitude = sqrt(
      _filteredAccelX * _filteredAccelX +
      _filteredAccelY * _filteredAccelY +
      _filteredAccelZ * _filteredAccelZ,
    );
    _lastMagnitude = magnitude;

    // Add to history
    _accelHistory.add(magnitude);
    if (_accelHistory.length > _historySize) {
      _accelHistory.removeAt(0);
    }

    // Need enough history
    if (_accelHistory.length < 10) return false;

    // Calculate baseline (gravity ~9.8)
    final baseline = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
    
    // Deviation from baseline
    final deviation = magnitude - baseline;
    _lastDeviation = deviation;

    // Update adaptive threshold based on recent activity
    _updateAdaptiveThreshold();

    // Check timing
    final now = DateTime.now();
    final timeSinceLastStep = now.difference(_lastStepTime).inMilliseconds;
    if (timeSinceLastStep < _minStepIntervalMs) return false;

    // Peak-valley detection for walking pattern
    if (_lookingForPeak) {
      // Looking for peak (high point)
      if (deviation > _dynamicThreshold && deviation > _lastPeakValue) {
        _lastPeakValue = deviation;
      } else if (_lastPeakValue > _dynamicThreshold && deviation < _lastPeakValue * 0.7) {
        // Found peak, now look for valley
        _lookingForPeak = false;
        _lastValleyValue = deviation;
      }
    } else {
      // Looking for valley (low point)
      if (deviation < _lastValleyValue) {
        _lastValleyValue = deviation;
      } else if (_lastValleyValue < 0 && deviation > _lastValleyValue + 0.3) {
        // Found valley, step complete!
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
    
    // Calculate variance
    final mean = _accelHistory.reduce((a, b) => a + b) / _accelHistory.length;
    double variance = 0;
    for (final v in _accelHistory) {
      variance += (v - mean) * (v - mean);
    }
    variance /= _accelHistory.length;
    final stdDev = sqrt(variance);
    
    // Adaptive threshold: lower bound 0.4, upper bound 2.0
    _dynamicThreshold = (stdDev * 1.5).clamp(0.4, 2.0);
  }

  (double, double) processStep() {
    final (drX, drY) = _deadReckoning.step();
    return _positionFilter.update(drX, drY);
  }

  void setPosition(double x, double y) {
    _deadReckoning.setPosition(x, y);
    _positionFilter.reset(x, y);
  }

  void reset(double x, double y, [double heading = 0.0]) {
    _deadReckoning.reset(x, y, heading);
    _positionFilter.reset(x, y);
    _accelHistory.clear();
    _lastPeakValue = 0;
    _lastValleyValue = 0;
    _lookingForPeak = true;
  }
}
