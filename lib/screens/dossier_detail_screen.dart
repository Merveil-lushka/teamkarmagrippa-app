import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/document.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';
import 'upload_document_screen.dart';
import 'edit_document_screen.dart';

class DossierDetailScreen extends StatefulWidget {
  final String dossierId;
  final String dossierNom;

  const DossierDetailScreen({
    super.key,
    required this.dossierId,
    required this.dossierNom,
  });

  @override
  State<DossierDetailScreen> createState() => _DossierDetailScreenState();
}

class _DossierDetailScreenState extends State<DossierDetailScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  bool _isGridView = false;
  
  Map<String, dynamic>? _dossierData;
  List<Document> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _api.getDossierDetail(widget.dossierId);
      final docsList = (data['documents'] as List? ?? []);
      
      if (mounted) {
        setState(() {
          _dossierData = data;
          _documents = docsList.map((e) => Document.fromJson(e)).toList();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier introuvable sur le serveur.'), backgroundColor: AppColors.secondary),
        );
      }
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le fichier')),
        );
      }
    }
  }

  Future<void> _togglePublish(Document doc) async {
    try {
      await _api.togglePublish(doc.id, published: !doc.isPublished);
      _loadDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary),
        );
      }
    }
  }

  void _deleteFile(Document doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le fichier ?'),
        content: Text('Voulez-vous vraiment supprimer "${doc.nom}" ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteDocument(doc.id);
                _loadDetails();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary),
                  );
                }
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _editFile(Document doc) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditDocumentScreen(document: doc)),
    );
    if (result == true) {
      _loadDetails();
    }
  }

  // 👇 NOUVELLE FONCTION : Afficher les propriétés du fichier
  void _showFileProperties(Document doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_getFileIcon(doc.type), color: _getFileColor(doc.type)),
            const SizedBox(width: 8),
            const Text('Propriétés'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPropRow('Nom', doc.nom),
              _buildPropRow('Type', doc.type.toUpperCase()),
              _buildPropRow('Taille', doc.fichier.tailleLisible),
              _buildPropRow('Date du document', DateFormat('dd/MM/yyyy').format(doc.dateDocument)),
              _buildPropRow('Entreprise', doc.entrepriseCliente.isEmpty ? '-' : doc.entrepriseCliente),
              _buildPropRow('Chantier', doc.nomChantier.isEmpty ? '-' : doc.nomChantier),
              _buildPropRow('Statut', doc.isPublished ? 'Publié' : 'Privé'),
              if (doc.description.isNotEmpty) _buildPropRow('Description', doc.description),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

  // 👇 Helper pour afficher une ligne d'information
  Widget _buildPropRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dossierNom),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.secondary)))
              : _buildContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UploadDocumentScreen(
                dossierId: widget.dossierId,
                dossierNom: widget.dossierNom,
                clientParDefaut: _dossierData?['client'] ?? '',
                chantierParDefaut: _dossierData?['nom'] ?? '',
              ),
            ),
          );
          if (result == true) {
            _loadDetails();
          }
        },
        backgroundColor: AppColors.primary,
        tooltip: 'Ajouter un fichier',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildContent() {
    final client = _dossierData?['client'] ?? 'Inconnu';
    final adresse = _dossierData?['adresseChantier'] ?? '';
    final statut = _dossierData?['statut'] ?? 'en_cours';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          color: Theme.of(context).cardTheme.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Client : $client',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statut == 'en_cours' ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statut == 'en_cours' ? 'En cours' : 'Terminé',
                      style: TextStyle(
                        color: statut == 'en_cours' ? Colors.blue : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (adresse.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(child: Text(adresse, style: const TextStyle(color: Colors.grey))),
                  ],
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fichiers (${_documents.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton.filledTonal(
                icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                tooltip: _isGridView ? 'Vue Liste' : 'Vue Grille',
                onPressed: () {
                  setState(() {
                    _isGridView = !_isGridView;
                  });
                },
              ),
            ],
          ),
        ),

        Expanded(
          child: _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.insert_drive_file, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text('Aucun fichier dans ce dossier.'),
                    ],
                  ),
                )
              : _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return _buildDocumentCard(doc);
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
        childAspectRatio: 0.9,
      ),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final doc = _documents[index];
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
                  Text(
                    doc.nom,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.fichier.tailleLisible,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (doc.isPublished)
                        const Icon(Icons.public, color: AppColors.success, size: 20)
                      else
                        const SizedBox(width: 20),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) {
                          // 👇 Ajout de la gestion des propriétés
                          if (value == 'props') _showFileProperties(doc);
                          if (value == 'edit') _editFile(doc);
                          if (value == 'delete') _deleteFile(doc);
                          if (value == 'publish') _togglePublish(doc);
                        },
                        itemBuilder: (BuildContext context) => _buildMenuItems(doc),
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

  // 👇 Mise à jour du menu pour inclure Propriétés
  List<PopupMenuEntry<String>> _buildMenuItems(Document doc) {
    return [
      const PopupMenuItem(value: 'props', child: Row(children: [Icon(Icons.info_outline, size: 20), SizedBox(width: 8), Text('Propriétés')])),
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
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: Row(children: [Icon(Icons.delete, size: 20, color: AppColors.secondary), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.secondary))]),
      ),
    ];
  }

  Widget _buildDocumentCard(Document doc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _openFile(doc),
        leading: Icon(_getFileIcon(doc.type), color: _getFileColor(doc.type), size: 36),
        title: Text(doc.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${doc.fichier.tailleLisible} • ${DateFormat('dd/MM/yyyy').format(doc.dateDocument)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (doc.isPublished)
              const Padding(
                padding: EdgeInsets.only(right: 8.0),
                child: Chip(
                  label: Text('Publié', style: TextStyle(fontSize: 10)),
                  backgroundColor: Color(0xFFE8F5E9),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                // 👇 Ajout de la gestion des propriétés
                if (value == 'props') _showFileProperties(doc);
                if (value == 'edit') _editFile(doc);
                if (value == 'delete') _deleteFile(doc);
                if (value == 'publish') _togglePublish(doc);
              },
              itemBuilder: (BuildContext context) => _buildMenuItems(doc),
            ),
          ],
        ),
      ),
    );
  }
}