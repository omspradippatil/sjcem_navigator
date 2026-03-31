import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/action_queue_service.dart';
import '../services/supabase_service.dart';
import '../services/offline_cache_service.dart';

class PollProvider extends ChangeNotifier {
  List<Poll> _polls = [];
  final Map<String, String?> _votedOptions = {}; // pollId -> optionId
  final Map<String, RealtimeChannel> _pollChannels = {};
  bool _isLoading = false;
  bool _isVoting = false;
  String? _error;
  bool _isOfflineMode = false;

  List<Poll> get polls => _polls;
  bool get isLoading => _isLoading;
  bool get isVoting => _isVoting;
  String? get error => _error;
  bool get isOfflineMode => _isOfflineMode;

  bool hasVoted(String pollId) => _votedOptions.containsKey(pollId);

  String? getVotedOption(String pollId) => _votedOptions[pollId];

  /// Load cached vote status for a user (call on app start/login)
  Future<void> loadCachedVoteStatus(String userId) async {
    try {
      final cachedVotes = await OfflineCacheService.getCachedVotedPolls(userId);
      _votedOptions.addAll(cachedVotes);
      debugPrint('📦 Loaded ${cachedVotes.length} cached votes for user');
    } catch (e) {
      debugPrint('Error loading cached vote status: $e');
    }
  }

  Future<void> loadPolls({String? branchId, bool activeOnly = true}) async {
    _isLoading = true;
    _error = null;
    _isOfflineMode = false;

    try {
      _polls = await SupabaseService.getPolls(
        branchId: branchId,
        activeOnly: activeOnly,
      );

      // Sync queued offline votes once we're online and polls are loaded.
      await syncPendingVotes();

      // Cache polls for offline use
      if (_polls.isNotEmpty && branchId != null) {
        await OfflineCacheService.cachePolls(_polls, branchId);
      }

      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      debugPrint('Error loading polls: $e - trying offline cache');

      // Try loading from cache
      if (branchId != null) {
        final cachedPolls = await OfflineCacheService.getCachedPolls(branchId);
        if (cachedPolls.isNotEmpty) {
          _polls = cachedPolls;
          _isOfflineMode = true;
          _error = null;
          debugPrint('📦 Loaded ${cachedPolls.length} polls from cache');
        } else {
          _error = 'Failed to load polls. Please try again.';
        }
      } else {
        _error = 'Failed to load polls. Please try again.';
      }

      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> checkVoteStatus(String pollId, String studentId) async {
    // First check cache
    if (_votedOptions.containsKey(pollId)) {
      return; // Already have vote status from cache
    }

    try {
      final optionId = await SupabaseService.getVotedOption(pollId, studentId);
      if (optionId != null) {
        _votedOptions[pollId] = optionId;
        // Update cache
        await OfflineCacheService.cacheVote(studentId, pollId, optionId);
      }
    } catch (e) {
      debugPrint('Error checking vote status: $e');
    }
  }

  Future<void> checkAllVoteStatus(String studentId) async {
    // First load cached votes
    await loadCachedVoteStatus(studentId);

    // Then check for any new votes from server
    for (final poll in _polls) {
      if (!_votedOptions.containsKey(poll.id)) {
        await checkVoteStatus(poll.id, studentId);
      }
    }
  }

  void subscribeToPoll(String pollId) {
    if (_pollChannels.containsKey(pollId)) return;

    try {
      _pollChannels[pollId] = SupabaseService.subscribeToPollVotes(
        pollId,
        () async {
          // Refresh poll data
          try {
            final updatedPoll = await SupabaseService.refreshPoll(pollId);
            if (updatedPoll != null) {
              final index = _polls.indexWhere((p) => p.id == pollId);
              if (index != -1) {
                _polls[index] = updatedPoll;
                notifyListeners();
              }
            }
          } catch (e) {
            debugPrint('Error refreshing poll: $e');
          }
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to poll: $e');
    }
  }

  void unsubscribeFromPoll(String pollId) {
    try {
      _pollChannels[pollId]?.unsubscribe();
      _pollChannels.remove(pollId);
    } catch (e) {
      debugPrint('Error unsubscribing from poll: $e');
    }
  }

  void unsubscribeFromAllPolls() {
    try {
      for (final channel in _pollChannels.values) {
        channel.unsubscribe();
      }
      _pollChannels.clear();
    } catch (e) {
      debugPrint('Error unsubscribing from all polls: $e');
    }
  }

  Future<bool> vote({
    required String pollId,
    required String optionId,
    required String studentId,
  }) async {
    if (_votedOptions.containsKey(pollId)) {
      _error = 'You have already voted on this poll';
      notifyListeners();
      return false;
    }

    _isVoting = true;
    _error = null;
    notifyListeners();

    try {
      final isOnline = await OfflineCacheService.checkConnectivity();
      if (!isOnline) {
        await ActionQueueService.queueAction(
          actionType: ActionQueueService.actionVote,
          targetId: pollId,
          payload: {
            'poll_id': pollId,
            'option_id': optionId,
            'student_id': studentId,
          },
          groupId: pollId,
        );

        _votedOptions[pollId] = optionId;
        await OfflineCacheService.cacheVote(studentId, pollId, optionId);
        _applyOptimisticVoteLocally(pollId, optionId);

        _isOfflineMode = true;
        _isVoting = false;
        notifyListeners();
        return true;
      }

      final success = await SupabaseService.vote(
        pollId: pollId,
        optionId: optionId,
        studentId: studentId,
      );

      if (success) {
        _votedOptions[pollId] = optionId;

        // Cache the vote for persistence across app restarts
        await OfflineCacheService.cacheVote(studentId, pollId, optionId);

        // Refresh poll data
        try {
          final updatedPoll = await SupabaseService.refreshPoll(pollId);
          if (updatedPoll != null) {
            final index = _polls.indexWhere((p) => p.id == pollId);
            if (index != -1) {
              _polls[index] = updatedPoll;
            }
          }
        } catch (e) {
          debugPrint('Error refreshing poll after vote: $e');
        }
      } else {
        _error = 'Failed to record vote. Please try again.';
      }

      _isVoting = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to vote. Please check your connection.';
      _isVoting = false;
      debugPrint('Error voting: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> syncPendingVotes() async {
    try {
      final isOnline = await OfflineCacheService.checkConnectivity();
      if (!isOnline) return;

      final pending =
          await ActionQueueService.getActionsByType(ActionQueueService.actionVote);

      for (final action in pending) {
        final pollId = action.payload['poll_id'] as String?;
        final optionId = action.payload['option_id'] as String?;
        final studentId = action.payload['student_id'] as String?;
        if (pollId == null || optionId == null || studentId == null) {
          continue;
        }

        final success = await SupabaseService.vote(
          pollId: pollId,
          optionId: optionId,
          studentId: studentId,
        );

        if (success) {
          await ActionQueueService.markActionSynced(action.id);
          continue;
        }

        // If already voted on server, drop stale queued vote.
        final alreadyVoted = await SupabaseService.hasVoted(pollId, studentId);
        if (alreadyVoted) {
          await ActionQueueService.markActionSynced(action.id);
        }
      }

      _isOfflineMode = false;
    } catch (e) {
      debugPrint('Error syncing pending votes: $e');
    }
  }

  void _applyOptimisticVoteLocally(String pollId, String optionId) {
    final pollIndex = _polls.indexWhere((p) => p.id == pollId);
    if (pollIndex == -1) return;

    final poll = _polls[pollIndex];
    final updatedOptions = poll.options.map((option) {
      if (option.id == optionId) {
        return PollOption(
          id: option.id,
          pollId: option.pollId,
          optionText: option.optionText,
          voteCount: option.voteCount + 1,
          createdAt: option.createdAt,
        );
      }
      return option;
    }).toList();

    _polls[pollIndex] = Poll(
      id: poll.id,
      title: poll.title,
      description: poll.description,
      branchId: poll.branchId,
      createdBy: poll.createdBy,
      isActive: poll.isActive,
      isAnonymous: poll.isAnonymous,
      targetAllBranches: poll.targetAllBranches,
      endsAt: poll.endsAt,
      createdAt: poll.createdAt,
      options: updatedOptions,
    );
  }

  Future<Poll?> createPoll({
    required String title,
    String? description,
    String? branchId,
    required String createdBy,
    required List<String> options,
    DateTime? endsAt,
    bool targetAllBranches = false,
    bool isAnonymous = true,
    String? creatorName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final poll = await SupabaseService.createPoll(
        title: title,
        description: description,
        branchId: targetAllBranches ? null : branchId,
        createdBy: createdBy,
        options: options,
        endsAt: endsAt,
        targetAllBranches: targetAllBranches,
        isAnonymous: isAnonymous,
      );

      if (poll != null) {
        _polls.insert(0, poll);

        // Notify all teachers about the new poll
        await SupabaseService.notifyTeachersAboutPoll(
          pollId: poll.id,
          pollTitle: title,
          creatorName: creatorName ?? 'Teacher',
          branchId: targetAllBranches ? null : branchId,
        );
      } else {
        _error = 'Failed to create poll. Please try again.';
      }

      _isLoading = false;
      notifyListeners();
      return poll;
    } catch (e) {
      _error = 'Failed to create poll. Please check your connection.';
      _isLoading = false;
      debugPrint('Error creating poll: $e');
      notifyListeners();
      return null;
    }
  }

  /// Get detailed vote statistics for teachers (counts and percentages)
  Future<Map<String, dynamic>> getPollVoteDetails(String pollId) async {
    try {
      return await SupabaseService.getPollVoteDetails(pollId);
    } catch (e) {
      debugPrint('Error getting poll vote details: $e');
      return {};
    }
  }

  /// Get voters for each option (for public/non-anonymous polls only - teachers)
  Future<Map<String, dynamic>> getPollVotersDetails(String pollId) async {
    try {
      return await SupabaseService.getPollVotersDetails(pollId);
    } catch (e) {
      debugPrint('Error getting poll voters details: $e');
      return {};
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    unsubscribeFromAllPolls();
    super.dispose();
  }
}
