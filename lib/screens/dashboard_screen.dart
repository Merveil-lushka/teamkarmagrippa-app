import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'dossiers_screen.dart';
import 'documents_screen.dart';
import 'publications_screen.dart';
import 'users_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'create_document_screen.dart'; // 👈 Import ajouté
import 'notifications_screen.dart';
import 'chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ApiService _api = ApiService();
  int _unreadChatCount = 0;
  Timer? _chatTimer;

  bool _isStatsLoading = true;
  int _dossiersCount = 0;
  int _documentsCount = 0;
  int _publicationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _chatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final count = await _api.getUnreadMessageCount();
        if (mounted) setState(() => _unreadChatCount = count);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;

    setState(() => _isStatsLoading = true);

    try {
      final pubs = await _api.listPublications();
      
      int dossiers = 0;
      int documents = 0;
      
      if (!auth.isTechnicien) {
        final dossiersList = await _api.listDossiers();
        final documentsList = await _api.listMyDocuments();
        dossiers = dossiersList.length;
        documents = documentsList.length;
      }

      if (mounted) {
        setState(() {
          _publicationsCount = pubs.length;
          _dossiersCount = dossiers;
          _documentsCount = documents;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isStatsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen()), // 👈 const retiré
          (route) => false,
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TeamKarmagrippa Cloud'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Changer le thème',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => context.read<ThemeProvider>().toggleTheme(),
          ),
          IconButton(
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => LoginScreen()), // 👈 const retiré
                (route) => false,
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.account_circle, color: Colors.white, size: 60),
                  const SizedBox(height: 8),
                  Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(user.role.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            _buildMenuTile(icon: Icons.dashboard, label: 'Tableau de bord', index: 0),
            
            if (auth.canManageDossiers) ...[
              _buildMenuTile(icon: Icons.folder, label: 'Mes dossiers', index: 1),
              _buildMenuTile(icon: Icons.description, label: 'Mes documents', index: 2),
            ],

            _buildMenuTile(icon: Icons.public, label: 'Publications', index: 3),
            const Divider(),
            ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat, color: AppColors.primary),
                  if (_unreadChatCount > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_unreadChatCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: const Text('Chat d\'équipe'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                ).then((_) {
                  setState(() => _unreadChatCount = 0);
                });
              },
            ),

            if (auth.isAdmin) ...[
              const Divider(),
              _buildMenuTile(icon: Icons.people, label: 'Gestion des comptes', index: 4),
            ],

            const Divider(),
            ListTile(
              leading: const Icon(Icons.system_update, color: AppColors.primary),
              title: const Text('Vérifier les mises à jour'),
              onTap: () async {
                Navigator.pop(context); // Ferme le drawer
                final updateService = UpdateService();

                try {
                  final updateInfo = await updateService.checkForUpdate();

                  if (!context.mounted) return;

                  if (updateInfo != null && updateInfo['needsUpdate'] == true) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Mise à jour disponible'),
                        content: Text(
                          'Une nouvelle version (${updateInfo['latestVersion']}) est disponible. Voulez-vous la télécharger ?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Plus tard'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Téléchargement en cours...'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                              await updateService.downloadAndInstall(
                                updateInfo['downloadUrl'],
                              );
                            },
                            child: const Text('Mettre à jour'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Votre application est à jour !'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Impossible de vérifier les mises à jour : $e'),
                    ),
                  );
                }
              },
            ),
            const Divider(),
            _buildMenuTile(icon: Icons.person, label: 'Mon profil', index: 5),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.secondary),
              title: const Text('Déconnexion', style: TextStyle(color: AppColors.secondary)),
              onTap: () async {
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()), // 👈 const retiré
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: _buildBody(user, auth),
    );
  }

  Widget _buildMenuTile({required IconData icon, required String label, required int index}) {
    return ListTile(
      leading: Icon(icon, color: _selectedIndex == index ? AppColors.primary : null),
      title: Text(
        label,
        style: TextStyle(
          color: _selectedIndex == index ? AppColors.primary : null,
          fontWeight: _selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: _selectedIndex == index,
      selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
      onTap: () {
        setState(() => _selectedIndex = index);
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildBody(User user, AuthProvider auth) {
    switch (_selectedIndex) {
      case 0: return _buildHome(user, auth);
      case 1: return const DossiersScreen();
      case 2: return const DocumentsScreen();
      case 3: return const PublicationsScreen(); 
      case 4: return const UsersScreen();
      case 5: return const ProfileScreen();
      default: return _buildHome(user, auth);
    }
  }

  Widget _buildHome(User user, AuthProvider auth) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        user.prenom.isNotEmpty ? user.prenom[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bienvenue, ${user.prenom} !', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Consulter et gérer les projets avec toute simplicité.',
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 👇 Carte du générateur ajoutée ici
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 28),
                ),
                title: const Text('Générateur de documents', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Créer un devis ou une facture avec calculs'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateDocumentScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            Text(
              auth.isTechnicien ? 'Vos publications' : 'Vue d\'ensemble',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_isStatsLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (auth.isTechnicien)
              _buildTechStats()
            else
              _buildStaffStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildTechStats() {
    return Card(
      color: AppColors.primary,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = 3),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Icon(Icons.public, color: Colors.white, size: 48),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_publicationsCount', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                    const Text('Documents publiés à consulter', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaffStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: _buildStatCard(
                title: 'Dossiers',
                count: _dossiersCount,
                icon: Icons.folder,
                color: AppColors.primary,
                onTap: () => setState(() => _selectedIndex = 1),
              ),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: _buildStatCard(
                title: 'Documents',
                count: _documentsCount,
                icon: Icons.description,
                color: Colors.orange,
                onTap: () => setState(() => _selectedIndex = 2),
              ),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: _buildStatCard(
                title: 'Publications en ligne',
                count: _publicationsCount,
                icon: Icons.public,
                color: AppColors.success,
                onTap: () => setState(() => _selectedIndex = 3),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 16),
              Text('$count', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}