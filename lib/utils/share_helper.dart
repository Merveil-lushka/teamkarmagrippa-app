import 'package:share_plus/share_plus.dart';
import '../models/document.dart';
import '../config/api_config.dart';

class ShareHelper {
  static Future<void> shareDocument(Document doc) async {
    String? url = doc.fichier.urlCloud;
    
    // Si pas d'URL Cloudinary, on prend l'URL locale (Render)
    if (url == null || url.isEmpty) {
      if (doc.fichier.urlLocale.isNotEmpty) {
        final origin = ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
        url = '$origin${doc.fichier.urlLocale}';
      }
    }

    if (url == null || url.isEmpty) {
      throw Exception('Lien du fichier introuvable');
    }

    // On prépare le message à envoyer avec le lien
    final text = 'Voici le document "${doc.nom}" :\n$url';
    
    // On ouvre le menu de partage natif du téléphone
    await Share.share(text, subject: doc.nom);
  }
}
