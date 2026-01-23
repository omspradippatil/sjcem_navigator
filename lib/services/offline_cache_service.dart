import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for caching data offline
/// Enables the app to work without internet connection
class OfflineCacheService {
  static const String _timetableKey = 'cached_timetable';
  static const String _roomsKey = 'cached_rooms';
  static const String _waypointsKey = 'cached_waypoints';
  static const String _connectionsKey = 'cached_connections';
  static const String _lastUpdateKey = 'last_cache_update';

  static SharedPreferences? _prefs;

  /// Initialize the cache service
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure prefs is initialized
  static Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Get the last time cache was updated
  static Future<DateTime?> getLastCacheUpdate() async {
    final prefs = await _preferences;
    final timestamp = prefs.getInt(_lastUpdateKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Update the last cache timestamp
  static Future<void> _updateLastCacheTime() async {
    final prefs = await _preferences;
    await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
  }

  // =============================================
  // TIMETABLE CACHING
  // =============================================

  /// Cache timetable entries
  static Future<void> cacheTimetable(
      List<TimetableEntry> entries, String branchId, int semester) async {
    try {
      final prefs = await _preferences;
      final key = '${_timetableKey}_${branchId}_$semester';

      final jsonList = entries.map((e) => e.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt(
          '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
      await _updateLastCacheTime();

      debugPrint(
          '📦 Cached ${entries.length} timetable entries for $branchId semester $semester');
    } catch (e) {
      debugPrint('Error caching timetable: $e');
    }
  }

  /// Get cached timetable entries
  static Future<List<TimetableEntry>> getCachedTimetable(
      String branchId, int semester) async {
    try {
      final prefs = await _preferences;
      final key = '${_timetableKey}_${branchId}_$semester';

      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => TimetableEntry.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached timetable: $e');
      return [];
    }
  }

  /// Check if timetable is cached
  static Future<bool> hasCachedTimetable(String branchId, int semester) async {
    final prefs = await _preferences;
    final key = '${_timetableKey}_${branchId}_$semester';
    return prefs.containsKey(key);
  }

  /// Get timetable cache timestamp
  static Future<DateTime?> getTimetableCacheTime(
      String branchId, int semester) async {
    final prefs = await _preferences;
    final key = '${_timetableKey}_${branchId}_$semester';
    final timestamp = prefs.getInt('${key}_timestamp');
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  // =============================================
  // ROOMS CACHING
  // =============================================

  /// Cache rooms
  static Future<void> cacheRooms(List<Room> rooms) async {
    try {
      final prefs = await _preferences;
      final jsonList = rooms.map((r) => r.toJson()).toList();
      await prefs.setString(_roomsKey, jsonEncode(jsonList));
      await prefs.setInt(
          '${_roomsKey}_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint('📦 Cached ${rooms.length} rooms');
    } catch (e) {
      debugPrint('Error caching rooms: $e');
    }
  }

  /// Get cached rooms
  static Future<List<Room>> getCachedRooms() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_roomsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Room.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached rooms: $e');
      return [];
    }
  }

  /// Check if rooms are cached
  static Future<bool> hasCachedRooms() async {
    final prefs = await _preferences;
    return prefs.containsKey(_roomsKey);
  }

  // =============================================
  // WAYPOINTS CACHING
  // =============================================

  /// Cache waypoints
  static Future<void> cacheWaypoints(List<NavigationWaypoint> waypoints) async {
    try {
      final prefs = await _preferences;
      final jsonList = waypoints.map((w) => w.toJson()).toList();
      await prefs.setString(_waypointsKey, jsonEncode(jsonList));

      debugPrint('📦 Cached ${waypoints.length} waypoints');
    } catch (e) {
      debugPrint('Error caching waypoints: $e');
    }
  }

  /// Get cached waypoints
  static Future<List<NavigationWaypoint>> getCachedWaypoints() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_waypointsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => NavigationWaypoint.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached waypoints: $e');
      return [];
    }
  }

  /// Cache waypoint connections
  static Future<void> cacheConnections(
      List<WaypointConnection> connections) async {
    try {
      final prefs = await _preferences;
      final jsonList = connections.map((c) => c.toJson()).toList();
      await prefs.setString(_connectionsKey, jsonEncode(jsonList));

      debugPrint('📦 Cached ${connections.length} connections');
    } catch (e) {
      debugPrint('Error caching connections: $e');
    }
  }

  /// Get cached waypoint connections
  static Future<List<WaypointConnection>> getCachedConnections() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_connectionsKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => WaypointConnection.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached connections: $e');
      return [];
    }
  }

  // =============================================
  // CACHE MANAGEMENT
  // =============================================

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await _preferences;
      final keys = prefs.getKeys().where(
          (key) => key.startsWith('cached_') || key.contains('_timestamp'));

      for (final key in keys) {
        await prefs.remove(key);
      }

      debugPrint('🗑️ Cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Check if cache is stale (older than 24 hours)
  static Future<bool> isCacheStale(String key) async {
    final prefs = await _preferences;
    final timestamp = prefs.getInt('${key}_timestamp');
    if (timestamp == null) return true;

    final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    return now.difference(cacheTime).inHours > 24;
  }

  /// Get cache size info
  static Future<Map<String, int>> getCacheInfo() async {
    final prefs = await _preferences;
    final keys = prefs.getKeys().where((key) => key.startsWith('cached_'));

    int totalSize = 0;
    int itemCount = 0;

    for (final key in keys) {
      final value = prefs.getString(key);
      if (value != null) {
        totalSize += value.length;
        itemCount++;
      }
    }

    return {
      'items': itemCount,
      'sizeBytes': totalSize,
    };
  }
}
