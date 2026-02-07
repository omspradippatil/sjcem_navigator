import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  void _handleNewChatMessage(Map<String, dynamic> data) {
    // Don't notify for own messages
    if (data['sender_id'] == _currentUserId) return;

    final senderName = data['anonymous_name'] ?? 'Someone';
    final message = data['message'] ?? '';

    debugPrint('🔔 Showing chat notification from $senderName: $message');

    showChatNotification(
      senderName: senderName,
      message: message,
      branchName: 'Branch Chat',
      extraData: {'message_id': data['id']},
    );
  }

  void _handleNewPrivateMessage(Map<String, dynamic> data) {
    // Don't notify for own messages
    if (data['sender_id'] == _currentUserId) return;

    final message = data['message'] ?? '';

    debugPrint('🔔 Showing private message notification');

    showPrivateMessageNotification(
      senderName: 'New Message',
      message: message,
      extraData: {'message_id': data['id'], 'sender_id': data['sender_id']},
    );
  }

  void _handleNewFile(Map<String, dynamic> data) {
    final fileName = data['name'] ?? 'New file';

    debugPrint('🔔 Showing file notification: $fileName');

    showFileUploadNotification(
      teacherName: 'Teacher',
      fileName: fileName,
      folderName: 'Study Materials',
      extraData: {'file_id': data['id']},
    );
  }

  void _handleNewPoll(Map<String, dynamic> data) {
    final pollTitle = data['title'] ?? 'New Poll';

    debugPrint('🔔 Showing poll notification: $pollTitle');

    showPollNotification(
      pollTitle: pollTitle,
      creatorName: 'Teacher',
      extraData: {'poll_id': data['id']},
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String channelId = _generalChannelId,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == _chatChannelId
          ? _chatChannelName
          : channelId == _fileChannelId
              ? _fileChannelName
              : _generalChannelName,
      channelDescription: channelId == _chatChannelId
          ? _chatChannelDesc
          : channelId == _fileChannelId
              ? _fileChannelDesc
              : _generalChannelDesc,
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

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
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
  Future<void> showTestNotification() async {
    debugPrint('🔔 Showing test notification');
    await _showLocalNotification(
      title: 'Test Notification',
      body: 'If you see this, notifications are working!',
      channelId: _generalChannelId,
    );
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
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
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
  }

  /// Get notification preference
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notifications_enabled') ?? true;
  }

  /// Dispose resources
  void dispose() {
    stopRealtimeListeners();
  }
}
