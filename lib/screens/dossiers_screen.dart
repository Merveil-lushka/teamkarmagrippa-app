import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/dossier.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dossier_detail_screen.dart'; // 👈 Import ajouté ici

class DossiersScreen extends StatefulWidget {
  const DossiersScreen({super.key});

  @override
  State<DossiersScreen> createState() => _DossiersScreenState();
}

class _DossiersScreenState extends State<DossiersScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Dossier> _dossiers = [];
  bool _isLoading = true;
  String? _error;

  // 👇 État pour basculer entre liste et grille
  bool _isGridView = false; 

  @override
  void initState() {
    super.initState();
    _loadDossiers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDossiers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dossiers = await _api.listDossiers(
        q: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _dossiers = dossiers;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
        });
        if (e.statusCode == 401 && mounted) {
          context.read<AuthProvider>().logout();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur de connexion au serveur';
          _isLoading = false;
        });
      }
    }
  }

  void _showCreateDialog() {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController();
    final clientController = TextEditingController();
    final adresseController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Nouveau dossier',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du dossier *',
                        prefixIcon: Icon(Icons.folder),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: clientController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du client *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: adresseController,
                      decoration: const InputDecoration(
                        labelText: 'Adresse du chantier',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => isSubmitting = true);
                              
                              try {
                                await _api.createDossier(
                                  nom: nomController.text.trim(),
                                  client: clientController.text.trim(),
                                  adresseChantier: adresseController.text.trim(),
                                  description: descController.text.trim(),
                                );
                                if (context.mounted) Navigator.pop(context);
                                _loadDossiers();
                              } on ApiException catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message), backgroundColor: AppColors.secondary),
                                  );
                                }
                              } finally {
                                if (context.mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Créer le dossier'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
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
          // ── Barre de recherche et bouton de vue ──
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadDossiers(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un dossier...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadDossiers();
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 👇 Bouton pour basculer entre Liste et Grille
                IconButton.filledTonal(
                  tooltip: _isGridView ? 'Vue Liste' : 'Vue Grille',
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ],
            ),
          ),

          // ── Liste ou Grille ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.secondary),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: AppColors.secondary)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadDossiers,
                              child: const Text('Réessayer'),
                            )
                          ],
                        ),
                      )
                    : _dossiers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _searchController.text.isEmpty
                                      ? 'Aucun dossier pour le moment.'
                                      : 'Aucun résultat pour cette recherche.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDossiers,
                            color: AppColors.primary,
                            // 👇 Choix de l'affichage
                            child: _isGridView ? _buildGridView() : _buildListView(),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.create_new_folder, color: Colors.white),
        label: const Text('Nouveau dossier', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  // ── Vue LISTE ──────────────────────────────────────────────
  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _dossiers.length,
      itemBuilder: (context, index) {
        final dossier = _dossiers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: AppColors.primary),
            ),
            title: Text(
              dossier.nom,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Client : ${dossier.client}'),
                Text(
                  'Créé le : ${dossier.createdAt != null ? DateFormat('dd/MM/yyyy').format(dossier.createdAt!) : '-'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: _buildStatusBadge(dossier.statut),
            onTap: () {
              // 👇 Navigation vers le détail
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DossierDetailScreen(
                    dossierId: dossier.id,
                    dossierNom: dossier.nom,
                  ),
                ),
              ).then((_) => _loadDossiers());
            },
          ),
        );
      },
    );
  }

  // ── Vue GRILLE (comme Google Drive) ─────────────────────────
  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Nombre de colonnes adaptatif selon la largeur de l'écran
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250, // Largeur max d'une carte (env 250px)
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,  // Ratio hauteur/largeur de la carte
      ),
      itemCount: _dossiers.length,
      itemBuilder: (context, index) {
        final dossier = _dossiers[index];
        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              // 👇 Navigation vers le détail
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DossierDetailScreen(
                    dossierId: dossier.id,
                    dossierNom: dossier.nom,
                  ),
                ),
              ).then((_) => _loadDossiers());
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder, size: 48, color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(
                    dossier.nom,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dossier.client,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Spacer(),
                  _buildStatusBadge(dossier.statut),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Badge de statut réutilisable ───────────────────────────
  Widget _buildStatusBadge(String statut) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statut == 'en_cours' 
            ? Colors.blue.withValues(alpha: 0.1)
            : statut == 'termine'
                ? AppColors.success.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statut == 'en_cours' ? 'En cours' : statut == 'termine' ? 'Terminé' : 'Archivé',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: statut == 'en_cours' 
              ? Colors.blue
              : statut == 'termine'
                  ? AppColors.success
                  : Colors.grey,
        ),
      ),
    );
  }
}