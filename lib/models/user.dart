class User {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final String role;
  final bool actif;
  final String? token;

  User({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    required this.actif,
    this.token,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'technicien',
      actif: json['actif'] ?? true,
      token: json['token'], // Présent uniquement lors du login/register
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'email': email,
      'role': role,
      'actif': actif,
      if (token != null) 'token': token,
    };
  }

  String get fullName => '$prenom $nom';
}