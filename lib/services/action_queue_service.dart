import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offline action queue system
/// Queues user actions (vote, message, location) when offline
/// Auto-syncs when connectivity restored
class ActionQueueService {
  static const String _queueKey = 'offline_action_queue';
  static const String _queueTimestampKey = 'offline_action_queue_timestamp';
  
  static SharedPreferences? _prefs;
  
  /// Action types that can be queued
  static const String actionVote = 'vote';
  static const String actionMessage = 'message';
  static const String actionLocationUpdate = 'location_update';
  static const String actionBookmark = 'bookmark';
  static const String actionPrivateMessage = 'private_message';
  
  /// Initialize action queue service
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Queue an action to be synced later
  static Future<void> queueAction({
    required String actionType,
    required String targetId, // pollId, chatId, etc.
    required Map<String, dynamic> payload,
    String? groupId, // For batching similar actions
  }) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      
      final action = OfflineAction(
        id: '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}',
        actionType: actionType,
        targetId: targetId,
        payload: payload,
        groupId: groupId,
        queuedAt: DateTime.now(),
        status: 'pending',
      );
      
      // Get existing queue
      final queueJson = prefs.getString(_queueKey);
      final queue = queueJson != null ? jsonDecode(queueJson) as List : [];
      
      // Add new action
      queue.add(action.toJson());
      
      // Persist updated queue
      await prefs.setString(_queueKey, jsonEncode(queue));
      await prefs.setInt(
        _queueTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      
      debugPrint('📋 Queued offline action: $actionType for $targetId');
    } catch (e) {
      debugPrint('❌ Error queueing action: $e');
      rethrow;
    }
  }
  
  /// Get all pending actions
  static Future<List<OfflineAction>> getPendingActions() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson == null) {
        return [];
      }
      
      final queue = jsonDecode(queueJson) as List;
      return queue
          .map((item) => OfflineAction.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Error loading pending actions: $e');
      return [];
    }
  }
  
  /// Get actions of a specific type
  static Future<List<OfflineAction>> getActionsByType(String actionType) async {
    final all = await getPendingActions();
    return all.where((a) => a.actionType == actionType).toList();
  }
  
  /// Mark action as synced (remove from queue)
  static Future<void> markActionSynced(String actionId) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson == null) {
        return;
      }
      
      var queue = jsonDecode(queueJson) as List;
      queue.removeWhere((item) => item['id'] == actionId);
      
      await prefs.setString(_queueKey, jsonEncode(queue));
      debugPrint('✅ Marked action as synced: $actionId');
    } catch (e) {
      debugPrint('❌ Error marking action synced: $e');
    }
  }
  
  /// Mark multiple actions as synced
  static Future<void> markActionsSynced(List<String> actionIds) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson == null) {
        return;
      }
      
      var queue = jsonDecode(queueJson) as List;
      queue.removeWhere((item) => actionIds.contains(item['id']));
      
      await prefs.setString(_queueKey, jsonEncode(queue));
      debugPrint('✅ Marked ${actionIds.length} actions as synced');
    } catch (e) {
      debugPrint('❌ Error marking actions synced: $e');
    }
  }
  
  /// Clear all pending actions
  static Future<void> clearQueue() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.remove(_queueKey);
      await prefs.remove(_queueTimestampKey);
      debugPrint('🗑️ Cleared offline action queue');
    } catch (e) {
      debugPrint('❌ Error clearing queue: $e');
    }
  }
  
  /// Get queue size and last update time
  static Future<Map<String, dynamic>> getQueueStats() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      final timestamp = prefs.getInt(_queueTimestampKey);
      
      final queue = queueJson != null ? jsonDecode(queueJson) as List : [];
      
      return {
        'pending_actions': queue.length,
        'last_update': timestamp != null 
            ? DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()
            : null,
        'queue_size_kb': queueJson?.length ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Error getting queue stats: $e');
      return {'pending_actions': 0};
    }
  }
}

/// Internal representation of a queued action
class OfflineAction {
  final String id;
  final String actionType;
  final String targetId;
  final Map<String, dynamic> payload;
  final String? groupId;
  final DateTime queuedAt;
  final String status; // pending, syncing, failed
  
  OfflineAction({
    required this.id,
    required this.actionType,
    required this.targetId,
    required this.payload,
    this.groupId,
    required this.queuedAt,
    required this.status,
  });
  
  factory OfflineAction.fromJson(Map<String, dynamic> json) {
    return OfflineAction(
      id: json['id'] ?? '',
      actionType: json['action_type'] ?? '',
      targetId: json['target_id'] ?? '',
      payload: json['payload'] ?? {},
      groupId: json['group_id'],
      queuedAt: json['queued_at'] != null
          ? DateTime.parse(json['queued_at'])
          : DateTime.now(),
      status: json['status'] ?? 'pending',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action_type': actionType,
      'target_id': targetId,
      'payload': payload,
      'group_id': groupId,
      'queued_at': queuedAt.toIso8601String(),
      'status': status,
    };
  }
}
