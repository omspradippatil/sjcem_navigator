class Announcement {
  final String id;
  final String title;
  final String content;
  final String? branchId;
  final String? createdBy;
  final bool isPinned;
  final bool isActive;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? creatorName;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    this.branchId,
    this.createdBy,
    this.isPinned = false,
    this.isActive = true,
    this.expiresAt,
    this.createdAt,
    this.creatorName,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      branchId: json['branch_id'],
      createdBy: json['created_by'],
      isPinned: json['is_pinned'] ?? false,
      isActive: json['is_active'] ?? true,
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      creatorName: json['teachers']?['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'branch_id': branchId,
      'created_by': createdBy,
      'is_pinned': isPinned,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
