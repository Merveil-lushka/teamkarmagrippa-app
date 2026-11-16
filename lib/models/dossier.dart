class Dossier {
  final String id;
  final String nom;
  final String client;
  final String adresseChantier;
  final String description;
  final String statut;
  final String owner;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Dossier({
    required this.id,
    required this.nom,
    required this.client,
    required this.adresseChantier,
    required this.description,
    required this.statut,
    required this.owner,
    this.createdAt,
    this.updatedAt,
  });

  factory Dossier.fromJson(Map<String, dynamic> json) {
    return Dossier(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      client: json['client'] ?? '',
      adresseChantier: json['adresseChantier'] ?? '',
      description: json['description'] ?? '',
      statut: json['statut'] ?? 'en_cours',
      owner: json['owner'] is Map ? json['owner']['_id'] : (json['owner'] ?? ''),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }
}