import 'package:material_ui/material_ui.dart';
import '../models/document.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';

class FilePreview extends StatelessWidget {
  final Document doc;
  final double size;
  final bool isGridView;

  const FilePreview({
    super.key,
    required this.doc,
    this.size = 40,
    this.isGridView = false,
  });

  // Transforme l'URL Cloudinary pour avoir une miniature légère (w_200, h_200)
  String _getThumbnailUrl(String url) {
    if (url.isEmpty) return '';
    // Si c'est une URL locale, on ajoute l'origine (Render)
    if (!url.startsWith('http')) {
      final origin = ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
      url = '$origin$url';
    }
    // Optimisation Cloudinary
    if (url.contains('cloudinary.com') && url.contains('/upload/')) {
      return url.replaceFirst('/upload/', '/upload/w_200,h_200,c_fill/');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final isImage = doc.type == 'photo' || doc.fichier.mimeType.startsWith('image/');
    final url = _getThumbnailUrl(doc.fichier.urlCloud ?? doc.fichier.urlLocale);

    if (isImage && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: isGridView ? double.infinity : size,
          height: isGridView ? 120 : size, // Plus haut en mode grille
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => 
              Icon(Icons.broken_image, color: Colors.grey, size: size),
        ),
      );
    }

    // Si ce n'est pas une image, on affiche l'icône classique
    return Icon(
      _getFileIcon(doc.type), 
      color: _getFileColor(doc.type), 
      size: isGridView ? 48 : size,
    );
  }

  IconData _getFileIcon(String type) {
    if (type == 'devis' || type == 'facture' || type == 'pdf') return Icons.picture_as_pdf;
    if (type == 'video') return Icons.video_file;
    if (type == 'audio') return Icons.audio_file;
    if (type == 'archive') return Icons.folder_zip;
    if (type == 'document') return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String type) {
    if (type == 'devis' || type == 'facture' || type == 'pdf') return Colors.red;
    if (type == 'video') return Colors.purple;
    if (type == 'audio') return Colors.teal;
    if (type == 'archive') return Colors.brown;
    if (type == 'document') return Colors.blue;
    return Colors.grey;
  }
}
