import '../models/models.dart';

/// Extension for Chat with threading and moderation
class ChatThread {
  final String id;
  final String parentMessageId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final int replyCount;
  final bool isArchived;
  
  ChatThread({
    required this.id,
    required this.parentMessageId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.replyCount = 0,
    this.isArchived = false,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] ?? '',
      parentMessageId: json['parent_message_id'] ?? '',
      authorId: json['author_id'] ?? '',
      authorName: json['author_name'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      replyCount: json['reply_count'] ?? 0,
      isArchived: json['is_archived'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_message_id': parentMessageId,
      'author_id': authorId,
      'author_name': authorName,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'reply_count': replyCount,
      'is_archived': isArchived,
    };
  }
}

/// Chat message with reactions and metadata
class ChatMessageExtended extends ChatMessage {
  final List<String>? mentions; // @userIds mentioned
  final Map<String, List<String>>? reactions; // emoji -> [userId, ...]
  final bool isPinned;
  final String? threadId; // if part of thread
  
  ChatMessageExtended({
    required super.id,
    required super.branchId,
    required super.senderId,
    required super.senderType,
    required super.anonymousName,
    required super.message,
    required super.createdAt,
    this.mentions,
    this.reactions,
    this.isPinned = false,
    this.threadId,
  });

  factory ChatMessageExtended.fromJson(Map<String, dynamic> json) {
    return ChatMessageExtended(
      id: json['id'] ?? '',
      branchId: json['branch_id'] ?? '',
      senderId: json['sender_id'] ?? json['author_id'] ?? '',
      senderType: json['sender_type'] ?? 'student',
      anonymousName: json['anonymous_name'] ?? json['author_name'] ?? 'Anonymous',
      message: json['message'] ?? json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      mentions: List<String>.from(json['mentions'] ?? []),
      reactions: Map<String, List<String>>.from(
        (json['reactions'] as Map?)?.map(
          (k, v) => MapEntry(k, List<String>.from(v ?? [])),
        ) ?? {},
      ),
      isPinned: json['is_pinned'] ?? false,
      threadId: json['thread_id'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'sender_id': senderId,
      'sender_type': senderType,
      'anonymous_name': anonymousName,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'mentions': mentions,
      'reactions': reactions,
      'is_pinned': isPinned,
      'thread_id': threadId,
    };
  }

  String get authorId => senderId;
  String get authorName => anonymousName;
  String get content => message;
}

/// Moderation and reporting
class ChatReport {
  final String id;
  final String reportedMessageId;
  final String reportedById;
  final String reason; // profanity, harassment, spam, off-topic
  final String? details;
  final DateTime createdAt;
  final String status; // reported, reviewing, resolved, dismissed
  
  ChatReport({
    required this.id,
    required this.reportedMessageId,
    required this.reportedById,
    required this.reason,
    this.details,
    required this.createdAt,
    this.status = 'reported',
  });

  factory ChatReport.fromJson(Map<String, dynamic> json) {
    return ChatReport(
      id: json['id'] ?? '',
      reportedMessageId: json['reported_message_id'] ?? '',
      reportedById: json['reported_by_id'] ?? '',
      reason: json['reason'] ?? '',
      details: json['details'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      status: json['status'] ?? 'reported',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reported_message_id': reportedMessageId,
      'reported_by_id': reportedById,
      'reason': reason,
      'details': details,
      'created_at': createdAt.toIso8601String(),
      'status': status,
    };
  }
}

/// Muted users by a student
class MutedUser {
  final String userId;
  final String userName;
  final DateTime? until; // null = permanent
  final String? reason;
  
  MutedUser({
    required this.userId,
    required this.userName,
    this.until,
    this.reason,
  });

  bool get isPermanent => until == null;
  bool get isActive {
    if (isPermanent) return true;
    return until!.isAfter(DateTime.now());
  }
}

/// Auto-profanity filter configuration
class ProfanityFilter {
  static const List<String> defaultBannedWords = [
    // Common profanities - can be extended
    'badword1', 'badword2', // Placeholder
  ];

  static String filterContent(String content, [List<String>? customWords]) {
    var filtered = content;
    final words = [...defaultBannedWords, ...?customWords];
    
    for (final word in words) {
      final regex = RegExp(word, caseSensitive: false);
      filtered = filtered.replaceAll(regex, '*' * word.length);
    }
    
    return filtered;
  }

  static bool containsProfanity(String content, [List<String>? customWords]) {
    final words = [...defaultBannedWords, ...?customWords];
    final lowerContent = content.toLowerCase();
    return words.any((word) => lowerContent.contains(word.toLowerCase()));
  }
}
