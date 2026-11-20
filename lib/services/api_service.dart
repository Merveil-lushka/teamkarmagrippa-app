
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';
import '../models/dossier.dart';
import '../models/document.dart';
import '../models/comment.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  MediaType? _getMediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mp3':
        return MediaType('audio', 'mpeg');
      case 'zip':
        return MediaType('application', 'zip');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await getToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    final body = response.body.isEmpty ? '{}' : response.body;
    Map<String, dynamic> json;

    try {
      json = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'Réponse invalide du serveur',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json;
    }

    final error = json['error'];
    String message = 'Erreur inconnue';

    if (error is Map && error['message'] != null) {
      message = error['message'].toString();
    } else if (json['message'] != null) {
      message = json['message'].toString();
    }

    throw ApiException(message, statusCode: response.statusCode);
  }

  // =====================================================
  // AUTHENTIFICATION
  // =====================================================

  Future<User> login(String agentCode, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.authLogin),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'agentCode': agentCode,
        'password': password,
      }),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final user = User.fromJson(json['data']);

    if (user.token != null) {
      await saveToken(user.token!);
      await saveUser(user);
    }

    return user;
  }

  // Register n'est plus utilisé par le frontend.
  // On le conserve pour éviter les erreurs de dépendances.

  Future<User> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.authRegister),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'password': password,
      }),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final user = User.fromJson(json['data']);

    if (user.token != null) {
      await saveToken(user.token!);
      await saveUser(user);
    }

    return user;
  }

  Future<User> getMe() async {
    final response = await http.get(
      Uri.parse(ApiConfig.authMe),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return User.fromJson(json['data']);
  }

  Future<User> updateProfile({
    String? nom,
    String? prenom,
    String? password,
  }) async {
    final response = await http.put(
      Uri.parse(ApiConfig.authMe),
      headers: await _headers(),
      body: jsonEncode({
        if (nom != null) 'nom': nom,
        if (prenom != null) 'prenom': prenom,
        if (password != null && password.isNotEmpty)
          'password': password,
      }),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final updatedUser = User.fromJson(json['data']);

    await saveUser(updatedUser);
    return updatedUser;
  }

  // =====================================================
  // DOSSIERS
  // =====================================================

  Future<List<Dossier>> listDossiers({
    String? statut,
    String? client,
    String? q,
  }) async {
    final params = <String, String>{
      if (statut != null) 'statut': statut,
      if (client != null) 'client': client,
      if (q != null) 'q': q,
    };

    final uri = Uri.parse(ApiConfig.dossiers).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final list = (json['data'] as List? ?? []);

    return list
        .map((e) => Dossier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getDossierDetail(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.dossiers}/$id'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return json['data'] as Map<String, dynamic>;
  }

  Future<Dossier> createDossier({
    required String nom,
    required String client,
    String? adresseChantier,
    String? description,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.dossiers),
      headers: await _headers(),
      body: jsonEncode({
        'nom': nom,
        'client': client,
        'adresseChantier': adresseChantier ?? '',
        'description': description ?? '',
      }),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return Dossier.fromJson(json['data']);
  }

  Future<void> updateDossier(
    String dossierId, {
    String? nom,
    String? client,
    String? adresseChantier,
    String? description,
    String? statut,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.dossiers}/$dossierId'),
      headers: await _headers(),
      body: jsonEncode({
        if (nom != null) 'nom': nom,
        if (client != null) 'client': client,
        if (adresseChantier != null)
          'adresseChantier': adresseChantier,
        if (description != null) 'description': description,
        if (statut != null) 'statut': statut,
      }),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  Future<void> deleteDossier(String dossierId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.dossiers}/$dossierId'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  // =====================================================
  // DOCUMENTS
  // =====================================================

  Future<List<Document>> listMyDocuments({
    String? type,
    int? mois,
    int? annee,
    String? client,
    String? q,
    bool? published,
  }) async {
    final params = <String, String>{
      if (type != null) 'type': type,
      if (mois != null) 'mois': mois.toString(),
      if (annee != null) 'annee': annee.toString(),
      if (client != null) 'client': client,
      if (q != null) 'q': q,
      if (published != null) 'published': published.toString(),
    };

    final uri = Uri.parse('${ApiConfig.documents}/me').replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final list = (json['data'] as List? ?? []);

    return list
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Document> uploadDocument({
    File? file,
    Uint8List? fileBytes,
    required String fileName,
    required String type,
    required String nom,
    String? description,
    String? entrepriseCliente,
    String? nomChantier,
    String? adresseChantier,
    String? devise,
    required DateTime dateDocument,
    String? dossierId,
    String? numeroDevis,
    double? montantDevisHT,
    double? montantDevisTTC,
    String? numeroFacture,
    double? montantFactureTTC,
    DateTime? dateEcheanceFacture,
    String? statutPaiement,
  }) async {
    final uri = Uri.parse(ApiConfig.documents);
    final request = http.MultipartRequest('POST', uri);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    final mediaType = _getMediaType(fileName);

    if (fileBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'fichier',
          fileBytes,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    } else if (file != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'fichier',
          file.path,
          filename: fileName,
          contentType: mediaType,
        ),
      );
    } else {
      throw ApiException('Aucun fichier fourni');
    }

    final dateStr =
        '${dateDocument.year.toString().padLeft(4, '0')}-'
        '${dateDocument.month.toString().padLeft(2, '0')}-'
        '${dateDocument.day.toString().padLeft(2, '0')}';

    request.fields['type'] = type;
    request.fields['nom'] = nom;
    request.fields['dateDocument'] = dateStr;

    if (description != null && description.isNotEmpty)
      request.fields['description'] = description;
    if (entrepriseCliente != null && entrepriseCliente.isNotEmpty)
      request.fields['entrepriseCliente'] = entrepriseCliente;
    if (nomChantier != null && nomChantier.isNotEmpty)
      request.fields['nomChantier'] = nomChantier;
    if (adresseChantier != null && adresseChantier.isNotEmpty)
      request.fields['adresseChantier'] = adresseChantier;
    if (devise != null && devise.isNotEmpty)
      request.fields['devise'] = devise;
    if (dossierId != null && dossierId.isNotEmpty)
      request.fields['dossierId'] = dossierId;

    if (type == 'devis') {
      if (numeroDevis != null && numeroDevis.isNotEmpty)
        request.fields['numeroDevis'] = numeroDevis;
      if (montantDevisHT != null)
        request.fields['montantDevisHT'] = montantDevisHT.toString();
      if (montantDevisTTC != null)
        request.fields['montantDevisTTC'] = montantDevisTTC.toString();
    } else if (type == 'facture') {
      if (numeroFacture != null && numeroFacture.isNotEmpty)
        request.fields['numeroFacture'] = numeroFacture;
      if (montantFactureTTC != null)
        request.fields['montantFactureTTC'] = montantFactureTTC.toString();

      if (dateEcheanceFacture != null) {
        request.fields['dateEcheanceFacture'] =
            '${dateEcheanceFacture.year.toString().padLeft(4, '0')}-'
            '${dateEcheanceFacture.month.toString().padLeft(2, '0')}-'
            '${dateEcheanceFacture.day.toString().padLeft(2, '0')}';
      }

      if (statutPaiement != null)
        request.fields['statutPaiement'] = statutPaiement;
    }

    final streamedResponse = await request.send()
        .timeout(ApiConfig.uploadTimeout);

    final response = await http.Response.fromStream(streamedResponse);

    final json = _parseResponse(response);
    return Document.fromJson(json['data']);
  }

  Future<void> updateDocument(
    String documentId, {
    File? file,
    Uint8List? fileBytes,
    String? fileName,
    String? nom,
    String? description,
    String? entrepriseCliente,
    String? nomChantier,
    String? adresseChantier,
    String? devise,
    DateTime? dateDocument,
    Map<String, dynamic>? metadata,
  }) async {
    final uri = Uri.parse('${ApiConfig.documents}/$documentId');
    final request = http.MultipartRequest('PUT', uri);

    final token = await getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    if (fileBytes != null && fileName != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'fichier',
          fileBytes,
          filename: fileName,
          contentType: _getMediaType(fileName),
        ),
      );
    } else if (file != null && fileName != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'fichier',
          file.path,
          filename: fileName,
          contentType: _getMediaType(fileName),
        ),
      );
    }

    if (nom != null) request.fields['nom'] = nom;
    if (description != null) request.fields['description'] = description;
    if (entrepriseCliente != null)
      request.fields['entrepriseCliente'] = entrepriseCliente;
    if (nomChantier != null)
      request.fields['nomChantier'] = nomChantier;
    if (adresseChantier != null)
      request.fields['adresseChantier'] = adresseChantier;
    if (devise != null) request.fields['devise'] = devise;

    if (dateDocument != null) {
      request.fields['dateDocument'] =
          '${dateDocument.year.toString().padLeft(4, '0')}-'
          '${dateDocument.month.toString().padLeft(2, '0')}-'
          '${dateDocument.day.toString().padLeft(2, '0')}';
    }

    if (metadata != null) {
      request.fields['metadata'] = jsonEncode(metadata);
    }

    final streamedResponse = await request.send()
        .timeout(ApiConfig.uploadTimeout);

    final response = await http.Response.fromStream(streamedResponse);

    _parseResponse(response);
  }

  Future<void> togglePublish(
    String documentId, {
    required bool published,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.documents}/$documentId/publish'),
      headers: await _headers(),
      body: jsonEncode({'published': published}),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  Future<void> deleteDocument(String documentId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.documents}/$documentId'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  // =====================================================
  // PUBLICATIONS ET COMMENTAIRES
  // =====================================================

  Future<List<Document>> listPublications({
    String? type,
    int? mois,
    int? annee,
    String? client,
    String? chantier,
    String? q,
  }) async {
    final params = <String, String>{
      if (type != null) 'type': type,
      if (mois != null) 'mois': mois.toString(),
      if (annee != null) 'annee': annee.toString(),
      if (client != null) 'client': client,
      if (chantier != null) 'chantier': chantier,
      if (q != null) 'q': q,
    };

    final uri = Uri.parse(ApiConfig.publications).replace(
      queryParameters: params.isEmpty ? null : params,
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final list = (json['data'] as List? ?? []);

    return list
        .map((e) => Document.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Comment>> getComments(String documentId) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.publications}/$documentId/comments'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final list = (json['data'] as List? ?? []);

    return list
        .map((e) => Comment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Comment> addComment(String documentId, String text) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.publications}/$documentId/comments'),
      headers: await _headers(),
      body: jsonEncode({'text': text}),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return Comment.fromJson(json['data']);
  }

  Future<void> deleteComment(
    String documentId,
    String commentId,
  ) async {
    final response = await http.delete(
      Uri.parse(
        '${ApiConfig.publications}/$documentId/comments/$commentId',
      ),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  // =====================================================
  // UTILISATEURS
  // =====================================================

  Future<List<User>> listUsers() async {
    final response = await http.get(
      Uri.parse(ApiConfig.users),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    final list = (json['data'] as List? ?? []);

    return list
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<User> createUser({
    required String nom,
    required String prenom,
    String? email,
    required String password,
    required String role,
    bool? canPublish,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.users),
      headers: await _headers(),
      body: jsonEncode({
        'nom': nom,
        'prenom': prenom,
        if (email != null && email.isNotEmpty) 'email': email,
        'password': password,
        'role': role,
        if (canPublish != null) 'canPublish': canPublish,
      }),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return User.fromJson(json['data']);
  }

  Future<void> updateUser(
    String userId, {
    String? nom,
    String? prenom,
    String? role,
    bool? actif,
    String? password,
    bool? canPublish,
  }) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.users}/$userId'),
      headers: await _headers(),
      body: jsonEncode({
        if (nom != null) 'nom': nom,
        if (prenom != null) 'prenom': prenom,
        if (role != null) 'role': role,
        if (actif != null) 'actif': actif,
        if (password != null && password.isNotEmpty)
          'password': password,
        if (canPublish != null) 'canPublish': canPublish,
      }),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('${ApiConfig.users}/$userId'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  // =====================================================
  // NOTIFICATIONS
  // =====================================================

  Future<List<dynamic>> listNotifications() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return json['data'] as List? ?? [];
  }

  Future<void> markNotificationsAsRead() async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/notifications/read'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    _parseResponse(response);
  }

  Future<Map<String, dynamic>> getUnreadCommentCounts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/notifications/unread-comments'),
      headers: await _headers(),
    ).timeout(ApiConfig.requestTimeout);

    final json = _parseResponse(response);
    return json['data'] as Map<String, dynamic>? ?? {};
  }

}