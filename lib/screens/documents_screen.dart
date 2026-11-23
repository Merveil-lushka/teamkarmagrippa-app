import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import '../widgets/file_preview.dart';
import '../utils/share_helper.dart';
import 'edit_document_screen.dart'; 

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Document> _documents = [];
  bool _isLoading = true;
  String? _error;
  bool _isGridView = false;

  // Filtres
  String? _selectedType;
  int? _selectedMois;
  int? _selectedAnnee;
  bool? _selectedPublished;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final docs = await _api.listMyDocuments(
        type: _selectedType,
        mois: _selectedMois,
        annee: _selectedAnnee,
        published: _selectedPublished,
        q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _documents = docs;
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
    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le fichier')));
    }
  }

  Future<void> _togglePublish(Document doc) async {
    try {
      await _api.togglePublish(doc.id, published: !doc.isPublished);
      _loadDocuments(); // Rafraîchit la liste
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary),
        );
      }
    }
  }

  Future<void> _editFile(Document doc) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditDocumentScreen(document: doc)),
    );
    if (result == true) _loadDocuments();
  }

  Future<void> _shareFile(Document doc) async {
    try {
      await ShareHelper.shareDocument(doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary),
        );
      }
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  const Text('Filtrer les documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: _selectedMois,
                    decoration: const InputDecoration(labelText: 'Mois'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous les mois')),
                      ...List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1, 
                        child: Text(DateFormat('MMMM', 'fr').format(DateTime(2024, i + 1)))
                      )),
                    ],
                    onChanged: (v) => setModalState(() => _selectedMois = v),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<int>(
                    value: _selectedAnnee,
                    decoration: const InputDecoration(labelText: 'Année'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Toutes les années')),
                      ...List.generate(5, (i) => DropdownMenuItem(
                        value: DateTime.now().year - i, 
                        child: Text('${DateTime.now().year - i}')
                      )),
                    ],
                    onChanged: (v) => setModalState(() => _selectedAnnee = v),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<bool>(
                    value: _selectedPublished,
                    decoration: const InputDecoration(labelText: 'Statut de publication'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Tous les documents')),
                      DropdownMenuItem(value: true, child: Text('Publiés uniquement')),
                      DropdownMenuItem(value: false, child: Text('Non publiés uniquement')),
                    ],
                    onChanged: (v) => setModalState(() => _selectedPublished = v),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedType = null;
                              _selectedMois = null;
                              _selectedAnnee = null;
                              _selectedPublished = null;
                            });
                          },
                          child: const Text('Réinitialiser'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _loadDocuments();
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

  List<PopupMenuEntry<String>> _buildMenuItems(Document doc) {
    return [
      const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share, size: 20), SizedBox(width: 8), Text('Partager')])),
      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Modifier')])),
      PopupMenuItem(
        value: 'publish',
        child: Row(
          children: [
            Icon(doc.isPublished ? Icons.visibility_off : Icons.public, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Text(doc.isPublished ? 'Dépublier' : 'Publier'),
          ],
        ),
      ),
    ];
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
                    onSubmitted: (_) => _loadDocuments(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un document...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _loadDocuments(); }),
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
                        ? const Center(child: Text('Aucun document trouvé.'))
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
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () => _openFile(doc),
            leading: FilePreview(doc: doc, size: 45),
            title: Text(doc.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${doc.fichier.tailleLisible} • ${DateFormat('dd/MM/yyyy').format(doc.dateDocument)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (doc.isPublished)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Chip(label: Text('Publié', style: TextStyle(fontSize: 10)), backgroundColor: Color(0xFFE8F5E9), side: BorderSide.none, visualDensity: VisualDensity.compact),
                  ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'share') ShareHelper.shareDocument(doc);
                    if (val == 'edit') _editFile(doc);
                    if (val == 'publish') _togglePublish(doc);
                  },
                  itemBuilder: (ctx) => _buildMenuItems(doc),
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return Card(
          child: Stack(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openFile(doc),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilePreview(doc: doc, isGridView: true),
                      const SizedBox(height: 12),
                      Text(doc.nom, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(doc.fichier.tailleLisible, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Spacer(),
                      if (doc.isPublished)
                        const Icon(Icons.public, color: AppColors.success, size: 20)
                      else
                        const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0, right: 0,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'share') ShareHelper.shareDocument(doc);
                    if (val == 'edit') _editFile(doc);
                    if (val == 'publish') _togglePublish(doc);
                  },
                  itemBuilder: (ctx) => _buildMenuItems(doc),
                ),
              ),
            ],
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