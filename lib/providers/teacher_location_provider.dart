import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class TeacherLocationProvider extends ChangeNotifier {
  Map<String, Teacher> _teacherLocations = {}; // teacherId -> Teacher with location
  Map<String, Room> _roomsCache = {}; // roomId -> Room
  RealtimeChannel? _locationChannel;
  bool _isLoading = false;
  String? _error;
  Timer? _autoUpdateTimer;

  Map<String, Teacher> get teacherLocations => _teacherLocations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTeacherLocations() async {
    _isLoading = true;
    _error = null;

    try {
      // Load rooms for cache
      final rooms = await SupabaseService.getRooms();
      _roomsCache = {for (var room in rooms) room.id: room};
      
      // Load teachers with location
      final teachers = await SupabaseService.getTeachersWithLocation();
      _teacherLocations = {for (var teacher in teachers) teacher.id: teacher};
      
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load teacher locations: ${e.toString()}';
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  void subscribeToLocationUpdates() {
    _locationChannel?.unsubscribe();
    
    _locationChannel = SupabaseService.subscribeToTeacherLocations(
      (data) {
        if (data['current_room_id'] != null) {
          final teacher = Teacher.fromJson(data);
          _teacherLocations[teacher.id] = teacher;
        } else {
          _teacherLocations.remove(data['id']);
        }
        notifyListeners();
      },
    );
  }

  void unsubscribeFromLocationUpdates() {
    _locationChannel?.unsubscribe();
    _locationChannel = null;
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
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

  Future<bool> updateMyLocation(String teacherId, String? roomId) async {
    try {
      final success = await SupabaseService.updateTeacherLocation(
        teacherId,
        roomId,
      );
      
      if (success) {
        if (roomId != null) {
          // Reload teacher data
          final teacher = await SupabaseService.getTeacherById(teacherId);
          if (teacher != null) {
            _teacherLocations[teacherId] = teacher;
          }
        } else {
          _teacherLocations.remove(teacherId);
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
  /// This runs every 5 minutes to update location automatically
  void startAutoLocationUpdate(String teacherId) {
    // Initial update
    _autoUpdateFromTimetable(teacherId);
    
    // Set up periodic updates
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _autoUpdateFromTimetable(teacherId),
    );
  }

  Future<void> _autoUpdateFromTimetable(String teacherId) async {
    try {
      final scheduledRoomId = await SupabaseService.getTeacherScheduledRoom(teacherId);
      
      if (scheduledRoomId != null) {
        // Teacher should be in this room based on timetable
        final currentTeacher = _teacherLocations[teacherId];
        if (currentTeacher?.currentRoomId != scheduledRoomId) {
          await updateMyLocation(teacherId, scheduledRoomId);
        }
      } else {
        // No class scheduled, optionally clear location
        // Uncomment if you want to auto-clear when no class:
        // await updateMyLocation(teacherId, null);
      }
    } catch (e) {
      debugPrint('Auto-location update error: $e');
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
