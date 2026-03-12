import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

/// Service for caching data offline
/// Enables the app to work without internet connection
class OfflineCacheService {
  static const String _timetableKey = 'cached_timetable';
  static const String _roomsKey = 'cached_rooms';
  static const String _waypointsKey = 'cached_waypoints';
  static const String _connectionsKey = 'cached_connections';
  static const String _branchesKey = 'cached_branches';
  static const String _teachersKey = 'cached_teachers';
  static const String _pollsKey = 'cached_polls';
  static const String _votedPollsKey = 'cached_voted_polls';
  static const String _announcementsKey = 'cached_announcements';
  static const String _chatMessagesKey = 'cached_chat_messages';
  static const String _studyFoldersKey = 'cached_study_folders';
  static const String _studyFilesKey = 'cached_study_files';
  static const String _lastUpdateKey = 'last_cache_update';

  static SharedPreferences? _prefs;

  // Connectivity state
  static bool _isOnline = true;
  static bool get isOnline => _isOnline;
  static bool get isOffline => !_isOnline;

  /// Initialize the cache service
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await checkConnectivity();
  }

  /// Check if device has internet connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isOnline = false;
    } on Exception catch (_) {
      _isOnline = false;
    }
    debugPrint('📶 Connectivity: ${_isOnline ? "Online" : "Offline"}');
    return _isOnline;
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
  // BRANCHES CACHING
  // =============================================

  /// Cache branches
  static Future<void> cacheBranches(List<Branch> branches) async {
    try {
      final prefs = await _preferences;
      final jsonList = branches.map((b) => b.toJson()).toList();
      await prefs.setString(_branchesKey, jsonEncode(jsonList));
      await prefs.setInt(
          '${_branchesKey}_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint('📦 Cached ${branches.length} branches');
    } catch (e) {
      debugPrint('Error caching branches: $e');
    }
  }

  /// Get cached branches
  static Future<List<Branch>> getCachedBranches() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_branchesKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Branch.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached branches: $e');
      return [];
    }
  }

  /// Check if branches are cached
  static Future<bool> hasCachedBranches() async {
    final prefs = await _preferences;
    return prefs.containsKey(_branchesKey);
  }

  // =============================================
  // TEACHERS CACHING (for teacher locations)
  // =============================================

  /// Cache teachers with location data
  static Future<void> cacheTeachers(List<Teacher> teachers) async {
    try {
      final prefs = await _preferences;
      final jsonList = teachers.map((t) => t.toJson()).toList();
      await prefs.setString(_teachersKey, jsonEncode(jsonList));
      await prefs.setInt(
          '${_teachersKey}_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint('📦 Cached ${teachers.length} teachers');
    } catch (e) {
      debugPrint('Error caching teachers: $e');
    }
  }

  /// Get cached teachers
  static Future<List<Teacher>> getCachedTeachers() async {
    try {
      final prefs = await _preferences;
      final jsonString = prefs.getString(_teachersKey);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Teacher.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached teachers: $e');
      return [];
    }
  }

  /// Check if teachers are cached
  static Future<bool> hasCachedTeachers() async {
    final prefs = await _preferences;
    return prefs.containsKey(_teachersKey);
  }

  // =============================================
  // POLLS CACHING
  // =============================================

  /// Cache polls
  static Future<void> cachePolls(List<Poll> polls, String branchId) async {
    try {
      final prefs = await _preferences;
      final key = '${_pollsKey}_$branchId';
      final jsonList = polls.map((p) => _pollToJson(p)).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt(
          '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint('📦 Cached ${polls.length} polls for branch $branchId');
    } catch (e) {
      debugPrint('Error caching polls: $e');
    }
  }

  /// Get cached polls
  static Future<List<Poll>> getCachedPolls(String branchId) async {
    try {
      final prefs = await _preferences;
      final key = '${_pollsKey}_$branchId';
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Poll.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached polls: $e');
      return [];
    }
  }

  /// Convert poll to JSON for caching (including options)
  static Map<String, dynamic> _pollToJson(Poll poll) {
    return {
      'id': poll.id,
      'title': poll.title,
      'description': poll.description,
      'branch_id': poll.branchId,
      'created_by': poll.createdBy,
      'is_active': poll.isActive,
      'is_anonymous': poll.isAnonymous,
      'target_all_branches': poll.targetAllBranches,
      'ends_at': poll.endsAt?.toIso8601String(),
      'created_at': poll.createdAt?.toIso8601String(),
      'poll_options': poll.options
          .map((o) => {
                'id': o.id,
                'poll_id': o.pollId,
                'option_text': o.optionText,
                'vote_count': o.voteCount,
                'created_at': o.createdAt?.toIso8601String(),
              })
          .toList(),
    };
  }

  // =============================================
  // VOTED POLLS CACHING (Per User)
  // =============================================

  /// Cache user's voted polls (pollId -> optionId)
  static Future<void> cacheVotedPolls(
      String userId, Map<String, String?> votedPolls) async {
    try {
      final prefs = await _preferences;
      final key = '${_votedPollsKey}_$userId';
      await prefs.setString(key, jsonEncode(votedPolls));

      debugPrint('📦 Cached ${votedPolls.length} voted polls for user $userId');
    } catch (e) {
      debugPrint('Error caching voted polls: $e');
    }
  }

  /// Get user's cached voted polls
  static Future<Map<String, String?>> getCachedVotedPolls(String userId) async {
    try {
      final prefs = await _preferences;
      final key = '${_votedPollsKey}_$userId';
      final jsonString = prefs.getString(key);
      if (jsonString == null) return {};

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String?));
    } catch (e) {
      debugPrint('Error getting cached voted polls: $e');
      return {};
    }
  }

  /// Add a single vote to cached voted polls
  static Future<void> cacheVote(
      String userId, String pollId, String optionId) async {
    try {
      final votedPolls = await getCachedVotedPolls(userId);
      votedPolls[pollId] = optionId;
      await cacheVotedPolls(userId, votedPolls);
    } catch (e) {
      debugPrint('Error caching vote: $e');
    }
  }

  // =============================================
  // ANNOUNCEMENTS CACHING
  // =============================================

  /// Cache announcements
  static Future<void> cacheAnnouncements(
      List<Announcement> announcements, String branchId) async {
    try {
      final prefs = await _preferences;
      final key = '${_announcementsKey}_$branchId';
      final jsonList = announcements.map((a) => a.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
      await prefs.setInt(
          '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);

      debugPrint(
          '📦 Cached ${announcements.length} announcements for branch $branchId');
    } catch (e) {
      debugPrint('Error caching announcements: $e');
    }
  }

  /// Get cached announcements
  static Future<List<Announcement>> getCachedAnnouncements(
      String branchId) async {
    try {
      final prefs = await _preferences;
      final key = '${_announcementsKey}_$branchId';
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => Announcement.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached announcements: $e');
      return [];
    }
  }

  // =============================================
  // CHAT MESSAGES CACHING
  // =============================================

  /// Cache chat messages for a branch
  static Future<void> cacheChatMessages(
      List<ChatMessage> messages, String branchId) async {
    try {
      final prefs = await _preferences;
      final key = '${_chatMessagesKey}_$branchId';
      // Only cache last 100 messages
      final messagesToCache = messages.take(100).toList();
      final jsonList = messagesToCache.map((m) => m.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));

      debugPrint(
          '📦 Cached ${messagesToCache.length} chat messages for branch $branchId');
    } catch (e) {
      debugPrint('Error caching chat messages: $e');
    }
  }

  /// Get cached chat messages
  static Future<List<ChatMessage>> getCachedChatMessages(
      String branchId) async {
    try {
      final prefs = await _preferences;
      final key = '${_chatMessagesKey}_$branchId';
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => ChatMessage.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached chat messages: $e');
      return [];
    }
  }

  // =============================================
  // STUDY FOLDERS & FILES CACHING
  // =============================================

  /// Cache study folders
  static Future<void> cacheStudyFolders(
      List<StudyFolder> folders, String? parentId) async {
    try {
      final prefs = await _preferences;
      final key = '${_studyFoldersKey}_${parentId ?? 'root'}';
      final jsonList = folders.map((f) => f.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));

      debugPrint('📦 Cached ${folders.length} folders for parent $parentId');
    } catch (e) {
      debugPrint('Error caching study folders: $e');
    }
  }

  /// Get cached study folders
  static Future<List<StudyFolder>> getCachedStudyFolders(
      String? parentId) async {
    try {
      final prefs = await _preferences;
      final key = '${_studyFoldersKey}_${parentId ?? 'root'}';
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => StudyFolder.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached study folders: $e');
      return [];
    }
  }

  /// Cache study files
  static Future<void> cacheStudyFiles(
      List<StudyFile> files, String folderId) async {
    try {
      final prefs = await _preferences;
      final key = '${_studyFilesKey}_$folderId';
      final jsonList = files.map((f) => f.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));

      debugPrint('📦 Cached ${files.length} files for folder $folderId');
    } catch (e) {
      debugPrint('Error caching study files: $e');
    }
  }

  /// Get cached study files
  static Future<List<StudyFile>> getCachedStudyFiles(String folderId) async {
    try {
      final prefs = await _preferences;
      final key = '${_studyFilesKey}_$folderId';
      final jsonString = prefs.getString(key);
      if (jsonString == null) return [];

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList.map((json) => StudyFile.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting cached study files: $e');
      return [];
    }
  }

  // =============================================
  // EAGER SYNC - Pre-cache all navigation data
  // =============================================

  /// Eagerly sync all navigation-critical data from Supabase to cache.
  /// Call this when the app starts with an internet connection so that
  /// navigation works fully offline afterwards.
  static Future<bool> syncNavigationData() async {
    if (isOffline) {
      debugPrint('📶 Offline - skipping navigation data sync');
      return false;
    }

    try {
      debugPrint('🔄 Syncing navigation data for offline use...');

      // Import is at the top of the file already, use SupabaseService
      final SupabaseClient client = Supabase.instance.client;

      // 1. Sync rooms
      final roomsResponse =
          await client.from('rooms').select().order('room_number');
      final rooms =
          (roomsResponse as List).map((r) => Room.fromJson(r)).toList();
      if (rooms.isNotEmpty) {
        await cacheRooms(rooms);
      }

      // 2. Sync waypoints
      final waypointsResponse =
          await client.from('navigation_waypoints').select();
      final waypoints = (waypointsResponse as List)
          .map((w) => NavigationWaypoint.fromJson(w))
          .toList();
      if (waypoints.isNotEmpty) {
        await cacheWaypoints(waypoints);
      }

      // 3. Sync waypoint connections
      final connectionsResponse =
          await client.from('waypoint_connections').select();
      final connections = (connectionsResponse as List)
          .map((c) => WaypointConnection.fromJson(c))
          .toList();
      if (connections.isNotEmpty) {
        await cacheConnections(connections);
      }

      // 4. Sync branches
      final branchesResponse =
          await client.from('branches').select().order('name');
      final branches =
          (branchesResponse as List).map((b) => Branch.fromJson(b)).toList();
      if (branches.isNotEmpty) {
        await cacheBranches(branches);
      }

      // 5. Sync teachers
      final teachersResponse =
          await client.from('teachers').select().order('name');
      final teachers =
          (teachersResponse as List).map((t) => Teacher.fromJson(t)).toList();
      if (teachers.isNotEmpty) {
        await cacheTeachers(teachers);
      }

      await _updateLastCacheTime();
      debugPrint(
          '✅ Navigation data synced: ${rooms.length} rooms, ${waypoints.length} waypoints, ${connections.length} connections');
      return true;
    } catch (e) {
      debugPrint('❌ Error syncing navigation data: $e');
      return false;
    }
  }

  /// Check if we have enough cached data for offline navigation
  static Future<bool> hasOfflineNavigationData() async {
    final hasRooms = await hasCachedRooms();
    final prefs = await _preferences;
    final hasWaypoints = prefs.containsKey(_waypointsKey);
    final hasConnections = prefs.containsKey(_connectionsKey);
    return hasRooms && hasWaypoints && hasConnections;
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
