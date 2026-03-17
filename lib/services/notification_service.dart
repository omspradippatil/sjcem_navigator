import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/timetable_entry.dart';

/// Notification Service using Supabase Realtime + Local Notifications
/// No Firebase required!
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;

  // Realtime channels
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _filesChannel;
  RealtimeChannel? _pollsChannel;
  RealtimeChannel? _privateMessagesChannel;

  // Lecture notification timers
  final Map<String, Timer> _lectureTimers = {};

  // Notification channels (Android)
  static const String _chatChannelId = 'chat_notifications';
  static const String _chatChannelName = 'Chat Notifications';
  static const String _chatChannelDesc = 'Notifications for new chat messages';

  static const String _fileChannelId = 'file_notifications';
  static const String _fileChannelName = 'Study Materials';
  static const String _fileChannelDesc =
      'Notifications when teachers upload files';

  static const String _generalChannelId = 'general_notifications';
  static const String _generalChannelName = 'General';
  static const String _generalChannelDesc = 'General app notifications';

  static const String _lectureChannelId = 'lecture_notifications';
  static const String _lectureChannelName = 'Lecture Reminders';
  static const String _lectureChannelDesc =
      'Notifications for upcoming lectures';

  bool _isInitialized = false;
  String? _currentUserId;

  // Callback for navigation
  Function(String type, Map<String, dynamic> data)? onNotificationTap;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      _isInitialized = true;
      debugPrint('🔔 NotificationService initialized (Supabase Realtime)');
    } catch (e) {
      debugPrint('❌ NotificationService initialization error: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      // Request notification permission (Android 13+)
      await androidPlugin?.requestNotificationsPermission();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _chatChannelId,
          _chatChannelName,
          description: _chatChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _fileChannelId,
          _fileChannelName,
          description: _fileChannelDesc,
          importance: Importance.high,
          playSound: true,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _generalChannelId,
          _generalChannelName,
          description: _generalChannelDesc,
          importance: Importance.defaultImportance,
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _lectureChannelId,
          _lectureChannelName,
          description: _lectureChannelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final type = data['type'] as String? ?? 'general';
        onNotificationTap?.call(type, data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Start listening for realtime updates
  Future<void> startRealtimeListeners({
    required String userId,
    required String branchId,
    String? userType,
  }) async {
    _currentUserId = userId;

    // Stop existing listeners
    await stopRealtimeListeners();

    debugPrint(
        '🔔 Starting realtime listeners for user: $userId, branch: $branchId');

    try {
      // Listen for new chat messages in the branch
      _chatChannel = _supabase
          .channel('chat_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'branch_chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) {
              debugPrint('🔔 New chat message received: ${payload.newRecord}');
              _handleNewChatMessage(payload.newRecord);
            },
          )
          .subscribe((status, [error]) {
        debugPrint('🔔 Chat channel status: $status, error: $error');
      });

      // Listen for new study files
      _filesChannel = _supabase
          .channel('files_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'study_files',
            callback: (payload) {
              debugPrint('🔔 New file uploaded: ${payload.newRecord}');
              _handleNewFile(payload.newRecord);
            },
          )
          .subscribe((status, [error]) {
        debugPrint('🔔 Files channel status: $status, error: $error');
      });

      // Listen for new polls
      _pollsChannel = _supabase
          .channel('polls_$branchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'polls',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'branch_id',
              value: branchId,
            ),
            callback: (payload) {
              debugPrint('🔔 New poll created: ${payload.newRecord}');
              _handleNewPoll(payload.newRecord);
            },
          )
          .subscribe((status, [error]) {
        debugPrint('🔔 Polls channel status: $status, error: $error');
      });

      // Also listen for private messages
      _privateMessagesChannel = _supabase
          .channel('private_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'private_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'receiver_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint('🔔 New private message: ${payload.newRecord}');
              _handleNewPrivateMessage(payload.newRecord);
            },
          )
          .subscribe((status, [error]) {
        debugPrint(
            '🔔 Private messages channel status: $status, error: $error');
      });

      debugPrint('🔔 Realtime listeners started for branch: $branchId');
    } catch (e) {
      debugPrint('❌ Error starting realtime listeners: $e');
    }
  }

  /// Stop all realtime listeners
  Future<void> stopRealtimeListeners() async {
    await _chatChannel?.unsubscribe();
    await _filesChannel?.unsubscribe();
    await _pollsChannel?.unsubscribe();
    await _privateMessagesChannel?.unsubscribe();
    _chatChannel = null;
    _filesChannel = null;
    _pollsChannel = null;
    _privateMessagesChannel = null;
    debugPrint('🔔 Realtime listeners stopped');
  }

  Future<void> _handleNewChatMessage(Map<String, dynamic> data) async {
    try {
      // Don't notify for own messages
      if (data['sender_id'] == _currentUserId) return;

      final senderName = data['anonymous_name'] ?? 'Someone';
      final message = data['message'] ?? '';

      debugPrint('🔔 Handling chat notification from $senderName: $message');

      await showChatNotification(
        senderName: senderName,
        message: message,
        branchName: 'Branch Chat',
        extraData: {'message_id': data['id']},
      );
    } catch (e) {
      debugPrint('❌ Error handling chat message notification: $e');
    }
  }

  Future<void> _handleNewPrivateMessage(Map<String, dynamic> data) async {
    try {
      // Don't notify for own messages
      if (data['sender_id'] == _currentUserId) return;

      final message = data['message'] ?? '';

      debugPrint('🔔 Handling private message notification');

      await showPrivateMessageNotification(
        senderName: 'New Message',
        message: message,
        extraData: {'message_id': data['id'], 'sender_id': data['sender_id']},
      );
    } catch (e) {
      debugPrint('❌ Error handling private message notification: $e');
    }
  }

  Future<void> _handleNewFile(Map<String, dynamic> data) async {
    try {
      final fileName = data['name'] ?? 'New file';

      debugPrint('🔔 Handling file notification: $fileName');

      await showFileUploadNotification(
        teacherName: 'Teacher',
        fileName: fileName,
        folderName: 'Study Materials',
        extraData: {'file_id': data['id']},
      );
    } catch (e) {
      debugPrint('❌ Error handling file notification: $e');
    }
  }

  Future<void> _handleNewPoll(Map<String, dynamic> data) async {
    try {
      final pollTitle = data['title'] ?? 'New Poll';

      debugPrint('🔔 Handling poll notification: $pollTitle');

      await showPollNotification(
        pollTitle: pollTitle,
        creatorName: 'Teacher',
        extraData: {'poll_id': data['id']},
      );
    } catch (e) {
      debugPrint('❌ Error handling poll notification: $e');
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _generalChannelId,
    bool bypassEnabledCheck = false,
  }) async {
    try {
      // Check if notifications are enabled (unless bypassed for test notifications)
      if (!bypassEnabledCheck) {
        final prefsEnabled = await getNotificationsEnabled();
        if (!prefsEnabled) {
          debugPrint('🔕 Notification skipped - disabled in preferences');
          return;
        }

        // Also check system permission
        final systemEnabled = await areNotificationsEnabled();
        if (!systemEnabled) {
          debugPrint('🔕 Notification skipped - system permission denied');
          return;
        }
      }

      // Get proper channel name for lecture notifications
      String channelName;
      String channelDescription;

      switch (channelId) {
        case _chatChannelId:
          channelName = _chatChannelName;
          channelDescription = _chatChannelDesc;
          break;
        case _fileChannelId:
          channelName = _fileChannelName;
          channelDescription = _fileChannelDesc;
          break;
        case _lectureChannelId:
          channelName = _lectureChannelName;
          channelDescription = _lectureChannelDesc;
          break;
        default:
          channelName = _generalChannelName;
          channelDescription = _generalChannelDesc;
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      debugPrint('🔔 Showing notification #$notificationId: $title');

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      debugPrint('✅ Notification shown successfully');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  // =============================================
  // PUBLIC METHODS
  // =============================================

  /// Show chat message notification
  Future<void> showChatNotification({
    required String senderName,
    required String message,
    required String branchName,
    Map<String, dynamic>? extraData,
  }) async {
    await _showLocalNotification(
      title: '$senderName in $branchName',
      body: message,
      payload: jsonEncode({
        'type': 'chat',
        'branch': branchName,
        ...?extraData,
      }),
      channelId: _chatChannelId,
    );
  }

  /// Show private message notification
  Future<void> showPrivateMessageNotification({
    required String senderName,
    required String message,
    Map<String, dynamic>? extraData,
  }) async {
    await _showLocalNotification(
      title: senderName,
      body: message,
      payload: jsonEncode({
        'type': 'private_message',
        ...?extraData,
      }),
      channelId: _chatChannelId,
    );
  }

  /// Show file upload notification
  Future<void> showFileUploadNotification({
    required String teacherName,
    required String fileName,
    required String folderName,
    Map<String, dynamic>? extraData,
  }) async {
    await _showLocalNotification(
      title: 'New Study Material 📚',
      body: '$teacherName uploaded "$fileName" in $folderName',
      payload: jsonEncode({
        'type': 'file',
        'folder': folderName,
        ...?extraData,
      }),
      channelId: _fileChannelId,
    );
  }

  /// Show poll notification
  Future<void> showPollNotification({
    required String pollTitle,
    required String creatorName,
    Map<String, dynamic>? extraData,
  }) async {
    await _showLocalNotification(
      title: 'New Poll 📊',
      body: '$creatorName created a poll: "$pollTitle"',
      payload: jsonEncode({
        'type': 'poll',
        ...?extraData,
      }),
      channelId: _generalChannelId,
    );
  }

  /// Show general notification
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _showLocalNotification(
      title: title,
      body: body,
      payload: data != null ? jsonEncode(data) : null,
      channelId: _generalChannelId,
    );
  }

  /// Test notification - call this to verify notifications are working
  /// Bypasses enabled checks to always show if system allows
  Future<bool> showTestNotification() async {
    debugPrint('🔔 Attempting to show test notification');

    // First check system permission
    final systemEnabled = await areNotificationsEnabled();
    debugPrint('🔔 System notifications enabled: $systemEnabled');

    if (!systemEnabled) {
      debugPrint('❌ System notifications are disabled - requesting permission');
      final granted = await requestPermission();
      if (!granted) {
        debugPrint('❌ Permission not granted');
        return false;
      }
    }

    await _showLocalNotification(
      title: 'Test Notification ✅',
      body: 'If you see this, notifications are working!',
      channelId: _generalChannelId,
      bypassEnabledCheck: true, // Always show test notification
    );
    return true;
  }

  /// Get notification status for debugging
  Future<Map<String, dynamic>> getNotificationStatus() async {
    final systemEnabled = await areNotificationsEnabled();
    final prefsEnabled = await getNotificationsEnabled();
    final lectureEnabled = await getLectureNotificationsEnabled();

    return {
      'initialized': _isInitialized,
      'systemPermission': systemEnabled,
      'preferencesEnabled': prefsEnabled,
      'lectureNotificationsEnabled': lectureEnabled,
      'currentUserId': _currentUserId,
      'chatChannelActive': _chatChannel != null,
      'filesChannelActive': _filesChannel != null,
      'pollsChannelActive': _pollsChannel != null,
      'privateMessagesChannelActive': _privateMessagesChannel != null,
      'scheduledLectureTimers': _lectureTimers.length,
    };
  }

  /// Ensure notifications are properly set up - call after login
  Future<bool> ensureNotificationsEnabled() async {
    // Check and request permission if needed
    var systemEnabled = await areNotificationsEnabled();
    if (!systemEnabled) {
      debugPrint('🔔 Requesting notification permission...');
      systemEnabled = await requestPermission();
    }

    // Reinitialize if not initialized
    if (!_isInitialized) {
      debugPrint('🔔 Re-initializing notification service...');
      await initialize();
    }

    debugPrint(
        '🔔 Notification status: system=$systemEnabled, initialized=$_isInitialized');
    return systemEnabled && _isInitialized;
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS handles this differently
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final result =
          await androidPlugin?.requestNotificationsPermission() ?? false;
      debugPrint('🔔 Android permission request result: $result');
      return result;
    } else if (Platform.isIOS) {
      final iosPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final result = await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      debugPrint('🔔 iOS permission request result: $result');
      return result;
    }
    return false;
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Save notification preferences
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    debugPrint('🔔 Notifications enabled preference set to: $enabled');
  }

  /// Get notification preference
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  // =============================================
  // LECTURE NOTIFICATIONS
  // =============================================

  /// Schedule notifications for today's upcoming lectures
  /// Call this when timetable is loaded
  Future<void> scheduleLectureNotifications(List<TimetableEntry> todayTimetable,
      {int minutesBefore = 5}) async {
    // Cancel existing lecture timers
    cancelAllLectureTimers();

    final now = DateTime.now();
    debugPrint(
        '🔔 Scheduling notifications for ${todayTimetable.length} timetable entries');

    for (final entry in todayTimetable) {
      // Skip breaks
      if (entry.isBreak) continue;

      // Calculate notification time (X minutes before start)
      final notifyTime =
          entry.startDateTime.subtract(Duration(minutes: minutesBefore));

      // Only schedule if notification time is in the future
      if (notifyTime.isAfter(now)) {
        final delay = notifyTime.difference(now);

        debugPrint(
            '🔔 Scheduling "${entry.displayName}" notification in ${delay.inMinutes} minutes');

        // Create a timer to show notification at the right time
        _lectureTimers[entry.id] = Timer(delay, () {
          _showLectureNotification(entry, minutesBefore);
        });
      }
    }

    debugPrint('🔔 Scheduled ${_lectureTimers.length} lecture notifications');
  }

  /// Show a lecture notification
  Future<void> _showLectureNotification(
      TimetableEntry entry, int minutesBefore) async {
    final subjectName = entry.displayName;
    final roomName = entry.room?.effectiveName ?? entry.room?.name ?? 'TBA';
    final teacherName = entry.teacher?.name ?? '';
    final time = entry.formattedTime;
    final batchInfo = entry.batch != null ? ' (${entry.batch})' : '';

    String title;
    String body;

    if (minutesBefore <= 0) {
      title = '📚 Class Starting Now!';
      body = '$subjectName$batchInfo\n📍 $roomName • $time';
    } else {
      title = '📚 Class in $minutesBefore minutes';
      body = '$subjectName$batchInfo\n📍 $roomName';
    }

    if (teacherName.isNotEmpty) {
      body += '\n👨‍🏫 $teacherName';
    }

    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': 'lecture',
        'entry_id': entry.id,
        'subject': subjectName,
        'room': roomName,
      }),
      channelId: _lectureChannelId,
    );
  }

  /// Show immediate notification about next lecture
  Future<void> showNextLectureNotification(TimetableEntry? nextLecture) async {
    if (nextLecture == null || nextLecture.isBreak) return;

    final timeUntilStart = nextLecture.timeUntilStart;
    if (timeUntilStart.isNegative) return;

    final subjectName = nextLecture.displayName;
    final roomName =
        nextLecture.room?.effectiveName ?? nextLecture.room?.name ?? 'TBA';
    final time = nextLecture.formattedTime;
    final batchInfo =
        nextLecture.batch != null ? ' (${nextLecture.batch})' : '';

    final minutesUntil = timeUntilStart.inMinutes;

    await _showLocalNotification(
      title: '📚 Next: $subjectName$batchInfo',
      body: '📍 $roomName • $time\nStarts in $minutesUntil minutes',
      payload: jsonEncode({
        'type': 'next_lecture',
        'entry_id': nextLecture.id,
        'subject': subjectName,
        'room': roomName,
      }),
      channelId: _lectureChannelId,
    );
  }

  /// Show current lecture notification
  Future<void> showCurrentLectureNotification(
      TimetableEntry? currentLecture) async {
    if (currentLecture == null || currentLecture.isBreak) return;

    final subjectName = currentLecture.displayName;
    final roomName = currentLecture.room?.effectiveName ??
        currentLecture.room?.name ??
        'TBA';
    final timeRemaining = currentLecture.timeRemaining;
    final batchInfo =
        currentLecture.batch != null ? ' (${currentLecture.batch})' : '';

    await _showLocalNotification(
      title: '📚 Current: $subjectName$batchInfo',
      body: '📍 $roomName\n⏱️ ${timeRemaining.inMinutes} minutes remaining',
      payload: jsonEncode({
        'type': 'current_lecture',
        'entry_id': currentLecture.id,
        'subject': subjectName,
        'room': roomName,
      }),
      channelId: _lectureChannelId,
    );
  }

  /// Cancel all scheduled lecture timers
  void cancelAllLectureTimers() {
    for (final timer in _lectureTimers.values) {
      timer.cancel();
    }
    _lectureTimers.clear();
    debugPrint('🔔 Cancelled all lecture notification timers');
  }

  /// Cancel a specific lecture notification
  Future<void> cancelLectureNotification(String entryId) async {
    _lectureTimers[entryId]?.cancel();
    _lectureTimers.remove(entryId);
  }

  /// Get/set lecture notification preference
  Future<void> setLectureNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lecture_notifications_enabled', enabled);
    if (!enabled) {
      cancelAllLectureTimers();
    }
  }

  Future<bool> getLectureNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('lecture_notifications_enabled') ?? true;
  }

  /// Get/set minutes before notification preference
  Future<void> setLectureNotificationMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lecture_notification_minutes', minutes);
  }

  Future<int> getLectureNotificationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('lecture_notification_minutes') ?? 5;
  }

  // =============================================
  // ONE SIGNAL — BACKGROUND PUSH NOTIFICATIONS
  // =============================================

  /// Initialize OneSignal SDK. Call once at app startup after dotenv is loaded.
  Future<void> initializeOneSignal(String appId) async {
    if (appId.isEmpty) {
      debugPrint('⚠️ OneSignal: no ONESIGNAL_APP_ID configured — skipping init');
      return;
    }
    try {
      OneSignal.Debug.setLogLevel(OSLogLevel.warn);
      OneSignal.initialize(appId);
      // Request permission (Android 13+ / iOS)
      await OneSignal.Notifications.requestPermission(true);
      debugPrint('🔔 OneSignal initialized (appId: ${appId.substring(0, 8)}…)');
    } catch (e) {
      debugPrint('❌ OneSignal init error: $e');
    }
  }

  /// Save this device's OneSignal player_id to Supabase so GitHub Actions
  /// can target it when sending push notifications.
  Future<void> registerDeviceToken({
    required String userId,
    required String userType, // 'student' or 'teacher'
    required String branchId,
  }) async {
    try {
      // Wait up to 10 seconds for OneSignal to obtain the push subscription ID from FCM
      int retries = 0;
      String? playerId;
      while (retries < 10) {
        playerId = OneSignal.User.pushSubscription.id;
        if (playerId != null && playerId.isNotEmpty) break;
        await Future.delayed(const Duration(seconds: 1));
        retries++;
      }

      if (playerId == null || playerId.isEmpty) {
        debugPrint('⚠️ OneSignal: no player_id obtained from FCM after 10s — token registration skipped');
        return;
      }
      
      debugPrint('🔔 Registering OneSignal player_id: ${playerId.substring(0, 8)}…');
      await Supabase.instance.client.from('device_tokens').upsert({
        'user_id': userId,
        'user_type': userType,
        'branch_id': branchId,
        'player_id': playerId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
      debugPrint('✅ OneSignal token saved to Supabase');
    } catch (e) {
      debugPrint('❌ OneSignal token registration error: $e');
    }
  }

  /// Remove device token from Supabase on logout so we stop sending pushes
  /// to logged-out users.
  Future<void> removeDeviceToken(String userId) async {
    try {
      await Supabase.instance.client
          .from('device_tokens')
          .delete()
          .eq('user_id', userId);
      debugPrint('🔔 OneSignal token removed from Supabase');
    } catch (e) {
      debugPrint('❌ OneSignal token removal error: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    cancelAllLectureTimers();
    stopRealtimeListeners();
  }
}
