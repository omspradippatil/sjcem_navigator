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
  
  /// Update the filter with a new measurement
  double update(double measurement) {
    // Prediction step
    final predictedErrorEstimate = _errorEstimate + _processNoise;
    
    // Update step
    final kalmanGain = predictedErrorEstimate / 
        (predictedErrorEstimate + _measurementNoise);
    
    _estimate = _estimate + kalmanGain * (measurement - _estimate);
    _errorEstimate = (1 - kalmanGain) * predictedErrorEstimate;
    
    return _estimate;
  }
  
  /// Reset the filter with new initial values
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
  
  /// Update both X and Y with new measurements
  (double, double) update(double measurementX, double measurementY) {
    return (
      _xFilter.update(measurementX),
      _yFilter.update(measurementY),
    );
  }
  
  /// Reset the filter with new initial position
  void reset(double initialX, double initialY) {
    _xFilter.reset(initialX);
    _yFilter.reset(initialY);
  }
}

/// Dead Reckoning calculator for indoor navigation
class DeadReckoning {
  double _x;
  double _y;
  double _heading; // in radians
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
  
  /// Update heading from compass/magnetometer (in degrees)
  void updateHeading(double headingDegrees) {
    _heading = headingDegrees * pi / 180;
  }
  
  /// Process a step and update position
  (double, double) step() {
    _x += _stepLength * sin(_heading);
    _y -= _stepLength * cos(_heading); // Negative because Y increases downward on screen
    return (_x, _y);
  }
  
  /// Process multiple steps
  (double, double) steps(int count) {
    for (int i = 0; i < count; i++) {
      step();
    }
    return (_x, _y);
  }
  
  /// Set position directly
  void setPosition(double x, double y) {
    _x = x;
    _y = y;
  }
  
  /// Reset to initial state
  void reset(double x, double y, [double heading = 0.0]) {
    _x = x;
    _y = y;
    _heading = heading;
  }
}

/// Sensor fusion for combining multiple sensor inputs
class SensorFusion {
  final KalmanFilter2D _positionFilter;
  final DeadReckoning _deadReckoning;
  final KalmanFilter _headingFilter;
  
  // Low-pass filter parameters for accelerometer
  double _filteredAccelX = 0.0;
  double _filteredAccelY = 0.0;
  double _filteredAccelZ = 0.0;
  static const double _accelFilterAlpha = 0.1;
  
  // Step detection
  double _lastAccelMagnitude = 0.0;
  bool _isStepPeak = false;
  static const double _stepThreshold = 1.2; // Adjust based on testing
  
  SensorFusion({
    double initialX = 0.0,
    double initialY = 0.0,
    double stepLength = 15.0,
  })  : _positionFilter = KalmanFilter2D(
          initialX: initialX,
          initialY: initialY,
        ),
        _deadReckoning = DeadReckoning(
          initialX: initialX,
          initialY: initialY,
          stepLength: stepLength,
        ),
        _headingFilter = KalmanFilter(
          initialEstimate: 0.0,
          processNoise: 0.1,
          measurementNoise: 0.5,
        );
  
  double get x => _positionFilter.x;
  double get y => _positionFilter.y;
  double get heading => _deadReckoning.heading;
  
  /// Update accelerometer data with low-pass filter
  void updateAccelerometer(double x, double y, double z) {
    _filteredAccelX = _accelFilterAlpha * x + (1 - _accelFilterAlpha) * _filteredAccelX;
    _filteredAccelY = _accelFilterAlpha * y + (1 - _accelFilterAlpha) * _filteredAccelY;
    _filteredAccelZ = _accelFilterAlpha * z + (1 - _accelFilterAlpha) * _filteredAccelZ;
  }
  
  /// Update heading from magnetometer (compass)
  void updateMagnetometer(double headingDegrees) {
    final filteredHeading = _headingFilter.update(headingDegrees);
    _deadReckoning.updateHeading(filteredHeading);
  }
  
  /// Check if a step was detected based on accelerometer
  bool detectStep() {
    final magnitude = sqrt(
      _filteredAccelX * _filteredAccelX +
      _filteredAccelY * _filteredAccelY +
      _filteredAccelZ * _filteredAccelZ,
    );
    
    // Simple peak detection
    if (magnitude > _stepThreshold && !_isStepPeak && magnitude > _lastAccelMagnitude) {
      _isStepPeak = true;
      _lastAccelMagnitude = magnitude;
      return true;
    } else if (magnitude < _stepThreshold) {
      _isStepPeak = false;
    }
    
    _lastAccelMagnitude = magnitude;
    return false;
  }
  
  /// Process a step and return filtered position
  (double, double) processStep() {
    final (drX, drY) = _deadReckoning.step();
    return _positionFilter.update(drX, drY);
  }
  
  /// Set initial position
  void setPosition(double x, double y) {
    _deadReckoning.setPosition(x, y);
    _positionFilter.reset(x, y);
  }
  
  /// Reset the sensor fusion
  void reset(double x, double y, [double heading = 0.0]) {
    _deadReckoning.reset(x, y, heading);
    _positionFilter.reset(x, y);
  }
}
