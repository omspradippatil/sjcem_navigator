import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';

class TeacherLocationProvider extends ChangeNotifier {
  Map<String, Teacher> _teacherLocations =
      {}; // teacherId -> Teacher with location
  Map<String, Room> _roomsCache = {}; // roomId -> Room
  RealtimeChannel? _locationChannel;
  bool _isLoading = false;
  String? _error;
  Timer? _autoUpdateTimer;
  Timer?
      _minuteTimer; // Timer that fires every minute for precise class transitions

  // Offline mode tracking
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  Map<String, Teacher> get teacherLocations => _teacherLocations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTeacherLocations() async {
    _isLoading = true;
    _error = null;
    _isOfflineMode = false;

    try {
      // Load rooms for cache
      final rooms = await SupabaseService.getRooms();
      _roomsCache = {for (var room in rooms) room.id: room};

      // Load teachers with location
      final teachers = await SupabaseService.getTeachersWithLocation();
      _teacherLocations = {for (var teacher in teachers) teacher.id: teacher};

      // Cache for offline use
      if (teachers.isNotEmpty) {
        await OfflineCacheService.cacheTeachers(teachers);
      }
      if (rooms.isNotEmpty) {
        await OfflineCacheService.cacheRooms(rooms);
      }

      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error loading teacher locations: $e - trying offline cache');

      // Try to load from offline cache
      final cachedTeachers = await OfflineCacheService.getCachedTeachers();
      final cachedRooms = await OfflineCacheService.getCachedRooms();

      if (cachedTeachers.isNotEmpty || cachedRooms.isNotEmpty) {
        _teacherLocations = {
          for (var teacher in cachedTeachers) teacher.id: teacher
        };
        _roomsCache = {for (var room in cachedRooms) room.id: room};
        _isOfflineMode = true;
        _error = null;
        debugPrint(
            '📦 Loaded ${cachedTeachers.length} teachers from offline cache');
      } else {
        _error = 'No internet. Connect to see teacher locations.';
      }

      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  void subscribeToLocationUpdates() {
    try {
      _locationChannel?.unsubscribe();

      _locationChannel = SupabaseService.subscribeToTeacherLocations(
        (data) {
          try {
            if (data['current_room_id'] != null) {
              final teacher = Teacher.fromJson(data);
              _teacherLocations[teacher.id] = teacher;
            } else {
              _teacherLocations.remove(data['id']);
            }
            notifyListeners();
          } catch (e) {
            debugPrint('Error processing location update: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to location updates: $e');
    }
  }

  void unsubscribeFromLocationUpdates() {
    try {
      _locationChannel?.unsubscribe();
      _locationChannel = null;
      _autoUpdateTimer?.cancel();
      _autoUpdateTimer = null;
      _minuteTimer?.cancel();
      _minuteTimer = null;
    } catch (e) {
      debugPrint('Error unsubscribing from location updates: $e');
    }
  }

  Room? getRoomForTeacher(String teacherId) {
    final teacher = _teacherLocations[teacherId];
    if (teacher?.currentRoomId != null) {
      return _roomsCache[teacher!.currentRoomId];
    }
    return null;
  }

  String? getRoomNameForTeacher(String teacherId) {
    final room = getRoomForTeacher(teacherId);
    return room?.effectiveName; // Uses display_name if available
  }

  Future<bool> updateMyLocation(String teacherId, String? roomId) async {
    try {
      final success = await SupabaseService.updateTeacherLocation(
        teacherId,
        roomId,
      );

      if (success) {
        if (roomId != null) {
          // Reload teacher data
          try {
            final teacher = await SupabaseService.getTeacherById(teacherId);
            if (teacher != null) {
              _teacherLocations[teacherId] = teacher;
            }
          } catch (e) {
            debugPrint('Error reloading teacher data: $e');
          }
        } else {
          _teacherLocations.remove(teacherId);
        }
        notifyListeners();
      } else {
        _error = 'Failed to update location. Please try again.';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = 'Failed to update location. Please check your connection.';
      debugPrint('Error updating location: $e');
      notifyListeners();
      return false;
    }
  }

  /// Start auto-updating teacher location based on timetable
  /// Uses a minute timer to catch class transitions accurately
  void startAutoLocationUpdate(String teacherId) {
    // Initial update
    _autoUpdateFromTimetable(teacherId);

    // Cancel existing timers
    _autoUpdateTimer?.cancel();
    _minuteTimer?.cancel();

    // Set up minute-based timer for accurate class transitions
    // This checks every minute if teacher should be in a different room
    _minuteTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _autoUpdateFromTimetable(teacherId),
    );

    // Also keep a 5-minute backup timer
    _autoUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _autoUpdateFromTimetable(teacherId),
    );
  }

  Future<void> _autoUpdateFromTimetable(String teacherId) async {
    try {
      // Get teacher's current status based on timetable
      final status = await SupabaseService.getTeacherTimetableStatus(teacherId);

      switch (status['status']) {
        case 'in_class':
          // Teacher should be in this room based on timetable
          final scheduledRoomId = status['roomId'];
          final currentTeacher = _teacherLocations[teacherId];
          if (currentTeacher?.currentRoomId != scheduledRoomId) {
            await updateMyLocation(teacherId, scheduledRoomId);
            debugPrint(
                'Auto-updated teacher $teacherId to room $scheduledRoomId (in class)');
          }
          break;

        case 'in_break':
          // Teacher is on break - set to staffroom if available
          await setTeacherInStaffroom(teacherId);
          debugPrint(
              'Auto-updated teacher $teacherId to staffroom (on ${status['breakName']})');
          break;

        case 'day_finished':
          // All lectures done - set to away
          await setTeacherAway(teacherId);
          debugPrint('Auto-updated teacher $teacherId to away (day finished)');
          break;

        case 'between_classes':
          // Free period between classes - could be in staffroom
          // Keep current location or set to staffroom
          final currentTeacher = _teacherLocations[teacherId];
          if (currentTeacher?.currentRoomId == null) {
            await setTeacherInStaffroom(teacherId);
            debugPrint(
                'Auto-updated teacher $teacherId to staffroom (between classes)');
          }
          break;

        default:
          // 'no_classes' or 'unknown' - keep current location
          break;
      }
    } catch (e) {
      debugPrint('Auto-location update error: $e');
    }
  }

  /// Mark teacher as away (leaving college)
  Future<bool> setTeacherAway(String teacherId) async {
    try {
      final success = await SupabaseService.setTeacherAway(teacherId);
      if (success) {
        _teacherLocations.remove(teacherId);
        notifyListeners();
        debugPrint('Teacher $teacherId marked as away');
      }
      return success;
    } catch (e) {
      debugPrint('Error setting teacher away: $e');
      return false;
    }
  }

  /// Move teacher to staffroom
  Future<bool> setTeacherInStaffroom(String teacherId) async {
    try {
      final success = await SupabaseService.setTeacherInStaffroom(teacherId);
      if (success) {
        // Reload teacher data to get updated location
        final teacher = await SupabaseService.getTeacherById(teacherId);
        if (teacher != null) {
          _teacherLocations[teacherId] = teacher;
        }
        notifyListeners();
        debugPrint('Teacher $teacherId moved to staffroom');
      }
      return success;
    } catch (e) {
      debugPrint('Error setting teacher in staffroom: $e');
      return false;
    }
  }

  /// Get teacher's current status (in class, on break, between classes, etc.)
  Future<Map<String, dynamic>> getTeacherStatus(String teacherId) async {
    try {
      return await SupabaseService.getTeacherTimetableStatus(teacherId);
    } catch (e) {
      return {'status': 'unknown', 'message': 'Unable to get status'};
    }
  }

  /// Get the scheduled room for a teacher based on current time
  Future<Room?> getScheduledRoomForTeacher(String teacherId) async {
    try {
      final roomId = await SupabaseService.getTeacherScheduledRoom(teacherId);
      if (roomId != null) {
        return _roomsCache[roomId];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get teacher's next class info
  Future<Map<String, dynamic>?> getTeacherNextClass(String teacherId) async {
    try {
      return await SupabaseService.getTeacherNextClass(teacherId);
    } catch (e) {
      return null;
    }
  }

  /// Sync all teachers' locations based on current timetable
  /// Useful for admin or HOD to sync all at once
  Future<int> syncAllTeacherLocations() async {
    try {
      final currentClasses = await SupabaseService.getCurrentOngoingClasses();
      int updatedCount = 0;

      for (final classInfo in currentClasses) {
        final teacherId = classInfo['teacher_id'];
        final roomId = classInfo['room_id'];

        if (teacherId != null && roomId != null) {
          final currentTeacher = _teacherLocations[teacherId];
          if (currentTeacher?.currentRoomId != roomId) {
            await SupabaseService.updateTeacherLocation(teacherId, roomId);
            updatedCount++;
          }
        }
      }

      // Reload all teacher locations
      await loadTeacherLocations();

      return updatedCount;
    } catch (e) {
      debugPrint('Error syncing all teacher locations: $e');
      return 0;
    }
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
