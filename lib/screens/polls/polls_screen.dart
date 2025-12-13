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

class _PollsScreenState extends State<PollsScreen> {
  @override
  void initState() {
    super.initState();
    _loadPolls();
  }

  Future<void> _loadPolls() async {
    final authProvider = context.read<AuthProvider>();
    final pollProvider = context.read<PollProvider>();
    
    await pollProvider.loadPolls(
      branchId: authProvider.currentBranchId,
      activeOnly: true,
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
  void dispose() {
    context.read<PollProvider>().unsubscribeFromAllPolls();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final pollProvider = context.watch<PollProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPolls,
        child: pollProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : pollProvider.polls.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.poll_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No active polls',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                        if (authProvider.isTeacher || authProvider.isHod)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: ElevatedButton.icon(
                              onPressed: () => _navigateToCreatePoll(),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Poll'),
                            ),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: pollProvider.polls.length,
                    itemBuilder: (context, index) {
                      final poll = pollProvider.polls[index];
                      return _buildPollCard(poll, authProvider, pollProvider);
                    },
                  ),
      ),
      floatingActionButton: (authProvider.isTeacher || authProvider.isHod)
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToCreatePoll(),
              icon: const Icon(Icons.add),
              label: const Text('Create Poll'),
            )
          : null,
    );
  }

  void _navigateToCreatePoll() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CreatePollScreen(),
      ),
    );
  }

  Widget _buildPollCard(Poll poll, AuthProvider authProvider, PollProvider pollProvider) {
    final hasVoted = pollProvider.hasVoted(poll.id);
    final votedOptionId = pollProvider.getVotedOption(poll.id);
    final totalVotes = poll.totalVotes;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    poll.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                if (poll.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
            const SizedBox(height: 16),
            
            // Poll Options
            ...poll.options.map((option) {
              final percentage = option.getPercentage(totalVotes);
              final isVotedOption = votedOptionId == option.id;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: (authProvider.isStudent && !hasVoted)
                      ? () => _vote(poll.id, option.id)
                      : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isVotedOption
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.shade300,
                        width: isVotedOption ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        // Progress background
                        if (hasVoted || authProvider.isTeacher)
                          Positioned.fill(
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isVotedOption
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                            ),
                          ),
                        
                        // Option content
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              if (isVotedOption)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                )
                              else if (!hasVoted && authProvider.isStudent)
                                Icon(
                                  Icons.radio_button_unchecked,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option.optionText,
                                  style: TextStyle(
                                    fontWeight: isVotedOption
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (hasVoted || authProvider.isTeacher) ...[
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${option.voteCount})',
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
            }),
            
            // Poll Footer
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total votes: $totalVotes',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (hasVoted)
                  Row(
                    children: [
                      Icon(
                        Icons.how_to_vote,
                        size: 14,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'You voted',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                if (poll.endsAt != null)
                  Text(
                    'Ends: ${_formatDate(poll.endsAt!)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            
            // Anonymous voting info for students
            if (authProvider.isStudent && !hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield,
                      size: 14,
                      color: Colors.green[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Your vote is anonymous',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
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
          content: Text(
            success
                ? 'Vote recorded successfully!'
                : pollProvider.error ?? 'Failed to vote',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
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
    } else {
      return '${diff.inMinutes}m left';
    }
  }
}
