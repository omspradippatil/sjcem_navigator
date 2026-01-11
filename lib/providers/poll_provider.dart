import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';

class PollProvider extends ChangeNotifier {
  List<Poll> _polls = [];
  final Map<String, String?> _votedOptions = {}; // pollId -> optionId
  final Map<String, RealtimeChannel> _pollChannels = {};
  bool _isLoading = false;
  bool _isVoting = false;
  String? _error;

  List<Poll> get polls => _polls;
  bool get isLoading => _isLoading;
  bool get isVoting => _isVoting;
  String? get error => _error;

  bool hasVoted(String pollId) => _votedOptions.containsKey(pollId);

  String? getVotedOption(String pollId) => _votedOptions[pollId];

  Future<void> loadPolls({String? branchId, bool activeOnly = true}) async {
    _isLoading = true;
    _error = null;

    try {
      _polls = await SupabaseService.getPolls(
        branchId: branchId,
        activeOnly: activeOnly,
      );
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load polls. Please try again.';
      _isLoading = false;
      debugPrint('Error loading polls: $e');
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> checkVoteStatus(String pollId, String studentId) async {
    try {
      final optionId = await SupabaseService.getVotedOption(pollId, studentId);
      if (optionId != null) {
        _votedOptions[pollId] = optionId;
        // Silent update - no notifications during load
      }
    } catch (e) {
      debugPrint('Error checking vote status: $e');
    }
  }

  Future<void> checkAllVoteStatus(String studentId) async {
    for (final poll in _polls) {
      await checkVoteStatus(poll.id, studentId);
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
      final success = await SupabaseService.vote(
        pollId: pollId,
        optionId: optionId,
        studentId: studentId,
      );

      if (success) {
        _votedOptions[pollId] = optionId;

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

  Future<Poll?> createPoll({
    required String title,
    String? description,
    String? branchId,
    required String createdBy,
    required List<String> options,
    DateTime? endsAt,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final poll = await SupabaseService.createPoll(
        title: title,
        description: description,
        branchId: branchId,
        createdBy: createdBy,
        options: options,
        endsAt: endsAt,
      );

      if (poll != null) {
        _polls.insert(0, poll);
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
