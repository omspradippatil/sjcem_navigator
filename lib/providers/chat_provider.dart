import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/action_queue_service.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';

class ChatProvider extends ChangeNotifier {
  // Branch chat
  List<ChatMessage> _branchMessages = [];
  RealtimeChannel? _branchChatChannel;

  // Private messages
  List<PrivateMessage> _privateMessages = [];
  RealtimeChannel? _privateMessageChannel;

  // Available students for chat
  List<Student> _availableStudents = [];

  // Current conversation
  String? _currentConversationId;

  // Loading states
  bool _isLoadingBranchChat = false;
  bool _isLoadingPrivateChat = false;
  bool _isSending = false;
  String? _error;

  List<ChatMessage> get branchMessages => _branchMessages;
  List<PrivateMessage> get privateMessages => _privateMessages;
  List<Student> get availableStudents => _availableStudents;
  bool get isLoadingBranchChat => _isLoadingBranchChat;
  bool get isLoadingPrivateChat => _isLoadingPrivateChat;
  bool get isSending => _isSending;
  String? get error => _error;

  // =============================================
  // BRANCH CHAT
  // =============================================

  Future<void> loadBranchMessages(String branchId) async {
    _isLoadingBranchChat = true;
    _error = null;

    try {
      _branchMessages = await SupabaseService.getBranchMessages(branchId);
      await syncPendingMessages();
      // Cache messages for offline use
      await OfflineCacheService.cacheChatMessages(_branchMessages, branchId);
      _isLoadingBranchChat = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      // Try to load from cache when offline
      debugPrint('Error loading branch messages: $e');
      final cachedMessages =
          await OfflineCacheService.getCachedChatMessages(branchId);
      if (cachedMessages.isNotEmpty) {
        _branchMessages = cachedMessages;
        _error = null;
        debugPrint('Loaded ${cachedMessages.length} messages from cache');
      } else {
        _error = 'Failed to load messages. Please try again.';
      }
      _isLoadingBranchChat = false;
      Future.microtask(() => notifyListeners());
    }
  }

  void subscribeToBranchChat(String branchId) {
    try {
      _branchChatChannel?.unsubscribe();

      _branchChatChannel = SupabaseService.subscribeToBranchChat(
        branchId,
        (message) {
          _branchMessages.add(message);
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to branch chat: $e');
    }
  }

  void unsubscribeFromBranchChat() {
    try {
      _branchChatChannel?.unsubscribe();
      _branchChatChannel = null;
    } catch (e) {
      debugPrint('Error unsubscribing from branch chat: $e');
    }
  }

  Future<bool> sendBranchMessage({
    required String branchId,
    required String senderId,
    required String senderType,
    required String anonymousName,
    required String message,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final sent = await SupabaseService.sendBranchMessage(
        branchId: branchId,
        senderId: senderId,
        senderType: senderType,
        anonymousName: anonymousName,
        message: message,
      );

      if (sent == null) {
        final isOnline = await OfflineCacheService.checkConnectivity();
        if (!isOnline) {
          await ActionQueueService.queueAction(
            actionType: ActionQueueService.actionMessage,
            targetId: branchId,
            payload: {
              'branch_id': branchId,
              'sender_id': senderId,
              'sender_type': senderType,
              'anonymous_name': anonymousName,
              'message': message,
            },
            groupId: branchId,
          );

          _branchMessages.add(ChatMessage(
            id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
            branchId: branchId,
            senderId: senderId,
            senderType: senderType,
            anonymousName: anonymousName,
            message: message,
            createdAt: DateTime.now(),
          ));

          _isSending = false;
          notifyListeners();
          return true;
        }
      }

      _isSending = false;
      if (sent == null) {
        _error = 'Failed to send message. Please try again.';
      }
      notifyListeners();
      return sent != null;
    } catch (e) {
      _error = 'Failed to send message. Please check your connection.';
      _isSending = false;
      debugPrint('Error sending branch message: $e');
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // PRIVATE MESSAGES
  // =============================================

  Future<void> loadAvailableStudents(
      String currentUserId, String? branchId) async {
    try {
      _availableStudents = await SupabaseService.getStudentsForChat(
        currentUserId,
        branchId,
      );
      // Silent update - no notifications during load
    } catch (e) {
      debugPrint('Error loading students: $e');
    }
  }

  Future<void> loadPrivateMessages(String userId1, String userId2) async {
    _isLoadingPrivateChat = true;
    _currentConversationId = userId2;
    _error = null;

    try {
      _privateMessages =
          await SupabaseService.getPrivateMessages(userId1, userId2);

        await syncPendingMessages();

      // Mark messages as read
      await SupabaseService.markMessagesAsRead(userId1, userId2);

      _isLoadingPrivateChat = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load messages. Please try again.';
      _isLoadingPrivateChat = false;
      debugPrint('Error loading private messages: $e');
      Future.microtask(() => notifyListeners());
    }
  }

  void subscribeToPrivateMessages(String currentUserId) {
    try {
      _privateMessageChannel?.unsubscribe();

      _privateMessageChannel = SupabaseService.subscribeToPrivateMessages(
        currentUserId,
        (message) {
          // Only add if it's part of current conversation and not a duplicate
          if (_currentConversationId != null &&
              (message.senderId == _currentConversationId ||
                  message.receiverId == _currentConversationId)) {
            // Check if message already exists to prevent duplicates
            final alreadyExists =
                _privateMessages.any((m) => m.id == message.id);
            if (!alreadyExists) {
              _privateMessages.add(message);
              notifyListeners();
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to private messages: $e');
    }
  }

  void unsubscribeFromPrivateMessages() {
    try {
      _privateMessageChannel?.unsubscribe();
      _privateMessageChannel = null;
      _currentConversationId = null;
    } catch (e) {
      debugPrint('Error unsubscribing from private messages: $e');
    }
  }

  Future<bool> sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    _isSending = true;
    _error = null;
    notifyListeners();

    try {
      final sent = await SupabaseService.sendPrivateMessage(
        senderId: senderId,
        receiverId: receiverId,
        message: message,
      );

      if (sent == null) {
        final isOnline = await OfflineCacheService.checkConnectivity();
        if (!isOnline) {
          await ActionQueueService.queueAction(
            actionType: ActionQueueService.actionPrivateMessage,
            targetId: receiverId,
            payload: {
              'sender_id': senderId,
              'receiver_id': receiverId,
              'message': message,
            },
            groupId: receiverId,
          );

          _privateMessages.add(PrivateMessage(
            id: 'offline_${DateTime.now().millisecondsSinceEpoch}',
            senderId: senderId,
            receiverId: receiverId,
            message: message,
            createdAt: DateTime.now(),
            isRead: true,
          ));

          _isSending = false;
          notifyListeners();
          return true;
        }
      }

      _isSending = false;
      if (sent == null) {
        _error = 'Failed to send message. Please try again.';
      }
      notifyListeners();
      return sent != null;
    } catch (e) {
      _error = 'Failed to send message. Please check your connection.';
      _isSending = false;
      debugPrint('Error sending private message: $e');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> syncPendingMessages() async {
    try {
      final isOnline = await OfflineCacheService.checkConnectivity();
      if (!isOnline) return;

      final pending = await ActionQueueService.getPendingActions();
      for (final action in pending) {
        if (action.actionType == ActionQueueService.actionMessage) {
          final payload = action.payload;
          final sent = await SupabaseService.sendBranchMessage(
            branchId: payload['branch_id'] as String? ?? '',
            senderId: payload['sender_id'] as String? ?? '',
            senderType: payload['sender_type'] as String? ?? 'student',
            anonymousName: payload['anonymous_name'] as String? ?? 'Anonymous',
            message: payload['message'] as String? ?? '',
          );
          if (sent != null) {
            await ActionQueueService.markActionSynced(action.id);
          }
        } else if (action.actionType ==
            ActionQueueService.actionPrivateMessage) {
          final payload = action.payload;
          final sent = await SupabaseService.sendPrivateMessage(
            senderId: payload['sender_id'] as String? ?? '',
            receiverId: payload['receiver_id'] as String? ?? '',
            message: payload['message'] as String? ?? '',
          );
          if (sent != null) {
            await ActionQueueService.markActionSynced(action.id);
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing pending messages: $e');
    }
  }

  @override
  void dispose() {
    unsubscribeFromBranchChat();
    unsubscribeFromPrivateMessages();
    super.dispose();
  }
}
