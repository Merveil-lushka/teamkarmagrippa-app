class Comment {
  final String id;
  final String text;
  final DateTime createdAt;
  final String authorId; // 👈 Ajouté pour identifier l'auteur
  final String authorName;
  final String authorRole;

  Comment({
    required this.id,
    required this.text,
    required this.createdAt,
    required this.authorId, // 👈 Ajouté
    required this.authorName,
    required this.authorRole,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>? ?? {};
    final nom = author['nom'] ?? '';
    final prenom = author['prenom'] ?? '';
    
    return Comment(
      id: json['_id'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      authorId: author['_id'] ?? '', // 👈 Récupère l'ID de l'auteur
      authorName: '$prenom $nom'.trim(),
      authorRole: author['role'] ?? 'inconnu',
    );
  }
}