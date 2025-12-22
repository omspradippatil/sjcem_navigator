import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/poll_provider.dart';
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
    context.read<PollProvider>().unsubscribeFromAllPolls();
    super.dispose();
  }

  Future<void> _loadPolls() async {
    final authProvider = context.read<AuthProvider>();
    final pollProvider = context.read<PollProvider>();

    await pollProvider.loadPolls(
      branchId: authProvider.currentBranchId,
      activeOnly: false, // Load all polls
    );

    // Check vote status for students
    if (authProvider.isStudent && authProvider.currentUserId != null) {
      await pollProvider.checkAllVoteStatus(authProvider.currentUserId!);
    }

    // Subscribe to poll updates
    for (final poll in pollProvider.polls) {
      pollProvider.subscribeToPoll(poll.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final pollProvider = context.watch<PollProvider>();

    // Separate active and ended polls
    final activePolls = pollProvider.polls.where((p) => p.isActive).toList();
    final endedPolls = pollProvider.polls.where((p) => !p.isActive).toList();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.how_to_vote, size: 18),
                    const SizedBox(width: 8),
                    Text('Active (${activePolls.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.history, size: 18),
                    const SizedBox(width: 8),
                    Text('Past (${endedPolls.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPollList(activePolls, authProvider, pollProvider,
              isActive: true),
          _buildPollList(endedPolls, authProvider, pollProvider,
              isActive: false),
        ],
      ),
      floatingActionButton: (authProvider.isTeacher || authProvider.isHod)
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreatePoll,
              icon: const Icon(Icons.add),
              label: const Text('Create Poll'),
            )
          : null,
    );
  }

  Widget _buildPollList(
    List<Poll> polls,
    AuthProvider authProvider,
    PollProvider pollProvider, {
    required bool isActive,
  }) {
    if (pollProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (polls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isActive ? Colors.blue.shade50 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.poll_outlined : Icons.history,
                size: 64,
                color: isActive ? Colors.blue.shade300 : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isActive ? 'No active polls' : 'No past polls',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Check back later for new polls'
                  : 'Completed polls will appear here',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPolls,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: polls.length,
        itemBuilder: (context, index) {
          final poll = polls[index];
          return _buildPollCard(poll, authProvider, pollProvider);
        },
      ),
    );
  }

  void _navigateToCreatePoll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreatePollScreen(),
      ),
    );
  }

  Widget _buildPollCard(
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: poll.isActive ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: poll.isActive ? Colors.blue.shade200 : Colors.grey.shade200,
          width: poll.isActive ? 1 : 0,
        ),
      ),
      child: Column(
        children: [
          // Poll Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: poll.isActive
                  ? Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3)
                  : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: poll.isActive
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.poll,
                        size: 20,
                        color: poll.isActive ? Colors.blue : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        poll.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    _buildStatusBadge(poll),
                  ],
                ),
                if (poll.description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    poll.description!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Poll Options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: poll.options.map((option) {
                final percentage = option.getPercentage(totalVotes);
                final isVotedOption = votedOptionId == option.id;
                final isWinning =
                    option.id == winningOption?.id && totalVotes > 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap:
                        (authProvider.isStudent && !hasVoted && poll.isActive)
                            ? () => _vote(poll.id, option.id)
                            : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isVotedOption
                              ? Theme.of(context).colorScheme.primary
                              : isWinning && !poll.isActive
                                  ? Colors.green.shade400
                                  : Colors.grey.shade300,
                          width: isVotedOption || (isWinning && !poll.isActive)
                              ? 2
                              : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
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
                                    color: isVotedOption
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                        : isWinning && !poll.isActive
                                            ? Colors.green.shade50
                                            : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(11),
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
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  )
                                else if (!hasVoted &&
                                    authProvider.isStudent &&
                                    poll.isActive)
                                  Icon(
                                    Icons.radio_button_unchecked,
                                    color: Colors.grey[400],
                                    size: 20,
                                  )
                                else if (isWinning && !poll.isActive)
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    option.optionText,
                                    style: TextStyle(
                                      fontWeight: isVotedOption || isWinning
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (hasVoted ||
                                    authProvider.isTeacher ||
                                    !poll.isActive) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isWinning && !poll.isActive
                                          ? Colors.green.shade100
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${percentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: isWinning && !poll.isActive
                                            ? Colors.green.shade700
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${option.voteCount}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
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
                );
              }).toList(),
            ),
          ),

          // Poll Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (hasVoted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Voted',
                          style: TextStyle(
                            color: Colors.green.shade700,
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
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTimeColor(poll.endsAt!).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade50, Colors.blue.shade50],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield,
                    size: 16,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your vote is anonymous and secure',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Poll poll) {
    if (poll.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.green, Colors.teal],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, color: Colors.white, size: 8),
            SizedBox(width: 4),
            Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'ENDED',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
  }

  Color _getTimeColor(DateTime endTime) {
    final diff = endTime.difference(DateTime.now());
    if (diff.inHours < 1) {
      return Colors.red;
    } else if (diff.inHours < 24) {
      return Colors.orange;
    } else {
      return Colors.blue;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                success
                    ? 'Vote recorded successfully!'
                    : pollProvider.error ?? 'Failed to vote',
              ),
            ],
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
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
}
