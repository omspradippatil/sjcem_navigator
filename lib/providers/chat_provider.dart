import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/postgres_service.dart';

class ChatProvider extends ChangeNotifier {
  // Branch chat
  List<ChatMessage> _branchMessages = [];

  // Private messages
  List<PrivateMessage> _privateMessages = [];

  // Available students for chat (conversations)
  List<Student> _conversations = [];

  // Loading states
  bool _isLoadingBranchChat = false;
  bool _isLoadingPrivateChat = false;
  bool _isSending = false;
  String? _error;

  // Current context for reloading
  String? _currentBranchId;
  int? _currentSemester;
  String? _currentConversationUserId;

  List<ChatMessage> get branchMessages => _branchMessages;
  List<PrivateMessage> get privateMessages => _privateMessages;
  List<Student> get conversations => _conversations;
  bool get isLoadingBranchChat => _isLoadingBranchChat;
  bool get isLoadingPrivateChat => _isLoadingPrivateChat;
  bool get isSending => _isSending;
  String? get error => _error;

  // =============================================
  // BRANCH CHAT
  // =============================================

  Future<void> loadBranchMessages({
    required String branchId,
    required int semester,
  }) async {
    _isLoadingBranchChat = true;
    _error = null;
    _currentBranchId = branchId;
    _currentSemester = semester;

    try {
      _branchMessages = await PostgresService.getChatMessages(
        branchId: branchId,
        semester: semester,
      );
      _isLoadingBranchChat = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load messages: ${e.toString()}';
      _isLoadingBranchChat = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> refreshBranchMessages() async {
    if (_currentBranchId != null && _currentSemester != null) {
      try {
        _branchMessages = await PostgresService.getChatMessages(
          branchId: _currentBranchId!,
          semester: _currentSemester!,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error refreshing messages: $e');
      }
    }
  }

  Future<bool> sendBranchMessage({
    required String senderId,
    required String branchId,
    required int semester,
    required String message,
  }) async {
    _isSending = true;
    notifyListeners();

    try {
      final sent = await PostgresService.sendChatMessage(
        senderId: senderId,
        branchId: branchId,
        semester: semester,
        message: message,
      );

      if (sent != null) {
        // Refresh messages to include the new one
        await refreshBranchMessages();
      }

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

  Future<void> loadConversations(String userId) async {
    try {
      _conversations = await PostgresService.getConversations(userId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<void> loadPrivateMessages({
    required String currentUserId,
    required String otherUserId,
  }) async {
    _isLoadingPrivateChat = true;
    _currentConversationUserId = otherUserId;
    _error = null;

    try {
      _privateMessages = await PostgresService.getPrivateMessages(
        senderId: currentUserId,
        receiverId: otherUserId,
      );

      _isLoadingPrivateChat = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load messages: ${e.toString()}';
      _isLoadingPrivateChat = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> refreshPrivateMessages(String currentUserId) async {
    if (_currentConversationUserId != null) {
      try {
        _privateMessages = await PostgresService.getPrivateMessages(
          senderId: currentUserId,
          receiverId: _currentConversationUserId!,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error refreshing private messages: $e');
      }
    }
  }

  Future<bool> sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    _isSending = true;
    notifyListeners();

    try {
      final sent = await PostgresService.sendPrivateMessage(
        senderId: senderId,
        receiverId: receiverId,
        message: message,
      );

      if (sent != null) {
        // Add message to local list immediately
        _privateMessages.add(sent);
      }

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

  void clearPrivateMessages() {
    _privateMessages = [];
    _currentConversationUserId = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
