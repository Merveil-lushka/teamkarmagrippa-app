class User {
  final String id;
  final String nom;
  final String prenom;
  final String? email; // 👈 L'email n'est plus obligatoire
  final String agentCode; // 👈 Nouveau champ
  final String role;
  final bool actif;
  final bool canPublish;
  final String? token;

  User({
    required this.id,
    required this.nom,
    required this.prenom,
    this.email,
    required this.agentCode, // 👈 Ajouté
    required this.role,
    required this.actif,
    required this.canPublish,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      email: json['email'],
      agentCode: json['agentCode'] ?? '', // 👈 Ajouté
      role: json['role'] ?? 'technicien',
      actif: json['actif'] ?? true,
      canPublish: json['canPublish'] ?? false,
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'agentCode': agentCode, // 👈 Ajouté
      'role': role,
      'actif': actif,
      'canPublish': canPublish,
      if (token != null) 'token': token,
    };
  }

  String get fullName => '$prenom $nom';
}