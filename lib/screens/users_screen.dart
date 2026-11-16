import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../models/user.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final ApiService _api = ApiService();
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await _api.listUsers();
      if (mounted) setState(() { _users = users; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _showUserForm({User? user}) {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController(text: user?.nom ?? '');
    final prenomController = TextEditingController(text: user?.prenom ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final passwordController = TextEditingController();
    String selectedRole = user?.role ?? 'technicien';
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(user == null ? 'Nouvel utilisateur' : 'Modifier l\'utilisateur', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: prenomController,
                        decoration: const InputDecoration(labelText: 'Prénom *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: nomController,
                        decoration: const InputDecoration(labelText: 'Nom *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        enabled: user == null, // On ne change pas l'email en modification
                        decoration: const InputDecoration(labelText: 'Email *'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(labelText: user == null ? 'Mot de passe *' : 'Nouveau mot de passe (laisser vide pour ne pas changer)'),
                        obscureText: true,
                        validator: (v) => user == null && (v == null || v.length < 6) ? 'Min. 6 caractères' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(labelText: 'Rôle *'),
                        items: const [
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          DropdownMenuItem(value: 'secretaire', child: Text('Secrétaire')),
                          DropdownMenuItem(value: 'designer', child: Text('Designer')),
                          DropdownMenuItem(value: 'dg', child: Text('DG')),
                          DropdownMenuItem(value: 'technicien', child: Text('Technicien')),
                        ],
                        onChanged: (v) => setModalState(() => selectedRole = v!),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isSubmitting ? null : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSubmitting = true);
                          
                          try {
                            if (user == null) {
                              await _api.createUser(
                                nom: nomController.text.trim(),
                                prenom: prenomController.text.trim(),
                                email: emailController.text.trim(),
                                password: passwordController.text,
                                role: selectedRole,
                              );
                            } else {
                              await _api.updateUser(
                                user.id,
                                nom: nomController.text.trim(),
                                prenom: prenomController.text.trim(),
                                role: selectedRole,
                                password: passwordController.text.isNotEmpty ? passwordController.text : null,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                            _loadUsers();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary));
                            }
                          } finally {
                            if (context.mounted) setModalState(() => isSubmitting = false);
                          }
                        },
                        child: isSubmitting
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(user == null ? 'Créer' : 'Enregistrer'),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleActive(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.actif ? 'Désactiver le compte ?' : 'Activer le compte ?'),
        content: Text('Voulez-vous ${user.actif ? 'désactiver' : 'activer'} le compte de ${user.fullName} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.updateUser(user.id, actif: !user.actif);
                _loadUsers();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
              }
            },
            child: Text(user.actif ? 'Désactiver' : 'Activer', style: TextStyle(color: user.actif ? AppColors.secondary : AppColors.success)),
          ),
        ],
      ),
    );
  }

  void _deleteUser(User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur ?'),
        content: Text('Voulez-vous vraiment supprimer le compte de ${user.fullName} ? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _api.deleteUser(user.id);
                _loadUsers();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.secondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final u = _users[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(u.prenom.isNotEmpty ? u.prenom[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.email),
                            Text(
                              u.role.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: u.role == 'admin' ? AppColors.secondary : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!u.actif)
                              const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(Icons.block, color: AppColors.secondary, size: 20),
                              ),
                            PopupMenuButton<String>(
                              onSelected: (val) {
                                if (val == 'edit') _showUserForm(user: u);
                                if (val == 'toggle') _toggleActive(u);
                                if (val == 'delete') _deleteUser(u);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Modifier')])),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Row(children: [
                                    Icon(u.actif ? Icons.visibility_off : Icons.visibility, size: 20, color: u.actif ? AppColors.secondary : AppColors.success),
                                    const SizedBox(width: 8),
                                    Text(u.actif ? 'Désactiver' : 'Activer'),
                                  ]),
                                ),
                                const PopupMenuDivider(),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: AppColors.secondary), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.secondary))])),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nouvel utilisateur', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}