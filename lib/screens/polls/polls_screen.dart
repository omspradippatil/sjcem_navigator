import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/poll_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/animations.dart';
import 'create_poll_screen.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPolls();
  }

  @override
  void dispose() {
    _tabController.dispose();
    try {
      context.read<PollProvider>().unsubscribeFromAllPolls();
    } catch (e) {
      debugPrint('Error in dispose: $e');
    }
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    PremiumSnackBar.showError(context, message);
  }

  Future<void> _loadPolls() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final pollProvider = context.read<PollProvider>();

      await pollProvider.loadPolls(
        branchId: authProvider.currentBranchId,
        activeOnly: false, // Load all polls
      );

      // Show error if loading failed
      if (pollProvider.error != null && mounted) {
        _showErrorSnackBar(pollProvider.error!);
        pollProvider.clearError();
        return;
      }

      // Check vote status for students
      if (authProvider.isStudent && authProvider.currentUserId != null) {
        await pollProvider.checkAllVoteStatus(authProvider.currentUserId!);
      }

      // Subscribe to poll updates
      for (final poll in pollProvider.polls) {
        pollProvider.subscribeToPoll(poll.id);
      }
    } catch (e) {
      debugPrint('Error loading polls: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load polls. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final pollProvider = context.watch<PollProvider>();

    // Separate active and ended polls
    final activePolls = pollProvider.polls.where((p) => p.isActive).toList();
    final endedPolls = pollProvider.polls.where((p) => !p.isActive).toList();

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.dark,
          ),
          child: Column(
            children: [
              // Tab bar header
              _buildPremiumTabBarHeader(activePolls.length, endedPolls.length),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPollList(activePolls, authProvider, pollProvider,
                        isActive: true),
                    _buildPollList(endedPolls, authProvider, pollProvider,
                        isActive: false),
                  ],
                ),
              ),
            ],
          ),
        ),
        // FAB positioned at bottom right
        if (authProvider.isTeacher || authProvider.isHod)
          Positioned(
            right: 16,
            bottom: 16,
            child: _buildPremiumFAB(),
          ),
      ],
    );
  }

  Widget _buildPremiumTabBarHeader(int activeCount, int endedCount) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.glassDark,
                AppColors.glassDark.withValues(alpha: 0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
          ),
          child: _buildPremiumTabBar(activeCount, endedCount),
        ),
      ),
    );
  }

  Widget _buildPremiumTabBar(int activeCount, int endedCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 45,
      decoration: BoxDecoration(
        color: AppColors.glassDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [AppShadows.glowPrimary],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.how_to_vote_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Active ($activeCount)'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_rounded, size: 18),
                const SizedBox(width: 6),
                Text('Past ($endedCount)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFAB() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        _navigateToCreatePoll();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [AppShadows.glowPrimary],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Create Poll',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollList(
    List<Poll> polls,
    AuthProvider authProvider,
    PollProvider pollProvider, {
    required bool isActive,
  }) {
    if (pollProvider.isLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            gradient: AppGradients.primarySubtle,
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (polls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: isActive
                      ? AppGradients.primarySubtle
                      : AppGradients.secondarySubtle,
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (isActive) AppShadows.glowPrimary,
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      (isActive ? AppGradients.primary : AppGradients.secondary)
                          .createShader(bounds),
                  child: Icon(
                    isActive ? Icons.poll_outlined : Icons.history_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isActive ? 'No active polls' : 'No past polls',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Check back later for new polls'
                  : 'Completed polls will appear here',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPolls,
      color: AppColors.accent,
      backgroundColor: AppColors.cardDark,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: polls.length,
        itemBuilder: (context, index) {
          final poll = polls[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 200 + (index * 30)),
            curve: Curves.easeOut,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 15 * (1 - value)),
                child: child,
              ),
            ),
            child: _buildPremiumPollCard(poll, authProvider, pollProvider),
          );
        },
      ),
    );
  }

  void _navigateToCreatePoll() {
    Navigator.of(context).push(
      SlidePageRoute(
        page: const CreatePollScreen(),
        direction: SlideDirection.up,
      ),
    );
  }

  Widget _buildPremiumPollCard(
    Poll poll,
    AuthProvider authProvider,
    PollProvider pollProvider,
  ) {
    final hasVoted = pollProvider.hasVoted(poll.id);
    final votedOptionId = pollProvider.getVotedOption(poll.id);
    final totalVotes = poll.totalVotes;

    // Find winning option
    PollOption? winningOption;
    if (totalVotes > 0) {
      winningOption = poll.options.reduce(
        (a, b) => a.voteCount > b.voteCount ? a : b,
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: poll.isActive
                    ? [
                        AppColors.primaryLight.withValues(alpha: 0.1),
                        AppColors.glassDark,
                      ]
                    : [
                        AppColors.glassDark,
                        AppColors.glassDark.withValues(alpha: 0.7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: poll.isActive
                    ? AppColors.primaryLight.withValues(alpha: 0.3)
                    : AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Poll Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: poll.isActive
                          ? [
                              AppColors.primaryLight.withValues(alpha: 0.15),
                              Colors.transparent,
                            ]
                          : [
                              AppColors.glassDark.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: poll.isActive
                                  ? AppGradients.primary
                                  : AppGradients.secondary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: poll.isActive
                                  ? [AppShadows.glowPrimary]
                                  : null,
                            ),
                            child: const Icon(
                              Icons.poll_rounded,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              poll.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildPremiumStatusBadge(poll),
                        ],
                      ),
                      if (poll.description != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          poll.description!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Poll Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: poll.options.map((option) {
                      final percentage = option.getPercentage(totalVotes);
                      final isVotedOption = votedOptionId == option.id;
                      final isWinning =
                          option.id == winningOption?.id && totalVotes > 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: (authProvider.isStudent &&
                                    !hasVoted &&
                                    poll.isActive)
                                ? () {
                                    HapticFeedback.lightImpact();
                                    _vote(poll.id, option.id);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: isVotedOption
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primaryLight
                                              .withValues(alpha: 0.2),
                                          AppColors.primaryLight
                                              .withValues(alpha: 0.1),
                                        ],
                                      )
                                    : isWinning && !poll.isActive
                                        ? LinearGradient(
                                            colors: [
                                              AppColors.success
                                                  .withValues(alpha: 0.2),
                                              AppColors.success
                                                  .withValues(alpha: 0.1),
                                            ],
                                          )
                                        : null,
                                border: Border.all(
                                  color: isVotedOption
                                      ? AppColors.primaryLight
                                          .withValues(alpha: 0.5)
                                      : isWinning && !poll.isActive
                                          ? AppColors.success
                                              .withValues(alpha: 0.5)
                                          : AppColors.glassBorder,
                                  width: isVotedOption ||
                                          (isWinning && !poll.isActive)
                                      ? 2
                                      : 1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Stack(
                                children: [
                                  // Progress background
                                  if (hasVoted ||
                                      authProvider.isTeacher ||
                                      !poll.isActive)
                                    Positioned.fill(
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: percentage / 100,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isVotedOption
                                                  ? [
                                                      AppColors.primaryLight
                                                          .withValues(
                                                              alpha: 0.3),
                                                      AppColors.primaryLight
                                                          .withValues(
                                                              alpha: 0.1),
                                                    ]
                                                  : isWinning && !poll.isActive
                                                      ? [
                                                          AppColors.success
                                                              .withValues(
                                                                  alpha: 0.3),
                                                          AppColors.success
                                                              .withValues(
                                                                  alpha: 0.1),
                                                        ]
                                                      : [
                                                          AppColors.textMuted
                                                              .withValues(
                                                                  alpha: 0.2),
                                                          AppColors.textMuted
                                                              .withValues(
                                                                  alpha: 0.05),
                                                        ],
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Option content
                                  Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        if (isVotedOption)
                                          Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              gradient: AppGradients.success,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check_rounded,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                          )
                                        else if (!hasVoted &&
                                            authProvider.isStudent &&
                                            poll.isActive)
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.textMuted,
                                                width: 2,
                                              ),
                                            ),
                                          )
                                        else if (isWinning && !poll.isActive)
                                          ShaderMask(
                                            shaderCallback: (bounds) =>
                                                AppGradients.warning
                                                    .createShader(bounds),
                                            child: const Icon(
                                              Icons.emoji_events_rounded,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            option.optionText,
                                            style: TextStyle(
                                              fontWeight:
                                                  isVotedOption || isWinning
                                                      ? FontWeight.bold
                                                      : FontWeight.w500,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (hasVoted ||
                                            authProvider.isTeacher ||
                                            !poll.isActive) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient:
                                                  isWinning && !poll.isActive
                                                      ? AppGradients.success
                                                      : null,
                                              color: isWinning && !poll.isActive
                                                  ? null
                                                  : AppColors.glassDark,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${percentage.toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: isWinning &&
                                                        !poll.isActive
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${option.voteCount}',
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Poll Footer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.glassDark.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // View Chart button for teachers
                      if ((authProvider.isTeacher || authProvider.isHod) &&
                          totalVotes > 0) ...[
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showPollChart(poll);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppGradients.accent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pie_chart_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Chart',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (hasVoted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppGradients.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Voted',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (poll.endsAt != null && poll.isActive) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _getTimeColor(poll.endsAt!)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getTimeColor(poll.endsAt!)
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: _getTimeColor(poll.endsAt!),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(poll.endsAt!),
                                style: TextStyle(
                                  color: _getTimeColor(poll.endsAt!),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Anonymous voting info for students
                if (authProvider.isStudent && !hasVoted && poll.isActive)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success.withValues(alpha: 0.1),
                          AppColors.info.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shield_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Your vote is anonymous and secure',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
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

  Widget _buildPremiumStatusBadge(Poll poll) {
    if (poll.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: AppGradients.success,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.glassDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.glassBorder,
          ),
        ),
        child: const Text(
          'ENDED',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
  }

  Color _getTimeColor(DateTime endTime) {
    final diff = endTime.difference(DateTime.now());
    if (diff.inHours < 1) {
      return AppColors.error;
    } else if (diff.inHours < 24) {
      return AppColors.warning;
    } else {
      return AppColors.info;
    }
  }

  Future<void> _vote(String pollId, String optionId) async {
    final authProvider = context.read<AuthProvider>();
    final pollProvider = context.read<PollProvider>();

    if (authProvider.currentUserId == null) return;

    final success = await pollProvider.vote(
      pollId: pollId,
      optionId: optionId,
      studentId: authProvider.currentUserId!,
    );

    if (mounted) {
      HapticFeedback.mediumImpact();
      if (success) {
        PremiumSnackBar.showSuccess(context, 'Vote recorded successfully!');
      } else {
        PremiumSnackBar.showError(
            context, pollProvider.error ?? 'Failed to vote');
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now);

    if (diff.isNegative) {
      return 'Ended';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d left';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h left';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m left';
    } else {
      return 'Ending soon';
    }
  }

  void _showPollChart(Poll poll) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _PollChartSheet(poll: poll),
    );
  }
}

// Pie Chart Colors
const List<Color> _chartColors = [
  Color(0xFF6366F1), // Indigo
  Color(0xFF22C55E), // Green
  Color(0xFFF59E0B), // Amber
  Color(0xFFEF4444), // Red
  Color(0xFF8B5CF6), // Purple
  Color(0xFF06B6D4), // Cyan
  Color(0xFFEC4899), // Pink
  Color(0xFFF97316), // Orange
  Color(0xFF14B8A6), // Teal
  Color(0xFF84CC16), // Lime
];

class _PollChartSheet extends StatefulWidget {
  final Poll poll;

  const _PollChartSheet({required this.poll});

  @override
  State<_PollChartSheet> createState() => _PollChartSheetState();
}

class _PollChartSheetState extends State<_PollChartSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _voterDetails;
  bool _loadingVoters = false;

  @override
  void initState() {
    super.initState();
    // Show tabs only for non-anonymous polls
    _tabController = TabController(
      length: widget.poll.isAnonymous ? 1 : 2,
      vsync: this,
    );
    if (!widget.poll.isAnonymous) {
      _loadVoterDetails();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadVoterDetails() async {
    setState(() => _loadingVoters = true);
    try {
      final details = await context
          .read<PollProvider>()
          .getPollVotersDetails(widget.poll.id);
      if (mounted) {
        setState(() {
          _voterDetails = details;
          _loadingVoters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingVoters = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalVotes = widget.poll.totalVotes;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.pie_chart_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.poll.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '$totalVotes total votes',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                          if (!widget.poll.isAnonymous) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Public',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          // Tab Bar (only for public polls)
          if (!widget.poll.isAnonymous)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.glassDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                tabs: const [
                  Tab(text: 'Chart'),
                  Tab(text: 'Voters'),
                ],
              ),
            ),

          Divider(color: AppColors.glassBorder, height: 1),

          // Content
          Flexible(
            child: widget.poll.isAnonymous
                ? _buildChartView(totalVotes)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildChartView(totalVotes),
                      _buildVotersView(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartView(int totalVotes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Pie Chart
          SizedBox(
            height: 200,
            width: 200,
            child: CustomPaint(
              painter: _PieChartPainter(
                options: widget.poll.options,
                totalVotes: totalVotes,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalVotes',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Text(
                      'votes',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Legend
          ...widget.poll.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final percentage = option.getPercentage(totalVotes);
            final color = _chartColors[index % _chartColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        option.optionText,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: color,
                          ),
                        ),
                        Text(
                          '${option.voteCount} vote${option.voteCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildVotersView() {
    if (_loadingVoters) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      );
    }

    if (_voterDetails == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load voter details',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadVoterDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final options = _voterDetails!['options'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Who voted for each option:',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ...options.asMap().entries.map((entry) {
            final index = entry.key;
            final optionData = entry.value as Map<String, dynamic>;
            final optionText = optionData['optionText'] as String? ?? 'Option';
            final voters = optionData['voters'] as List<dynamic>? ?? [];
            final voteCount = optionData['voteCount'] as int? ?? 0;
            final color = _chartColors[index % _chartColors.length];

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.glassDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: voters.isNotEmpty,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  title: Text(
                    optionText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$voteCount vote${voteCount == 1 ? '' : 's'}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  children: [
                    if (voters.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No votes yet',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.cardDark,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          children: voters.asMap().entries.map((voterEntry) {
                            final voter =
                                voterEntry.value as Map<String, dynamic>;
                            final name = voter['name'] as String? ?? 'Unknown';
                            final rollNumber =
                                voter['rollNumber'] as String? ?? '';
                            final isLast = voterEntry.key == voters.length - 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : Border(
                                        bottom: BorderSide(
                                          color: AppColors.glassBorder,
                                          width: 0.5,
                                        ),
                                      ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          color.withValues(alpha: 0.7),
                                          color,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (rollNumber.isNotEmpty)
                                          Text(
                                            rollNumber,
                                            style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<PollOption> options;
  final int totalVotes;

  _PieChartPainter({required this.options, required this.totalVotes});

  @override
  void paint(Canvas canvas, Size size) {
    if (totalVotes == 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 30.0;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < options.length; i++) {
      final option = options[i];
      final percentage = option.getPercentage(totalVotes) / 100;
      final sweepAngle = 2 * math.pi * percentage;

      if (sweepAngle > 0) {
        final paint = Paint()
          ..color = _chartColors[i % _chartColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
          startAngle,
          sweepAngle - 0.02, // Small gap between segments
          false,
          paint,
        );

        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
