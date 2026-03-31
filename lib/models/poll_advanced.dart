
/// Extension for Poll with scheduling and advanced features
class PollScheduling {
  final String pollId;
  final DateTime? scheduledPublishAt;
  final Duration? autoCloseAfter;
  final List<String>? segmentBySemesters; // e.g., ['1', '2', '3']
  final List<String>? segmentByBranches;  // e.g., ['CSE', 'ECE']
  
  PollScheduling({
    required this.pollId,
    this.scheduledPublishAt,
    this.autoCloseAfter,
    this.segmentBySemesters,
    this.segmentByBranches,
  });

  factory PollScheduling.fromJson(Map<String, dynamic> json) {
    return PollScheduling(
      pollId: json['poll_id'] ?? '',
      scheduledPublishAt: json['scheduled_publish_at'] != null
          ? DateTime.parse(json['scheduled_publish_at'])
          : null,
      autoCloseAfter: json['auto_close_after_minutes'] != null
          ? Duration(minutes: json['auto_close_after_minutes'])
          : null,
      segmentBySemesters: List<String>.from(json['segment_by_semesters'] ?? []),
      segmentByBranches: List<String>.from(json['segment_by_branches'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poll_id': pollId,
      'scheduled_publish_at': scheduledPublishAt?.toIso8601String(),
      'auto_close_after_minutes': autoCloseAfter?.inMinutes,
      'segment_by_semesters': segmentBySemesters,
      'segment_by_branches': segmentByBranches,
    };
  }
}

/// Poll result insights with trends and statistics
class PollInsights {
  final String pollId;
  final int totalVotes;
  final double participationRate; // 0-100%
  final DateTime? startedAt;
  final DateTime? closedAt;
  final List<OptionTrend> trends;
  
  PollInsights({
    required this.pollId,
    required this.totalVotes,
    required this.participationRate,
    this.startedAt,
    this.closedAt,
    required this.trends,
  });

  factory PollInsights.fromJson(Map<String, dynamic> json) {
    return PollInsights(
      pollId: json['poll_id'] ?? '',
      totalVotes: json['total_votes'] ?? 0,
      participationRate: (json['participation_rate'] ?? 0).toDouble(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'])
          : null,
      trends: List<OptionTrend>.from(
        (json['trends'] ?? []).map(
          (t) => OptionTrend.fromJson(t),
        ),
      ),
    );
  }
}

/// Individual option vote trend
class OptionTrend {
  final String optionId;
  final String optionText;
  final int voteCount;
  final double percentage;
  final List<int>? hourlyVotes; // For trend chart
  
  OptionTrend({
    required this.optionId,
    required this.optionText,
    required this.voteCount,
    required this.percentage,
    this.hourlyVotes,
  });

  factory OptionTrend.fromJson(Map<String, dynamic> json) {
    return OptionTrend(
      optionId: json['option_id'] ?? '',
      optionText: json['option_text'] ?? '',
      voteCount: json['vote_count'] ?? 0,
      percentage: (json['percentage'] ?? 0).toDouble(),
      hourlyVotes: List<int>.from(json['hourly_votes'] ?? []),
    );
  }
}
