class ChatMessage {
  final String id;
  final String branchId;
  final String senderId;
  final String senderType;
  final String anonymousName;
  final String message;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.branchId,
    required this.senderId,
    required this.senderType,
    required this.anonymousName,
    required this.message,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      branchId: json['branch_id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderType: json['sender_type'] ?? '',
      anonymousName: json['anonymous_name'] ?? '',
      message: json['message'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_id': branchId,
      'sender_id': senderId,
      'sender_type': senderType,
      'anonymous_name': anonymousName,
      'message': message,
    };
  }

  bool get isTeacher => senderType == 'teacher';
  bool get isStudent => senderType == 'student';
}
