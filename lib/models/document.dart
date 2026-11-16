class FichierInfo {
  final String originalName;
  final String mimeType;
  final int size;
  final String urlLocale;
  final String? urlCloud;
  final String cloudSyncStatus;

  FichierInfo({
    required this.originalName,
    required this.mimeType,
    required this.size,
    required this.urlLocale,
    this.urlCloud,
    required this.cloudSyncStatus,
  });

  factory FichierInfo.fromJson(Map<String, dynamic> json) {
    return FichierInfo(
      originalName: json['originalName'] ?? '',
      mimeType: json['mimeType'] ?? '',
      // 👇 Correction du bug de taille (conversion forcée en entier)
      size: (json['size'] as num?)?.toInt() ?? 0,
      urlLocale: json['urlLocale'] ?? '',
      urlCloud: json['urlCloud'],
      cloudSyncStatus: json['cloudSyncStatus'] ?? 'disabled',
    );
  }

  String get tailleLisible {
    if (size < 1024) return '$size o';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} Ko';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

class Document {
  final String id;
  final String type;
  final String nom;
  final String description;
  final String entrepriseCliente;
  final String nomChantier;
  final DateTime dateDocument;
  final int mois;
  final int annee;
  final FichierInfo fichier;
  final String? dossierId;
  final String owner;
  final bool isPublished;

  Document({
    required this.id,
    required this.type,
    required this.nom,
    required this.description,
    required this.entrepriseCliente,
    required this.nomChantier,
    required this.dateDocument,
    required this.mois,
    required this.annee,
    required this.fichier,
    this.dossierId,
    required this.owner,
    required this.isPublished,
  });

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] ?? '',
      type: json['type'] ?? 'autre',
      nom: json['nom'] ?? '',
      description: json['description'] ?? '',
      entrepriseCliente: json['entrepriseCliente'] ?? '',
      nomChantier: json['nomChantier'] ?? '',
      dateDocument: json['dateDocument'] != null 
          ? DateTime.tryParse(json['dateDocument']) ?? DateTime.now() 
          : DateTime.now(),
      mois: json['mois'] ?? 1,
      annee: json['annee'] ?? DateTime.now().year,
      fichier: FichierInfo.fromJson(json['fichier'] ?? {}),
      dossierId: json['dossier'],
      owner: json['owner'] is Map ? json['owner']['_id'] : (json['owner'] ?? ''),
      isPublished: json['isPublished'] ?? false,
    );
  }
}