import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';
import '../../utils/animations.dart';

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

  // For teachers without a branch
  String? _selectedBranchId;
  String? _selectedBranchName;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: AnimationDurations.mediumLong,
      vsync: this,
    );
    _sendButtonController = AnimationController(
      duration: AnimationDurations.short,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: AnimationCurves.emphasizedDecelerate,
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

    // Use selected branch for teachers, or user's branch for students
    String? branchId = authProvider.currentBranchId ?? _selectedBranchId;

    // For teachers without a branch: try to select the first available branch
    if (branchId == null && (authProvider.isTeacher || authProvider.isAdmin)) {
      final branches = authProvider.branches;
      if (branches.isNotEmpty) {
        branchId = branches.first.id;
        _selectedBranchId = branchId;
        _selectedBranchName = branches.first.name;
      }
    }

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

  void _selectBranch(String branchId, String branchName) {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.unsubscribeFromBranchChat();

    setState(() {
      _selectedBranchId = branchId;
      _selectedBranchName = branchName;
    });

    _loadMessages();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    PremiumSnackBar.showError(context, message);
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

    // Use selected branch for teachers without a branch
    final branchId = authProvider.currentBranchId ?? _selectedBranchId;
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
    final authProvider = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.dark,
      ),
      child: Column(
        children: [
          // Premium Branch Info Header
          _buildPremiumHeader(authProvider),

          // Messages List
          Expanded(
            child: chatProvider.branchMessages.isEmpty
                ? _buildEmptyState()
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
                              milliseconds: 200 + (index * 20).clamp(0, 100)),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) => Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset:
                                  Offset((isMe ? 20 : -20) * (1 - value), 0),
                              child: child,
                            ),
                          ),
                          child: _buildPremiumMessageBubble(message, isMe),
                        );
                      },
                    ),
                  ),
          ),

          // Premium Message Input
          _buildPremiumMessageInput(chatProvider),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader(AuthProvider authProvider) {
    // Determine the branch name to display
    String branchName = 'Department Chat';
    if (authProvider.currentBranchId != null) {
      final branch = authProvider.branches.firstWhere(
        (b) => b.id == authProvider.currentBranchId,
        orElse: () => Branch(id: '', name: 'Unknown', code: ''),
      );
      branchName = branch.name;
    } else if (_selectedBranchName != null) {
      branchName = _selectedBranchName!;
    }

    final canSelectBranch = (authProvider.isTeacher || authProvider.isAdmin) &&
        authProvider.currentBranchId == null;

    return TweenAnimationBuilder<double>(
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
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.glassDark,
                  AppColors.glassDark.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.glassBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.primary,
                    boxShadow: [AppShadows.glowPrimary],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardDark.withValues(alpha: 0.8),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: AppColors.textPrimary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Branch name with optional selector
                      if (canSelectBranch)
                        GestureDetector(
                          onTap: () => _showBranchSelectorDialog(authProvider),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppGradients.primary.createShader(bounds),
                                child: Text(
                                  branchName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.swap_horiz,
                                  color: AppColors.accent,
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppGradients.primary.createShader(bounds),
                          child: Text(
                            branchName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              authProvider.currentUserName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBranchSelectorDialog(AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swap_horiz,
                  color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Select Department',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: authProvider.branches.length,
            itemBuilder: (context, index) {
              final branch = authProvider.branches[index];
              final isSelected = _selectedBranchId == branch.id;

              return InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  _selectBranch(branch.id, branch.name);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppGradients.primary : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          branch.code,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.accent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          branch.name,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: Colors.white, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return FadeTransition(
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
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: AppGradients.primarySubtle,
                  shape: BoxShape.circle,
                  boxShadow: [AppShadows.glowPrimary],
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppGradients.primary.createShader(bounds),
                  child: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No messages yet',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Be the first to start the conversation! 🎉',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumMessageInput(ChatProvider chatProvider) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.glassDark,
                AppColors.cardDark.withValues(alpha: 0.9),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              top: BorderSide(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        AppColors.glassDark,
                        AppColors.glassDark.withValues(alpha: 0.5),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.glassBorder,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                      filled: false,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(
                        Icons.edit_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                        size: 20,
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
                child: GestureDetector(
                  onTap: chatProvider.isSending
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          _sendMessage();
                        },
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.primary,
                      boxShadow: [AppShadows.glowPrimary],
                    ),
                    child: Center(
                      child: chatProvider.isSending
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumMessageBubble(ChatMessage message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Sender name outside bubble for received messages
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.anonymousName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: message.isTeacher
                            ? AppColors.warning
                            : AppColors.accent,
                      ),
                    ),
                    if (message.isTeacher) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: AppGradients.warning,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_rounded,
                                size: 10, color: Colors.white),
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
              ),
            // Message bubble
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 6),
                bottomRight: Radius.circular(isMe ? 6 : 20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: isMe ? 0 : 5, sigmaY: isMe ? 0 : 5),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? AppGradients.primary
                        : message.isTeacher
                            ? LinearGradient(
                                colors: [
                                  AppColors.warning.withValues(alpha: 0.2),
                                  AppColors.warning.withValues(alpha: 0.1),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  AppColors.glassDark,
                                  AppColors.glassDark.withValues(alpha: 0.7),
                                ],
                              ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 6),
                      bottomRight: Radius.circular(isMe ? 6 : 20),
                    ),
                    border: isMe
                        ? null
                        : Border.all(
                            color: message.isTeacher
                                ? AppColors.warning.withValues(alpha: 0.3)
                                : AppColors.glassBorder,
                            width: 1,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? AppColors.primaryLight.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.message,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: isMe ? Colors.white60 : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.jm().format(message.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isMe ? Colors.white60 : AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
