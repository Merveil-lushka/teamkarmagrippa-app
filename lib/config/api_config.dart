import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// ── URL du backend ────────────────────────────────────────
  /// 
  /// - Web / Desktop (Linux, macOS, Windows) : localhost:5000
  /// - Android Emulator : 10.0.2.2:5000 (alias de localhost pour l'émulateur)
  /// - Téléphone réel : remplace par l'IP locale de ton PC (ex: 192.168.1.42)
  ///   (le téléphone et le PC doivent être sur le même WiFi)
  /// 
  /// Pour connaître ton IP locale : `hostname -I` sur Linux
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api';
    }
    if (Platform.isAndroid) {
      // Pour un émulateur, 10.0.2.2 pointe vers le localhost de la machine hôte.
      // Pour un téléphone réel, remplace par l'IP de ton PC :
      // return 'http://192.168.1.42:5000/api';
      return 'http://10.0.2.2:5000/api';
    }
    // Linux, macOS, Windows desktop
    return 'http://localhost:5000/api';
  }

  /// ── Timeouts ──────────────────────────────────────────────
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // 👇 Passé à 1 heure pour laisser le temps aux gros fichiers (vidéos)
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
  /// l'origine du serveur (sans /api).
  static String resolveFileUrl(String? urlLocale, String? urlCloud) {
    if (urlCloud != null && urlCloud.isNotEmpty) return urlCloud;
    if (urlLocale == null || urlLocale.isEmpty) return '';
    
    final origin = baseUrl.replaceAll(RegExp(r'/api$'), '');
    return '$origin$urlLocale';
  }
}