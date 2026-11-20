import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import 'publication_detail_screen.dart';

class PublicationsScreen extends StatefulWidget {
  const PublicationsScreen({super.key});

  @override
  State<PublicationsScreen> createState() => _PublicationsScreenState();
}

class _PublicationsScreenState extends State<PublicationsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Document> _documents = [];
  bool _isLoading = true;
  String? _error;
  bool _isGridView = false;
  String? _selectedType;
  Map<String, dynamic> _unreadCounts = {}; // 👈 Stocke les badges

  @override
  void initState() {
    super.initState();
    _loadPublications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPublications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final docs = await _api.listPublications(
        type: _selectedType,
        q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      // 👇 On récupère les compteurs de messages non lus
      final counts = await _api.getUnreadCommentCounts();
      
      if (mounted) {
        setState(() {
          _documents = docs;
          _unreadCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openFile(Document doc) async {
    String? url = doc.fichier.urlCloud;
    if (url == null || url.isEmpty) {
      if (doc.fichier.urlLocale.isNotEmpty) {
        final origin = ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
        url = '$origin${doc.fichier.urlLocale}';
      }
    }
    if (url == null || url.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier introuvable.')));
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le fichier')));
    }
  }

  void _openDetail(Document doc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PublicationDetailScreen(document: doc)),
    ).then((_) => _loadPublications()); // 👈 Recharge les compteurs au retour
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Filtrer les publications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Type de document'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les types')),
                      ...['devis', 'facture', 'pdf', 'photo', 'video', 'audio', 'archive', 'document'].map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase())),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => _selectedType = v),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModalState(() => _selectedType = null),
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _loadPublications();
                          },
                          child: const Text('Appliquer'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadPublications(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une publication...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _loadPublications(); }),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(icon: const Icon(Icons.filter_list), onPressed: _showFilters),
                const SizedBox(width: 8),
                IconButton.filledTonal(icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view), onPressed: () => setState(() => _isGridView = !_isGridView)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.secondary)))
                    : _documents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.public_off, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                const Text('Aucune publication pour le moment.'),
                              ],
                            ),
                          )
                        : _isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final unreadCount = _unreadCounts[doc.id] ?? 0; // 👈 Récupère le badge
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _openFile(doc),
            leading: Icon(_getFileIcon(doc.type), color: _getFileColor(doc.type), size: 36),
            title: Text(doc.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${doc.fichier.tailleLisible} • ${DateFormat('dd/MM/yyyy').format(doc.dateDocument)}\nPublié par : ${doc.ownerName}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, color: AppColors.primary),
                  tooltip: 'Lire le fichier',
                  onPressed: () => _openFile(doc),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
                      tooltip: 'Voir les commentaires',
                      onPressed: () => _openDetail(doc),
                    ),
                    // 👇 LE BADGE ROUGE
                    if (unreadCount > 0)
                      Positioned(
                        right: 6, top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                          child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        final unreadCount = _unreadCounts[doc.id] ?? 0; // 👈 Récupère le badge
        
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openFile(doc),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_getFileIcon(doc.type), color: _getFileColor(doc.type), size: 48),
                  const SizedBox(height: 12),
                  Text(doc.nom, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(doc.fichier.tailleLisible, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(doc.ownerName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontStyle: FontStyle.italic)),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(icon: const Icon(Icons.visibility, color: AppColors.primary), onPressed: () => _openFile(doc), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                      Stack(
                        children: [
                          IconButton(icon: const Icon(Icons.chat_bubble_outline, color: AppColors.primary), onPressed: () => _openDetail(doc), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                          // 👇 LE BADGE ROUGE (Vue Grille)
                          if (unreadCount > 0)
                            Positioned(
                              right: 0, top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getFileIcon(String type) {
    if (type == 'devis' || type == 'facture' || type == 'pdf') return Icons.picture_as_pdf;
    if (type == 'photo') return Icons.image;
    if (type == 'video') return Icons.video_file;
    if (type == 'audio') return Icons.audio_file;
    if (type == 'archive') return Icons.folder_zip;
    if (type == 'document') return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String type) {
    if (type == 'devis' || type == 'facture' || type == 'pdf') return Colors.red;
    if (type == 'photo') return Colors.orange;
    if (type == 'video') return Colors.purple;
    if (type == 'audio') return Colors.teal;
    if (type == 'archive') return Colors.brown;
    if (type == 'document') return Colors.blue;
    return Colors.grey;
  }
}