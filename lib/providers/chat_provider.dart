import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

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
    notifyListeners();

    try {
      _branchMessages = await SupabaseService.getBranchMessages(branchId);
      _isLoadingBranchChat = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load messages: ${e.toString()}';
      _isLoadingBranchChat = false;
      notifyListeners();
    }
  }

  void subscribeToBranchChat(String branchId) {
    _branchChatChannel?.unsubscribe();
    
    _branchChatChannel = SupabaseService.subscribeToBranchChat(
      branchId,
      (message) {
        _branchMessages.add(message);
        notifyListeners();
      },
    );
  }

  void unsubscribeFromBranchChat() {
    _branchChatChannel?.unsubscribe();
    _branchChatChannel = null;
  }

  Future<bool> sendBranchMessage({
    required String branchId,
    required String senderId,
    required String senderType,
    required String anonymousName,
    required String message,
  }) async {
    _isSending = true;
    notifyListeners();

    try {
      final sent = await SupabaseService.sendBranchMessage(
        branchId: branchId,
        senderId: senderId,
        senderType: senderType,
        anonymousName: anonymousName,
        message: message,
      );
      
      _isSending = false;
      notifyListeners();
      return sent != null;
    } catch (e) {
      _error = 'Failed to send message: ${e.toString()}';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  // =============================================
  // PRIVATE MESSAGES
  // =============================================

  Future<void> loadAvailableStudents(String currentUserId, String? branchId) async {
    try {
      _availableStudents = await SupabaseService.getStudentsForChat(
        currentUserId,
        branchId,
      );
      notifyListeners();
    } catch (e) {
      print('Error loading students: $e');
    }
  }

  Future<void> loadPrivateMessages(String userId1, String userId2) async {
    _isLoadingPrivateChat = true;
    _currentConversationId = userId2;
    _error = null;
    notifyListeners();

    try {
      _privateMessages = await SupabaseService.getPrivateMessages(userId1, userId2);
      
      // Mark messages as read
      await SupabaseService.markMessagesAsRead(userId1, userId2);
      
      _isLoadingPrivateChat = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load messages: ${e.toString()}';
      _isLoadingPrivateChat = false;
      notifyListeners();
    }
  }

  void subscribeToPrivateMessages(String currentUserId) {
    _privateMessageChannel?.unsubscribe();
    
    _privateMessageChannel = SupabaseService.subscribeToPrivateMessages(
      currentUserId,
      (message) {
        // Only add if it's part of current conversation
        if (_currentConversationId != null &&
            (message.senderId == _currentConversationId ||
             message.receiverId == _currentConversationId)) {
          _privateMessages.add(message);
          notifyListeners();
        }
      },
    );
  }

  void unsubscribeFromPrivateMessages() {
    _privateMessageChannel?.unsubscribe();
    _privateMessageChannel = null;
    _currentConversationId = null;
  }

  Future<bool> sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    _isSending = true;
    notifyListeners();

    try {
      final sent = await SupabaseService.sendPrivateMessage(
        senderId: senderId,
        receiverId: receiverId,
        message: message,
      );
      
      _isSending = false;
      notifyListeners();
      return sent != null;
    } catch (e) {
      _error = 'Failed to send message: ${e.toString()}';
      _isSending = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromBranchChat();
    unsubscribeFromPrivateMessages();
    super.dispose();
  }
}
