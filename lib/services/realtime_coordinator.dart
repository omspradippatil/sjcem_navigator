import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Unified realtime coordinator to reduce duplicate subscriptions
/// Single source of truth for all realtime channels across providers
class RealtimeCoordinator {
  static final RealtimeCoordinator _instance = RealtimeCoordinator._internal();
  
  factory RealtimeCoordinator() {
    return _instance;
  }
  
  RealtimeCoordinator._internal();
  
  // Track all active subscriptions to prevent duplicates
  final Map<String, RealtimeChannel> _subscriptions = {};
  final Map<String, List<void Function(PostgresChangePayload)>> _subscribers =
      {};
  
  /// Subscribe to a table with automatic deduplication
  /// Calls [onData] whenever payload is received
  RealtimeChannel subscribeToTable(
    String tableName, {
    required void Function(PostgresChangePayload payload) onData,
  }) {
    // Register subscriber
    _subscribers.putIfAbsent(tableName, () => []);
    _subscribers[tableName]!.add(onData);
    
    // Return if already subscribed to avoid duplicate
    if (_subscriptions.containsKey(tableName)) {
      debugPrint('♻️ Reusing existing subscription for $tableName');
      return _subscriptions[tableName]!;
    }
    
    // Create new subscription
    debugPrint('📡 Creating new realtime subscription: $tableName');
    
    final subscription = Supabase.instance.client
        .channel('coordinator-$tableName')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: tableName,
          callback: (payload) {
            debugPrint('🔔 Event on $tableName: ${payload.eventType.name}');
            // Broadcast to all subscribers for this table
            for (final subscriber in _subscribers[tableName] ?? []) {
              subscriber(payload);
            }
          },
        )
        .subscribe();
    
    _subscriptions[tableName] = subscription;
    debugPrint('✅ Subscribed to: $tableName');
    return subscription;
  }
  
  /// Unsubscribe from a specific table
  Future<void> unsubscribeFromTable(String tableName) async {
    if (!_subscriptions.containsKey(tableName)) {
      return;
    }
    
    debugPrint('🔌 Unsubscribing from: $tableName');
    await _subscriptions[tableName]!.unsubscribe();
    _subscriptions.remove(tableName);
    _subscribers.remove(tableName);
  }
  
  /// Unsubscribe a specific callback from a table
  /// Useful for cleaning up provider subscriptions without killing full subscription
  void removeSubscriber(String tableName, Function subscriber) {
    _subscribers[tableName]?.remove(subscriber);
    if (_subscribers[tableName]?.isEmpty ?? false) {
      debugPrint('👤 Removed last subscriber from $tableName, keeping subscription');
    } else {
      debugPrint('👤 Removed subscriber from $tableName');
    }
  }
  
  /// Unsubscribe all subscriptions (e.g., on logout)
  Future<void> unsubscribeAll() async {
    debugPrint('🌐 Unsubscribing from all realtime subscriptions');
    final keys = List.from(_subscriptions.keys);
    for (final key in keys) {
      await unsubscribeFromTable(key);
    }
  }
  
  /// Get list of active subscriptions (useful for debugging)
  List<String> getActiveSubscriptions() => _subscriptions.keys.toList();

  /// Backward-compatible alias used by integration docs.
  List<String> getActiveChannels() => getActiveSubscriptions();
  
  /// Check if a specific table is subscribed
  bool isSubscribed(String tableName) => _subscriptions.containsKey(tableName);
  
  /// Get subscription count per table
  Map<String, int> getSubscriptionStats() {
    return {
      for (var entry in _subscribers.entries)
        entry.key: entry.value.length,
    };
  }
}
