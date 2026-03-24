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
  Timer? _globalAutoSyncTimer;
  bool _isAutoUpdateRunning = false;
  bool _isGlobalSyncRunning = false;

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

      // Load all teachers so current/default location state can be tracked consistently.
      final teachers = await SupabaseService.getTeachers();
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
            final teacher = Teacher.fromJson(data);
            _teacherLocations[teacher.id] = teacher;
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
    } catch (e) {
      debugPrint('Error unsubscribing from location updates: $e');
    }
  }

  void stopAutoLocationUpdate() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
    _minuteTimer?.cancel();
    _minuteTimer = null;
  }

  void startGlobalAutoLocationSync(
      {Duration interval = const Duration(minutes: 1)}) {
    if (_globalAutoSyncTimer != null) {
      return;
    }

    _runGlobalAutoSync();
    _globalAutoSyncTimer = Timer.periodic(
      interval,
      (_) => _runGlobalAutoSync(),
    );
  }

  void stopGlobalAutoLocationSync() {
    _globalAutoSyncTimer?.cancel();
    _globalAutoSyncTimer = null;
  }

  Future<void> _runGlobalAutoSync() async {
    if (_isGlobalSyncRunning || _isOfflineMode) {
      return;
    }

    _isGlobalSyncRunning = true;
    try {
      await SupabaseService.autoUpdateAllTeacherLocations();
      final teachers = await SupabaseService.getTeachers();
      _teacherLocations = {for (var teacher in teachers) teacher.id: teacher};

      if (teachers.isNotEmpty) {
        await OfflineCacheService.cacheTeachers(teachers);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Global teacher location sync error: $e');
    } finally {
      _isGlobalSyncRunning = false;
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
        // Reload teacher data so current/default room state is always in sync.
        try {
          final teacher = await SupabaseService.getTeacherById(teacherId);
          if (teacher != null) {
            _teacherLocations[teacherId] = teacher;
          }
        } catch (e) {
          debugPrint('Error reloading teacher data: $e');
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
    stopAutoLocationUpdate();

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
    if (_isAutoUpdateRunning) {
      return;
    }
    _isAutoUpdateRunning = true;

    try {
      // Get teacher's current status based on timetable
      final status = await SupabaseService.getTeacherTimetableStatus(teacherId);
      final currentTeacher =
          _teacherLocations[teacherId] ?? await SupabaseService.getTeacherById(teacherId);

      switch (status['status']) {
        case 'in_class':
          // Teacher should be in this room based on timetable
          final scheduledRoomId = status['roomId'];
          if (currentTeacher?.currentRoomId != scheduledRoomId) {
            await updateMyLocation(teacherId, scheduledRoomId);
            debugPrint(
                'Auto-updated teacher $teacherId to room $scheduledRoomId (in class)');
          }
          break;

        case 'in_break':
          await _setTeacherToDefaultOrStaffroom(teacherId, currentTeacher);
          debugPrint(
              'Auto-updated teacher $teacherId to default/staffroom (on ${status['breakName']})');
          break;

        case 'day_finished':
          await _setTeacherToDefaultOrStaffroom(teacherId, currentTeacher);
          debugPrint('Auto-updated teacher $teacherId to default/staffroom (day finished)');
          break;

        case 'between_classes':
          await _setTeacherToDefaultOrStaffroom(teacherId, currentTeacher);
          debugPrint('Auto-updated teacher $teacherId to default/staffroom (between classes)');
          break;

        case 'no_classes':
          await _setTeacherToDefaultOrStaffroom(teacherId, currentTeacher);
          debugPrint('Auto-updated teacher $teacherId to default/staffroom (no classes)');
          break;

        default:
          // 'no_classes' or 'unknown' - keep current location
          break;
      }
    } catch (e) {
      debugPrint('Auto-location update error: $e');
    } finally {
      _isAutoUpdateRunning = false;
    }
  }

  Future<void> _setTeacherToDefaultOrStaffroom(
      String teacherId, Teacher? teacher) async {
    final defaultRoomId = teacher?.defaultRoomId;

    if (defaultRoomId != null) {
      if (teacher?.currentRoomId != defaultRoomId) {
        await updateMyLocation(teacherId, defaultRoomId);
      }
      return;
    }

    await setTeacherInStaffroom(teacherId);
  }

  /// Mark teacher as away (leaving college)
  Future<bool> setTeacherAway(String teacherId) async {
    try {
      final success = await SupabaseService.setTeacherAway(teacherId);
      if (success) {
        final teacher = await SupabaseService.getTeacherById(teacherId);
        if (teacher != null) {
          _teacherLocations[teacherId] = teacher;
        } else {
          _teacherLocations.remove(teacherId);
        }
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

  Future<bool> updateMyDefaultRoom(String teacherId, String? roomId) async {
    try {
      final success = await SupabaseService.updateTeacherDefaultRoom(
        teacherId,
        roomId,
      );

      if (success) {
        final teacher = await SupabaseService.getTeacherById(teacherId);
        if (teacher != null) {
          _teacherLocations[teacherId] = teacher;
        }
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error updating default room: $e');
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
      final updatedCount = await SupabaseService.autoUpdateAllTeacherLocations();

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
    stopAutoLocationUpdate();
    stopGlobalAutoLocationSync();
    super.dispose();
  }
}
