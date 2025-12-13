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
    notifyListeners();

    try {
      _polls = await SupabaseService.getPolls(
        branchId: branchId,
        activeOnly: activeOnly,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load polls: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkVoteStatus(String pollId, String studentId) async {
    final optionId = await SupabaseService.getVotedOption(pollId, studentId);
    if (optionId != null) {
      _votedOptions[pollId] = optionId;
      notifyListeners();
    }
  }

  Future<void> checkAllVoteStatus(String studentId) async {
    for (final poll in _polls) {
      await checkVoteStatus(poll.id, studentId);
    }
  }

  void subscribeToPoll(String pollId) {
    if (_pollChannels.containsKey(pollId)) return;
    
    _pollChannels[pollId] = SupabaseService.subscribeToPollVotes(
      pollId,
      () async {
        // Refresh poll data
        final updatedPoll = await SupabaseService.refreshPoll(pollId);
        if (updatedPoll != null) {
          final index = _polls.indexWhere((p) => p.id == pollId);
          if (index != -1) {
            _polls[index] = updatedPoll;
            notifyListeners();
          }
        }
      },
    );
  }

  void unsubscribeFromPoll(String pollId) {
    _pollChannels[pollId]?.unsubscribe();
    _pollChannels.remove(pollId);
  }

  void unsubscribeFromAllPolls() {
    for (final channel in _pollChannels.values) {
      channel.unsubscribe();
    }
    _pollChannels.clear();
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
        final updatedPoll = await SupabaseService.refreshPoll(pollId);
        if (updatedPoll != null) {
          final index = _polls.indexWhere((p) => p.id == pollId);
          if (index != -1) {
            _polls[index] = updatedPoll;
          }
        }
      }
      
      _isVoting = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to vote: ${e.toString()}';
      _isVoting = false;
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
      }
      
      _isLoading = false;
      notifyListeners();
      return poll;
    } catch (e) {
      _error = 'Failed to create poll: ${e.toString()}';
      _isLoading = false;
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
