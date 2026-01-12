import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/constants.dart';

class BranchChatScreen extends StatefulWidget {
  const BranchChatScreen({super.key});

  @override
  State<BranchChatScreen> createState() => _BranchChatScreenState();
}

class _BranchChatScreenState extends State<BranchChatScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  late AnimationController _fadeController;
  late AnimationController _sendButtonController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    _sendButtonController.dispose();
    context.read<ChatProvider>().unsubscribeFromBranchChat();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    final branchId = authProvider.currentBranchId;
    if (branchId != null) {
      await chatProvider.loadBranchMessages(branchId);
      chatProvider.subscribeToBranchChat(branchId);
      _fadeController.forward();
      _scrollToBottom();

      if (chatProvider.error != null && mounted) {
        _showErrorSnackBar(chatProvider.error!);
        chatProvider.clearError();
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    _sendButtonController
        .forward()
        .then((_) => _sendButtonController.reverse());

    final authProvider = context.read<AuthProvider>();
    final chatProvider = context.read<ChatProvider>();

    final branchId = authProvider.currentBranchId;
    if (branchId == null) return;

    final success = await chatProvider.sendBranchMessage(
      branchId: branchId,
      senderId: authProvider.currentUserId!,
      senderType: authProvider.isTeacher
          ? AppConstants.userTypeTeacher
          : AppConstants.userTypeStudent,
      anonymousName: authProvider.anonymousName,
      message: message,
    );

    if (success) {
      _messageController.clear();
      _scrollToBottom();
    } else if (chatProvider.error != null && mounted) {
      _showErrorSnackBar(chatProvider.error!);
      chatProvider.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
      ),
      child: Column(
        children: [
          // Branch Info Header
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A1A2E), const Color(0xFF2D3250)]
                      : [
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.7),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.group, color: Colors.white, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              authProvider.isStudent
                                  ? Icons.visibility_off
                                  : Icons.person,
                              size: 14,
                              color: isDark ? Colors.white60 : Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                authProvider.isStudent
                                    ? 'You appear as: ${authProvider.anonymousName}'
                                    : 'Your name is visible',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (authProvider.isStudent)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Tooltip(
                        message: 'Your identity is anonymous to teachers',
                        child: Icon(
                          Icons.shield,
                          color: Colors.green[400],
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Messages List
          Expanded(
            child: chatProvider.isLoadingBranchChat
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : chatProvider.branchMessages.isEmpty
                    ? FadeTransition(
                        opacity: _fadeAnimation,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0.5, end: 1.0),
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.elasticOut,
                                builder: (context, value, child) =>
                                    Transform.scale(scale: value, child: child),
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [
                                              const Color(0xFF2D3250),
                                              const Color(0xFF424769)
                                            ]
                                          : [
                                              Colors.blue.shade50,
                                              Colors.indigo.shade50
                                            ],
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.grey[600],
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Be the first to say something! 🎉',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: chatProvider.branchMessages.length,
                          itemBuilder: (context, index) {
                            final message = chatProvider.branchMessages[index];
                            final isMe =
                                message.senderId == authProvider.currentUserId;

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(
                                  milliseconds:
                                      200 + (index * 20).clamp(0, 100)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(
                                    (isMe ? 20 : -20) * (1 - value),
                                    0,
                                  ),
                                  child: child,
                                ),
                              ),
                              child: _buildMessageBubble(message, isMe, isDark),
                            );
                          },
                        ),
                      ),
          ),

          // Message Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A2E)
                  : Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                              color:
                                  isDark ? Colors.white38 : Colors.grey[500]),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF2D2D44)
                              : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                        minLines: 1,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedBuilder(
                    animation: _sendButtonController,
                    builder: (context, child) => Transform.scale(
                      scale: 1.0 + (_sendButtonController.value * 0.2),
                      child: child,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        child: IconButton(
                          onPressed:
                              chatProvider.isSending ? null : _sendMessage,
                          icon: chatProvider.isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded,
                                  color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.primary.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : message.isTeacher
                  ? LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF5C4D1F), const Color(0xFF4A3E16)]
                          : [Colors.amber.shade100, Colors.amber.shade50],
                    )
                  : null,
          color: isMe
              ? null
              : message.isTeacher
                  ? null
                  : (isDark ? const Color(0xFF2D2D44) : Colors.grey[100]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: isMe
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                  : message.isTeacher
                      ? Colors.amber.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    message.anonymousName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: isMe
                          ? Colors.white70
                          : message.isTeacher
                              ? (isDark
                                  ? Colors.amber.shade200
                                  : Colors.brown.shade700)
                              : Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (message.isTeacher) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade600, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text(
                          'Teacher',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.message,
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : message.isTeacher
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat.jm().format(message.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? Colors.white60
                    : message.isTeacher
                        ? (isDark
                            ? Colors.amber.shade200.withOpacity(0.7)
                            : Colors.brown.shade400)
                        : (isDark ? Colors.white38 : Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
