import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/dossier.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dossier_detail_screen.dart';

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
                      decoration: const InputDecoration(labelText: 'Nom du dossier *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: clientController,
                      decoration: const InputDecoration(labelText: 'Nom du client *'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: adresseController, decoration: const InputDecoration(labelText: 'Adresse du chantier')),
                    const SizedBox(height: 12),
                    TextFormField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
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
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                              } finally {
                                if (context.mounted) setModalState(() => isSubmitting = false);
                              }
                            },
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Créer le dossier'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDialog(Dossier dossier) {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController(text: dossier.nom);
    final clientController = TextEditingController(text: dossier.client);
    final adresseController = TextEditingController(text: dossier.adresseChantier);
    final descController = TextEditingController(text: dossier.description);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Modifier le dossier', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextFormField(controller: nomController, decoration: const InputDecoration(labelText: 'Nom du dossier *'), validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: clientController, decoration: const InputDecoration(labelText: 'Client *'), validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: adresseController, decoration: const InputDecoration(labelText: 'Adresse')),
                    const SizedBox(height: 12),
                    TextFormField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        setModalState(() => isSubmitting = true);
                        try {
                          await _api.updateDossier(
                            dossier.id,
                            nom: nomController.text.trim(),
                            client: clientController.text.trim(),
                            adresseChantier: adresseController.text.trim(),
                            description: descController.text.trim(),
                          );
                          if (context.mounted) Navigator.pop(context);
                          _loadDossiers();
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
                        } finally {
                          if (context.mounted) setModalState(() => isSubmitting = false);
                        }
                      },
                      child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _deleteDossier(Dossier dossier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le dossier ?'),
        content: Text('Voulez-vous supprimer "${dossier.nom}" et tous ses fichiers ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteDossier(dossier.id);
                _loadDossiers();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary));
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );
  }

  void _showPropertiesDialog(Dossier dossier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [Icon(Icons.folder, color: AppColors.primary), SizedBox(width: 8), Text('Propriétés')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropRow('Nom', dossier.nom),
            _buildPropRow('Client', dossier.client),
            _buildPropRow('Adresse', dossier.adresseChantier.isEmpty ? '-' : dossier.adresseChantier),
            _buildPropRow('Statut', dossier.statut),
            _buildPropRow('Créé le', dossier.createdAt != null ? DateFormat('dd/MM/yyyy à HH:mm').format(dossier.createdAt!) : '-'),
            if (dossier.description.isNotEmpty) _buildPropRow('Description', dossier.description),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
      ),
    );
  }

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
                    onSubmitted: (_) => _loadDossiers(),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un dossier...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _loadDossiers(); }),
                    ),
                  ),
                ),
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
                    : _dossiers.isEmpty
                        ? Center(child: Text(_searchController.text.isEmpty ? 'Aucun dossier.' : 'Aucun résultat.'))
                        : RefreshIndicator(
                            onRefresh: _loadDossiers,
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

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _dossiers.length,
      itemBuilder: (context, index) {
        final dossier = _dossiers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DossierDetailScreen(dossierId: dossier.id, dossierNom: dossier.nom))).then((_) => _loadDossiers());
            },
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.folder, color: AppColors.primary),
            ),
            title: Text(dossier.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Client : ${dossier.client}'),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'edit') _showEditDialog(dossier);
                if (val == 'delete') _deleteDossier(dossier);
                if (val == 'props') _showPropertiesDialog(dossier);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'props', child: Row(children: [Icon(Icons.info_outline, size: 20), SizedBox(width: 8), Text('Propriétés')])),
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Modifier')])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: AppColors.secondary), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.secondary))])),
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
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 250, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.1),
      itemCount: _dossiers.length,
      itemBuilder: (context, index) {
        final dossier = _dossiers[index];
        return Card(
          child: Stack(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DossierDetailScreen(dossierId: dossier.id, dossierNom: dossier.nom))).then((_) => _loadDossiers());
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(dossier.nom, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(dossier.client, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0, right: 0,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') _showEditDialog(dossier);
                    if (val == 'delete') _deleteDossier(dossier);
                    if (val == 'props') _showPropertiesDialog(dossier);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'props', child: Row(children: [Icon(Icons.info_outline, size: 20), SizedBox(width: 8), Text('Propriétés')])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Modifier')])),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: AppColors.secondary), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.secondary))])),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}