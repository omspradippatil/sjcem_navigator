# Feature Integration Examples

Quick reference for integrating the new Phase 1 & 2 features.

---

## 1. Announcements Integration

```dart
// In your screen's initState or didChangeDependencies
final announcements = context.read<AnnouncementsProvider>();
final auth = context.read<AuthProvider>();

// Load announcements
await announcements.loadAnnouncements(
  branchId: auth.currentUser!.branchId,
);

// Subscribe to live updates
announcements.subscribeToAnnouncements(auth.currentUser!.branchId);

// In UI - check if feature enabled
final flags = context.read<FeatureFlagsProvider>();
if (flags.isEnabled('announcements')) {
  // Show announcements tab
}
```

---

## 2. Using Feature Flags

```dart
// Initialize on auth (in auth_provider.dart after login)
final flags = context.read<FeatureFlagsProvider>();
await flags.init(userRole: user.role); // 'student', 'teacher', 'admin', 'hod'

// Check features throughout app
if (flags.isEnabled('chat_threads')) {
  // Show chat threads UI
}

if (flags.isEnabled('digital_twin')) {
  // Show campus map
}

// Admin toggle (debug mode)
await flags.toggle('announcements');

// Sync from backend
await flags.syncFromBackend({
  'announcements': true,
  'digital_twin': false,
});
```

---

## 3. Offline Action Queue

```dart
// Queue a vote when user is offline
try {
  await ActionQueueService.init();
  
  await ActionQueueService.queueAction(
    actionType: ActionQueueService.actionVote,
    targetId: pollId,
    payload: {
      'option_id': selectedOptionId,
      'poll_id': pollId,
      'student_id': studentId,
    },
    groupId: pollId,
  );
  
  print('Vote queued for sync later');
} catch (e) {
  print('Error queueing vote: $e');
}

// Later when online - sync
Future<void> syncPendingActions() async {
  final pending = await ActionQueueService.getPendingActions();
  
  for (final action in pending) {
    try {
      if (action.actionType == ActionQueueService.actionVote) {
        // Sync vote to backend
        await SupabaseService.vote(
          pollId: action.targetId,
          optionId: action.payload['option_id'],
          studentId: action.payload['student_id'],
        );
        await ActionQueueService.markActionSynced(action.id);
      }
    } catch (e) {
      print('Error syncing action: $e');
    }
  }
  
  // Show sync status
  final stats = await ActionQueueService.getQueueStats();
  print('${stats['pending_actions']} actions still pending');
}
```

---

## 4. Realtime Coordinator Usage

```dart
// In ChatProvider (instead of direct subscriptions)
final coordinator = RealtimeCoordinator();

void subscribeToMessages(String branchId) {
  // This automatically deduplicates if another provider subscribes to same table
  coordinator.subscribeToTable(
    'chat_messages',
    onData: (payload) {
      final message = ChatMessage.fromJson(payload['new']);
      _messages.add(message);
      notifyListeners();
    },
  );
}

// Get active channels for debugging
final channels = coordinator.getActiveChannels();
print('Active channels: $channels'); // ['chat_messages', 'polls', 'notices']

// Get subscription count
final stats = coordinator.getSubscriptionStats();
print(stats); // {'chat_messages': 2, 'polls': 1, 'notices': 3}
```

---

## 5. Advanced Polls Features

```dart
// Import the advanced polls model
import 'models/poll_advanced.dart';

// Create poll with scheduling and segmentation
final scheduling = PollScheduling(
  pollId: 'poll_123',
  scheduledPublishAt: DateTime.now().add(Duration(days: 1)),
  autoCloseAfter: Duration(hours: 24),
  segmentBySemesters: ['3', '4'], // Only for sem 3 & 4
  segmentByBranches: ['CSE', 'ECE'],
);

// Get poll insights after voting
final insights = PollInsights(
  pollId: 'poll_123',
  totalVotes: 245,
  participationRate: 78.5,
  startedAt: poll.createdAt,
  trends: [
    OptionTrend(
      optionId: 'opt_1',
      optionText: 'Option 1',
      voteCount: 120,
      percentage: 49.0,
      hourlyVotes: [10, 15, 25, 30, 40],
    ),
  ],
);

// Display vote trends
for (final trend in insights.trends) {
  print('${trend.optionText}: ${trend.percentage}%');
}
```

---

## 6. Advanced Chat Features

```dart
// Import advanced chat models
import 'models/chat_advanced.dart';

// Send message with mentions and reactions
final message = ChatMessageExtended(
  id: 'msg_123',
  branchId: 'branch_1',
  authorId: currentUserId,
  authorName: currentUserName,
  content: 'Hey @user1 and @user2, check this out!',
  createdAt: DateTime.now(),
  mentions: ['user1_id', 'user2_id'],
  reactions: {
    '👍': ['user3_id', 'user4_id'],
    '❤️': ['user5_id'],
  },
  isPinned: false,
  threadId: null, // null means top-level message
);

// Start a thread/reply
final threadReply = ChatMessageExtended(
  id: 'msg_124',
  branchId: 'branch_1',
  authorId: user2Id,
  authorName: user2Name,
  content: 'Great idea!',
  createdAt: DateTime.now(),
  threadId: 'msg_123', // Linked to parent message
);

// Report inappropriate message
final report = ChatReport(
  id: 'report_1',
  reportedMessageId: 'msg_offensive',
  reportedById: currentUserId,
  reason: 'profanity', // or 'harassment', 'spam', 'off-topic'
  details: 'Very rude language',
  createdAt: DateTime.now(),
);

// Auto-filter profanity
final filtered = ProfanityFilter.filterContent(
  userContent,
  ['customBadword1', 'customBadword2'],
);

// Check if contains profanity
if (ProfanityFilter.containsProfanity(userContent)) {
  // Show warning
}
```

---

## 7. Enhanced Study Materials Search

```dart
// Import advanced study materials
import 'models/study_materials_advanced.dart';

// Perform global FTS search
final query = StudyMaterialsSearchQuery(
  keywords: 'circuit analysis',
  filterByTeacher: ['prof_id_1'],
  filterBySubject: ['Electronics'],
  filterBySemester: [3, 4],
  sortBy: 'relevance',
  bookmarkedOnly: false,
);

final results = await studyMaterialsProvider.searchGlobal(query);

// Access extended file metadata
for (final result in results) {
  print('${result.file.name} (${result.file.displaySize})');
  print('Tags: ${result.file.tags?.join(", ")}');
  print('Last accessed: ${result.file.lastAccessedAt}');
  print('Relevance: ${result.relevanceScore * 100}%');
}

// Access recently opened files
final recent = await studyMaterialsProvider.getRecentFiles();
for (final file in recent) {
  print('${file.fileName} - accessed ${file.accessCount} times');
}

// Bookmark a file
final bookmark = StudyBookmark(
  id: 'bm_1',
  studentId: currentStudentId,
  fileId: file.id,
  bookmarkedAt: DateTime.now(),
  notes: 'Important for exams',
);

await studyMaterialsProvider.bookmarkFile(file.id, notes: 'MyNotes');

// Get all bookmarks
final bookmarks = await studyMaterialsProvider.getBookmarkedFiles();
```

---

## 8. Indoor Navigation with Floor Transitions

```dart
// Store waypoints for multi-stop navigation
// When user reaches destination floor and changes floors
final currentFloor = 2;
const targetFloor = 3;

if (currentFloor != targetFloor) {
  // Show floor transition dialog
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change Floor'),
      content: Text('You reached floor $currentFloor. Moving to floor $targetFloor'),
      actions: [
        TextButton(
          onPressed: () {
            // Recalibrate to new floor
            navigationProvider.recalibrateToFloor(targetFloor);
            Navigator.pop(context);
          },
          child: const Text('Continue'),
        ),
      ],
    ),
  );
}

// Waypoint guidance with voice
for (final waypoint in route.waypoints) {
  print('Go to ${waypoint.roomName} (${waypoint.distance}m)');
  // Text-to-speech or haptic feedback
}
```

---

## 9. Observability & Diagnostics

```dart
// Show diagnostics page for judges/admins
class DiagnosticsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Diagnostics')),
      body: ListView(
        children: [
          // Realtime coordinator stats
          ListTile(
            title: const Text('Active Realtime Channels'),
            subtitle: Text(
              RealtimeCoordinator().getActiveChannels().join(', '),
            ),
          ),
          
          // Action queue stats
          FutureBuilder(
            future: ActionQueueService.getQueueStats(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final stats = snapshot.data as Map<String, dynamic>;
              return ListTile(
                title: const Text('Offline Actions Pending'),
                subtitle: Text('${stats['pending_actions']} queued'),
              );
            },
          ),
          
          // Cache diagnostics
          ListTile(
            title: const Text('Cache Status'),
            subtitle: FutureBuilder(
              future: OfflineCacheService.getLastCacheUpdate(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Never synced');
                return Text('Last sync: ${snapshot.data}');
              },
            ),
          ),
          
          // Feature flags status
          Consumer<FeatureFlagsProvider>(
            builder: (context, flags, _) {
              return ExpansionTile(
                title: const Text('Feature Flags'),
                children: [
                  for (final entry in flags.getFlagStatus().entries)
                    ListTile(
                      title: Text(entry.key),
                      trailing: Text(entry.value ? '✅' : '❌'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
```

---

## Next Steps

1. **Connect to Supabase**: Ensure `SupabaseService` has methods for these features
2. **Test offline**: Toggle WiFi and test action queuing
3. **Monitor realtime**: Check coordinator stats on multiple devices
4. **Rollout features**: Use feature flags to enable/disable for testing
5. **Observe**: Use diagnostics page to track performance

All features are modular and can be toggled independently!
