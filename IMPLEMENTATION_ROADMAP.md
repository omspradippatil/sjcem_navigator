# SJCEM Navigator - Feature Roadmap Implementation Guide

## ✅ PHASE 1 (COMPLETED) - Critical Foundations

### 1. **Realtime Unification Coordinator**
**File**: `lib/services/realtime_coordinator.dart` ✅

**Purpose**: Single source of truth for all realtime subscriptions, preventing duplicate channels and race conditions.

**Key Features**:
- Deduplicates subscriptions to same table/filter
- Tracks all active channels with unique keys
- Auto-reuses channels instead of creating duplicates
- Supports filters for targeted subscriptions
- One-to-many subscriber pattern (multiple providers can listen to one channel)

**Usage Example**:
```dart
final coordinator = RealtimeCoordinator();

// Provider 1
coordinator.subscribeToTable(
  'notices',
  onData: (payload) {
    // Handle announcements
  },
);

// Provider 2 - reuses same channel automatically
coordinator.subscribeToTable(
  'notices',
  onData: (payload) {
    // Another handler on same channel
  },
);

// Get stats for debugging
print(coordinator.getSubscriptionStats()); // {notices: 2}
```

**Integration**: Used in `AnnouncementsProvider`, ready for chat/polls/navigation providers.

---

### 2. **Role-Based Feature Flags Provider**
**File**: `lib/providers/feature_flags_provider.dart` ✅

**Purpose**: Dynamic feature enable/disable per user role for safe demo presentations and production toggling.

**Pre-configured Features**:
- `announcements` - Show admin/teacher announcements (enabled for all)
- `indoor_navigation` - Multi-stop waypoint nav (enabled for students/teachers)
- `chat_threads` - Threaded messaging (enabled for students/teachers)
- `study_materials_search` - Global search (enabled for students/teachers)
- `polls_advanced` - Scheduling + segmentation (enabled for all)
- `offline_sync` - Action queue system (enabled for students/teachers)
- `digital_twin` - Campus map view (demo only, disabled default)
- `academic_widgets` - Home widgets (enabled for all)
- `observability` - Diagnostics page (admin/judges only)

**Usage Example**:
```dart
// In build method or provider
final flags = context.read<FeatureFlagsProvider>();

if (flags.isEnabled('announcements')) {
  // Show announcements tab
}

// Admin toggle (debug/demo)
await flags.toggle('digital_twin');

// Sync from backend for cloud control
await flags.syncFromBackend({
  'announcements': false,
  'digital_twin': true,
});
```

**Initialization**: Added to main.dart MultiProvider.

---

### 3. **Offline Action Queue Service**
**File**: `lib/services/action_queue_service.dart` ✅

**Purpose**: Queue user actions (vote, message, location) when offline, auto-sync on reconnect.

**Supported Actions**:
- `ActionQueueService.actionVote` - Poll votes
- `ActionQueueService.actionMessage` - Chat messages
- `ActionQueueService.actionLocationUpdate` - Location updates
- `ActionQueueService.actionBookmark` - Study material bookmarks
- `ActionQueueService.actionPrivateMessage` - DMs

**Usage Example**:
```dart
// User votes offline
await ActionQueueService.queueAction(
  actionType: ActionQueueService.actionVote,
  targetId: pollId,
  payload: {
    'option_id': optionId,
    'poll_id': pollId,
  },
  groupId: pollId, // Batch by poll
);

// Later, when online - get all pending
final pending = await ActionQueueService.getPendingActions();
for (final action in pending) {
  // Sync to Supabase
  await syncActionToBackend(action);
  await ActionQueueService.markActionSynced(action.id);
}

// Check queue size
final stats = await ActionQueueService.getQueueStats();
print('${stats['pending_actions']} actions queued');
```

**Initialization**: Added to main.dart with OfflineCacheService.

---

### 4. **Announcements Provider & Tab UI**
**Files**: 
- `lib/providers/announcements_provider.dart` ✅
- `lib/screens/home/announcements_tab.dart` ✅

**Purpose**: Real-time announcement display with pinning, expiry, and rich UI.

**Features**:
- Real-time subscriptions via Realtime Coordinator
- Automatic caching for offline
- Pinned announcements widget
- Expiry tracking
- Branch-scoped announcements
- Read status tracking
- Pull-to-refresh

**UI Components**:
- Pinned section at top (up to 3)
- Recent announcements below
- Creator name and timestamp
- Expiry badge if applicable
- Bottom sheet full-screen detail view

**Implementation Note**: Uses existing `Announcement` model from database.

---

## 📋 PHASE 2 (READY TO IMPLEMENT) - User-Facing Features

### Next Priority: Study Materials Enhanced Search

**Planned Features**:
- Global FTS search (title, teacher, semester, subject, content)
- Bookmarks/favorites with heart icon
- "Recently opened" section
- Smart tags and metadata
- File preview cards

**Implementation Plan**:
1. Extend `StudyMaterialsProvider` with search logic
2. Add FTS query to `SupabaseService.searchStudyMaterials()`
3. Create search UI components
4. Add bookmark state management
5. Integrate with offline cache

---

## 🗺️ PHASE 3 (ARCHITECTED) - Navigation & Chat Enhancements

### Planned Features:

**Indoor Navigation Multi-Stop**:
- Waypoint-based pathfinding
- Floor transition detection
- Auto-recalibration on floor change
- Voice/haptic guidance

**Chat Threads + Moderation**:
- Thread/reply structure
- @mentions with notifications
- Pin important messages
- Profanity filter
- Report system
- Mute users

---

## 🎯 Integration Checklist

### ✅ Done:
- [x] Realtime Coordinator created and documented
- [x] Feature Flags provider with 9 pre-configured flags
- [x] Action Queue service with 5 action types
- [x] Announcements provider with realtime sync
- [x] Announcements UI with pinning and detail view
- [x] main.dart updated with new providers and services
- [x] OfflineCacheService initialized alongside FeatureFlagsProvider

### 📝 Next Steps:
- [ ] Add `getAnnouncements()` method to SupabaseService (if not exists)
- [ ] Update chat_provider.dart to use RealtimeCoordinator
- [ ] Update poll_provider.dart with scheduling logic
- [ ] Enhance study_materials_provider.dart with search
- [ ] Create observability diagnostics page
- [ ] Add offline sync banner to main app
- [ ] Test all features with feature flags on/off

### 🔌 Connection Points:

**For Chat Enhancement**:
```dart
// In chat_provider.dart, replace direct subscriptions with:
final coordinator = RealtimeCoordinator();
coordinator.subscribeToTable(
  'chat_messages',
  onData: _handleChatUpdate,
);
```

**For Poll Enhancement**:
```dart
// Add to poll_provider.dart
final coordinator = RealtimeCoordinator();
coordinator.subscribeToTable(
  'polls',
  onData: _handlePollUpdate,
);
```

---

## 📊 Architecture Benefits

1. **Realtime Unification**: 
   - Before: 7 providers × N subscriptions = potential 7N channels
   - After: Single coordinator reuses channels → reduced memory, network overhead

2. **Feature Flags**:
   - Safe demo mode (disable risky features)
   - Backend control (enable/disable without app update)
   - Role-based access (judges see different features)

3. **Offline Action Queue**:
   - Users can interact offline (vote, message, bookmark)
   - Automatic sync on reconnect
   - Prevents data loss

4. **Announcements**:
   - Instant notifications for important updates
   - Pinning for critical info
   - Beautiful, theme-consistent UI

---

## 🚀 Quick Start for Next Developer

1. **Enable offline editing**: Implement sync logic in ChatProvider and PollProvider to consume action queue
2. **Add search**: Extend StudyMaterialsProvider with global FTS (Full-Text Search)
3. **Polish navigation**: Add floor transition logic to NavigationProvider
4. **Observability**: Create diagnostics page showing queue stats, cache age, realtime channel count

All groundwork is ready; implementation is sequential and modular.
