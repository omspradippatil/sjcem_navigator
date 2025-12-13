import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class TimetableProvider extends ChangeNotifier {
  List<TimetableEntry> _todayTimetable = [];
  List<TimetableEntry> _weekTimetable = [];
  TimetableEntry? _currentPeriod;
  TimetableEntry? _nextPeriod;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;
  
  // Countdown
  Duration _timeUntilNext = Duration.zero;
  Duration _timeRemaining = Duration.zero;

  List<TimetableEntry> get todayTimetable => _todayTimetable;
  List<TimetableEntry> get weekTimetable => _weekTimetable;
  TimetableEntry? get currentPeriod => _currentPeriod;
  TimetableEntry? get nextPeriod => _nextPeriod;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Duration get timeUntilNext => _timeUntilNext;
  Duration get timeRemaining => _timeRemaining;
  
  String get todayName => AppConstants.daysOfWeek[DateTime.now().weekday % 7];

  TimetableProvider() {
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCurrentAndNext();
    });
  }

  Future<void> loadTodayTimetable({
    required String branchId,
    required int semester,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _todayTimetable = await SupabaseService.getTodayTimetable(
        branchId: branchId,
        semester: semester,
      );
      _updateCurrentAndNext();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load timetable: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWeekTimetable({
    required String branchId,
    required int semester,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _weekTimetable = await SupabaseService.getTimetable(
        branchId: branchId,
        semester: semester,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load timetable: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateCurrentAndNext() {
    if (_todayTimetable.isEmpty) return;

    TimetableEntry? current;
    TimetableEntry? next;

    for (int i = 0; i < _todayTimetable.length; i++) {
      final entry = _todayTimetable[i];
      
      if (entry.isCurrentPeriod) {
        current = entry;
        if (i + 1 < _todayTimetable.length) {
          next = _todayTimetable[i + 1];
        }
        break;
      } else if (entry.isUpcoming) {
        next = entry;
        break;
      }
    }

    _currentPeriod = current;
    _nextPeriod = next;
    
    if (_currentPeriod != null) {
      _timeRemaining = _currentPeriod!.timeRemaining;
    } else {
      _timeRemaining = Duration.zero;
    }
    
    if (_nextPeriod != null) {
      _timeUntilNext = _nextPeriod!.timeUntilStart;
    } else {
      _timeUntilNext = Duration.zero;
    }

    notifyListeners();
  }

  List<TimetableEntry> getTimetableForDay(int dayOfWeek) {
    return _weekTimetable
        .where((entry) => entry.dayOfWeek == dayOfWeek)
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
  }

  String formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00:00';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}
