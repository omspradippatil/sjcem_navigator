class AppConstants {
  // PostgreSQL Database Connection
  static const String dbHost = '13.204.77.158';
  static const int dbPort = 5432;
  static const String dbName = 'flutterdb';
  static const String dbUser = 'flutteruser';
  static const String dbPassword = 'OM@om123';

  // Map dimensions (adjust based on your floor map image)
  static const double mapWidth = 700.0;
  static const double mapHeight = 650.0;

  // Step length in pixels (calibrated for the map scale)
  static const double stepLengthPixels = 15.0;

  // Kalman filter parameters
  static const double processNoise = 0.01;
  static const double measurementNoise = 0.1;

  // Days of week
  static const List<String> daysOfWeek = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  // User types
  static const String userTypeStudent = 'student';
  static const String userTypeTeacher = 'teacher';
  static const String userTypeGuest = 'guest';
}
