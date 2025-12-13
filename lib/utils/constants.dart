class AppConstants {
  static const String supabaseUrl = 'https://wlystotvdgzkyhiqtnsh.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndseXN0b3R2ZGd6a3loaXF0bnNoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU1MzgxMDMsImV4cCI6MjA4MTExNDEwM30.TET-316B8ZNG8btslfVKmh0xffFjHyFAftrCV9acIJ8';
  
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
