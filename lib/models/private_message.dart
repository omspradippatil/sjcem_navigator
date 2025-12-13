class PrivateMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  
  // For display purposes
  String? senderName;
  String? receiverName;

  PrivateMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
    this.senderName,
    this.receiverName,
  });

  factory PrivateMessage.fromJson(Map<String, dynamic> json) {
    return PrivateMessage(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      message: json['message'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'is_read': isRead,
    };
  }
}

class Conversation {
  final String oderId;
  final String odierName;
  final PrivateMessage? lastMessage;
  final int unreadCount;

  Conversation({
    required this.oderId,
    required this.odierName,
    this.lastMessage,
    this.unreadCount = 0,
  });
}
