import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // 👇 Ton URL Render (sans le /api à la fin)
  static const String _productionUrl = 'https://teamkarmagrippa-backend.onrender.com';

  static String get baseUrl {
    // Sur le Web (Chrome), sur Android (émulateur ou vrai téléphone), 
    // ou sur Desktop, on utilise toujours l'URL de Render.
    if (kIsWeb) {
      return '$_productionUrl/api';
    }
    
    return '$_productionUrl/api';
  }

  /// ── Timeouts ──────────────────────────────────────────────
  // On garde 30 secondes pour les requêtes normales
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // On garde 1 heure pour les gros uploads de fichiers
  static const Duration uploadTimeout = Duration(hours: 1); 

  /// ── Endpoints d'authentification ──────────────────────────
  static String get authLogin => '$baseUrl/auth/login';
  static String get authRegister => '$baseUrl/auth/register';
  static String get authMe => '$baseUrl/auth/me';

  /// ── Endpoints métier ──────────────────────────────────────
  static String get dossiers => '$baseUrl/dossiers';
  static String get documents => '$baseUrl/documents';
  static String get publications => '$baseUrl/publications';
  static String get users => '$baseUrl/users';

  /// ── Construction d'URL de fichiers ────────────────────────
  /// Les URLs Cloudinary sont complètes (https://...), les URLs locales
  /// sont relatives (/uploads/...). On doit préfixer ces dernières par
  /// l'origine du serveur Render (sans /api).
  static String resolveFileUrl(String? urlLocale, String? urlCloud) {
    if (urlCloud != null && urlCloud.isNotEmpty) return urlCloud;
    if (urlLocale == null || urlLocale.isEmpty) return '';
    
    final origin = _productionUrl; // https://teamkarmagrippa-backend.onrender.com
    return '$origin$urlLocale';
  }
}