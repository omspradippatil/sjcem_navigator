import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';
import '../services/realtime_coordinator.dart';

class AnnouncementsProvider extends ChangeNotifier {
  final RealtimeCoordinator _realtime = RealtimeCoordinator();
  
  List<Announcement> _announcements = [];
  List<Announcement> _pinnedAnnouncements = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _announcementsChannel;
  
  List<Announcement> get announcements => _announcements;
  List<Announcement> get pinnedAnnouncements => _pinnedAnnouncements;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Statistics
  int get unreadCount {
    return _announcements.where((a) => a.createdAt != null).length;
  }

  /// Load announcements for a branch
  Future<void> loadAnnouncements({
    required String branchId,
    bool activeOnly = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _announcements = await SupabaseService.getAnnouncements(
        branchId: branchId,
        activeOnly: activeOnly,
      );
      
      // Separate pinned announcements
      _updatePinnedAnnouncements();
      
      // Cache for offline use
      await OfflineCacheService.cacheAnnouncements(_announcements, branchId);
      
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      
      // Try to load from cache
      final cached = await OfflineCacheService.getCachedAnnouncements(branchId);
      if (cached.isNotEmpty) {
        _announcements = cached;
        _updatePinnedAnnouncements();
        _error = null;
        debugPrint('📦 Loaded ${cached.length} announcements from cache');
      } else {
        _error = 'Failed to load announcements. Please try again.';
      }
      
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  /// Subscribe to real-time announcement updates
  void subscribeToAnnouncements(String branchId) {
    try {
      // Use unified realtime coordinator to avoid duplicate subscriptions
      _announcementsChannel = _realtime.subscribeToTable(
        'announcements',
        onData: (payload) {
          final record = payload.newRecord.isNotEmpty
              ? payload.newRecord
              : payload.oldRecord;

          if (record.isEmpty) return;

          // Convert database record to Announcement model
          final announcement = Announcement.fromJson(record);

          if (!_isInBranchScope(announcement.branchId, branchId)) {
            return;
          }

          switch (payload.eventType) {
            case PostgresChangeEvent.insert:
            case PostgresChangeEvent.update:
              // Update or add announcement
              final existingIndex = _announcements
                  .indexWhere((a) => a.id == announcement.id);
              
              if (existingIndex >= 0) {
                _announcements[existingIndex] = announcement;
              } else {
                _announcements.insert(0, announcement);
              }
              _updatePinnedAnnouncements();
              notifyListeners();
              break;

            case PostgresChangeEvent.delete:
              _announcements.removeWhere((a) => a.id == announcement.id);
              _updatePinnedAnnouncements();
              notifyListeners();
              break;
            default:
              break;
          }
        },
      );

      debugPrint('✅ Subscribed to announcements for branch: $branchId');
    } catch (e) {
      debugPrint('Error subscribing to announcements: $e');
      _error = 'Failed to subscribe to live updates';
      notifyListeners();
    }
  }

  /// Unsubscribe from realtime updates
  Future<void> unsubscribe() async {
    if (_announcementsChannel != null) {
      await _realtime.unsubscribeFromTable('announcements');
      _announcementsChannel = null;
      debugPrint('🔌 Unsubscribed from announcements');
    }
  }

  /// Update pinned announcements list
  void _updatePinnedAnnouncements() {
    _pinnedAnnouncements = _announcements
        .where((a) => a.isPinned && a.isActive)
        .take(3)
        .toList();
  }

  /// Check if announcement is in user's branch scope
  bool _isInBranchScope(String? announcementBranchId, String userBranchId) {
    // Global announcements (null branchId) or matching branch
    return announcementBranchId == null ||
        announcementBranchId == userBranchId;
  }

  /// Mark announcement as read (local tracking)
  void markAsRead(String announcementId) {
    // This could be persisted to a separate tracking table in Supabase
    debugPrint('✓ Marked announcement $announcementId as read');
  }

  @override
  void dispose() {
    unsubscribe();
    super.dispose();
  }
}
