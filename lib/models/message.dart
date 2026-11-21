class ChatMessage {
  final String id;
  final String text;
  final String senderId;
  final String senderName;
  final String senderRole;
  final DateTime createdAt;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;

  ChatMessage({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.createdAt,
    this.fileUrl,
    this.fileType,
    this.fileName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: json['_id'] ?? '',
      text: json['text'] ?? '',
      senderId: sender['_id'] ?? '',
      senderName: '${sender['prenom'] ?? ''} ${sender['nom'] ?? ''}'.trim(),
      senderRole: sender['role'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      fileUrl: json['fileUrl'],
      fileType: json['fileType'],
      fileName: json['fileName'],
    );
  }
}