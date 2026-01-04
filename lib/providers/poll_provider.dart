import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/postgres_service.dart';

class PollProvider extends ChangeNotifier {
  List<Poll> _polls = [];
  final Map<String, String?> _votedOptions = {}; // pollId -> optionId
  bool _isLoading = false;
  bool _isVoting = false;
  String? _error;
  String? _currentBranchId;
  int? _currentSemester;

  List<Poll> get polls => _polls;
  bool get isLoading => _isLoading;
  bool get isVoting => _isVoting;
  String? get error => _error;

  bool hasVoted(String pollId) => _votedOptions.containsKey(pollId);

  String? getVotedOption(String pollId) => _votedOptions[pollId];

  Future<void> loadPolls({
    required String branchId,
    required int semester,
  }) async {
    _isLoading = true;
    _error = null;
    _currentBranchId = branchId;
    _currentSemester = semester;

    try {
      _polls = await PostgresService.getPolls(
        branchId: branchId,
        semester: semester,
      );
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    } catch (e) {
      _error = 'Failed to load polls: ${e.toString()}';
      _isLoading = false;
      Future.microtask(() => notifyListeners());
    }
  }

  Future<void> checkVoteStatus(String pollId, String studentId) async {
    final optionId = await PostgresService.getUserVote(pollId, studentId);
    if (optionId != null) {
      _votedOptions[pollId] = optionId;
    }
  }

  Future<void> checkAllVoteStatus(String studentId) async {
    for (final poll in _polls) {
      await checkVoteStatus(poll.id, studentId);
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
      final success = await PostgresService.votePoll(
        optionId: optionId,
        voterId: studentId,
      );

      if (success) {
        _votedOptions[pollId] = optionId;
        // Refresh polls to get updated vote counts
        if (_currentBranchId != null && _currentSemester != null) {
          await loadPolls(
              branchId: _currentBranchId!, semester: _currentSemester!);
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
    required String branchId,
    required int semester,
    required String question,
    required String createdBy,
    required List<String> options,
    DateTime? expiresAt,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final poll = await PostgresService.createPoll(
        branchId: branchId,
        semester: semester,
        question: question,
        createdBy: createdBy,
        options: options,
        expiresAt: expiresAt,
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
    super.dispose();
  }
}
