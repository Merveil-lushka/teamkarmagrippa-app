import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdateService {
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // 1. Récupérer la version actuelle de l'app
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // 2. Récupérer la version en ligne
      final response = await http.get(Uri.parse('https://teamkarmagrippa-backend.onrender.com/api/version'));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final String latestVersion = data['latestVersion'];
      final String downloadUrl = data['downloadUrl'];

      // 3. Comparer les versions
      if (latestVersion != currentVersion) {
        return {
          'needsUpdate': true,
          'latestVersion': latestVersion,
          'downloadUrl': downloadUrl,
        };
      }
      return {'needsUpdate': false};
    } catch (e) {
      return null; // Si erreur réseau, on ignore
    }
  }

  Future<void> downloadAndInstall(String url) async {
    try {
      final dir = await getExternalStorageDirectory();
      final filePath = '${dir!.path}/update.apk';
      final file = File(filePath);

      // Téléchargement
      final response = await http.get(Uri.parse(url));
      await file.writeAsBytes(response.bodyBytes);

      // Installation
      await OpenFilex.open(filePath);
    } catch (e) {
      print('Erreur update: $e');
    }
  }
}