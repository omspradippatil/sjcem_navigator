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

  Map<String, Teacher> get teacherLocations => _teacherLocations;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTeacherLocations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load rooms for cache
      final rooms = await SupabaseService.getRooms();
      _roomsCache = {for (var room in rooms) room.id: room};
      
      // Load teachers with location
      final teachers = await SupabaseService.getTeachersWithLocation();
      _teacherLocations = {for (var teacher in teachers) teacher.id: teacher};
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load teacher locations: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
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
