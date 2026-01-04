import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/postgres_service.dart';

class TeacherLocationProvider extends ChangeNotifier {
  Map<String, Teacher> _teacherLocations =
      {}; // teacherId -> Teacher with location
  Map<String, Room> _roomsCache = {}; // roomId -> Room
  List<Map<String, dynamic>> _teachersWithSchedule = [];
  bool _isLoading = false;
  String? _error;
  Timer? _autoUpdateTimer;
  Timer? _pollingTimer;
  Timer? _locationSyncTimer;

  Map<String, Teacher> get teacherLocations => _teacherLocations;
  List<Map<String, dynamic>> get teachersWithSchedule => _teachersWithSchedule;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTeacherLocations() async {
    _isLoading = true;
    _error = null;

    try {
      // Auto-update all teacher locations based on timetable first
      await PostgresService.autoUpdateTeacherLocations();

      // Load rooms for cache
      final rooms = await PostgresService.getAllRooms();
      _roomsCache = {for (var room in rooms) room.id: room};

      // Load teachers with location
      final teachers = await PostgresService.getTeachersWithLocation();
      _teacherLocations = {for (var teacher in teachers) teacher.id: teacher};

      // Load all teachers with their schedule info
      _teachersWithSchedule =
          await PostgresService.getAllTeachersWithSchedule();

      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load teacher locations: ${e.toString()}';
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  void subscribeToLocationUpdates() {
    // Using periodic polling instead of subscriptions with PostgreSQL
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadTeacherLocations(),
    );

    // Also start location sync timer (every minute) to keep locations updated
    _startLocationSyncTimer();
  }

  void _startLocationSyncTimer() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) async {
        // This calls the database function to auto-update all teachers
        await PostgresService.autoUpdateTeacherLocations();
        await loadTeacherLocations();
      },
    );
  }

  void unsubscribeFromLocationUpdates() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
    _locationSyncTimer?.cancel();
    _locationSyncTimer = null;
  }

  Room? getRoomForTeacher(String teacherId) {
    final teacher = _teacherLocations[teacherId];
    if (teacher?.currentRoomId != null) {
      return _roomsCache[teacher!.currentRoomId];
    }
    return null;
  }

  String? getRoomNameForTeacher(String teacherId) {
    return getRoomForTeacher(teacherId)?.name;
  }

  /// Get teacher's current class info
  Map<String, dynamic>? getTeacherScheduleInfo(String teacherId) {
    try {
      return _teachersWithSchedule.firstWhere(
        (t) => t['id'] == teacherId,
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateMyLocation(String teacherId, String? roomId) async {
    try {
      if (roomId == null) {
        _teacherLocations.remove(teacherId);
        notifyListeners();
        return true;
      }

      final success = await PostgresService.updateTeacherLocation(
        teacherId: teacherId,
        roomId: roomId,
      );

      if (success) {
        // Reload teacher data
        final teacher = await PostgresService.getTeacherById(teacherId);
        if (teacher != null) {
          _teacherLocations[teacherId] = teacher;
        }
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to update location: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Start auto-updating teacher location based on timetable
  void startAutoLocationUpdate(String teacherId) {
    // Initial update
    _autoUpdateFromTimetable(teacherId);

    // Set up periodic updates (every minute to match class schedules)
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _autoUpdateFromTimetable(teacherId),
    );
  }

  Future<void> _autoUpdateFromTimetable(String teacherId) async {
    try {
      // Use database function to get scheduled room
      final scheduledRoomId =
          await PostgresService.getTeacherScheduledRoom(teacherId);

      if (scheduledRoomId != null) {
        final currentTeacher = _teacherLocations[teacherId];
        if (currentTeacher?.currentRoomId != scheduledRoomId) {
          await updateMyLocation(teacherId, scheduledRoomId);
        }
      } else {
        // No class right now, clear location
        final currentTeacher = _teacherLocations[teacherId];
        if (currentTeacher?.currentRoomId != null) {
          await updateMyLocation(teacherId, null);
        }
      }
    } catch (e) {
      debugPrint('Auto-location update error: $e');
    }
  }

  /// Get teacher's current and next class info
  Future<Map<String, dynamic>?> getTeacherClassStatus(String teacherId) async {
    return await PostgresService.getTeacherScheduleStatus(teacherId);
  }

  List<Room> getAvailableRooms() {
    return _roomsCache.values.toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromLocationUpdates();
    super.dispose();
  }
}
