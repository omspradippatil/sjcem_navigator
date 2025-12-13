class Poll {
  final String id;
  final String title;
  final String? description;
  final String? branchId;
  final String? createdBy;
  final bool isActive;
  final DateTime? endsAt;
  final DateTime? createdAt;
  
  List<PollOption> options;
  String? creatorName;

  Poll({
    required this.id,
    required this.title,
    this.description,
    this.branchId,
    this.createdBy,
    this.isActive = true,
    this.endsAt,
    this.createdAt,
    this.options = const [],
    this.creatorName,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      branchId: json['branch_id'],
      createdBy: json['created_by'],
      isActive: json['is_active'] ?? true,
      endsAt: json['ends_at'] != null 
          ? DateTime.parse(json['ends_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      options: json['poll_options'] != null
          ? (json['poll_options'] as List)
              .map((o) => PollOption.fromJson(o))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'branch_id': branchId,
      'created_by': createdBy,
      'is_active': isActive,
      'ends_at': endsAt?.toIso8601String(),
    };
  }

  int get totalVotes => options.fold(0, (sum, opt) => sum + opt.voteCount);
}

class PollOption {
  final String id;
  final String pollId;
  final String optionText;
  int voteCount;
  final DateTime? createdAt;

  PollOption({
    required this.id,
    required this.pollId,
    required this.optionText,
    this.voteCount = 0,
    this.createdAt,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] ?? '',
      pollId: json['poll_id'] ?? '',
      optionText: json['option_text'] ?? '',
      voteCount: json['vote_count'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poll_id': pollId,
      'option_text': optionText,
    };
  }

  double getPercentage(int totalVotes) {
    if (totalVotes == 0) return 0;
    return (voteCount / totalVotes) * 100;
  }
}

class PollVote {
  final String id;
  final String pollId;
  final String optionId;
  final String studentId;
  final DateTime? createdAt;

  PollVote({
    required this.id,
    required this.pollId,
    required this.optionId,
    required this.studentId,
    this.createdAt,
  });

  factory PollVote.fromJson(Map<String, dynamic> json) {
    return PollVote(
      id: json['id'] ?? '',
      pollId: json['poll_id'] ?? '',
      optionId: json['option_id'] ?? '',
      studentId: json['student_id'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'poll_id': pollId,
      'option_id': optionId,
      'student_id': studentId,
    };
  }
}
