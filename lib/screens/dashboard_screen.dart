import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dossiers_screen.dart';
import 'documents_screen.dart';
import 'publications_screen.dart';
import 'users_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'create_document_screen.dart';
import 'chat_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final ApiService _api = ApiService();

  bool _isStatsLoading = true;
  int _dossiersCount = 0;
  int _documentsCount = 0;
  int _publicationsCount = 0;
  int _unreadChatCount = 0;
  Timer? _chatTimer;

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
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('TeamKarmagrippa Cloud'),
        backgroundColor: AppColors.primary,
        actions: [
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
                MaterialPageRoute(builder: (_) => LoginScreen()),
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
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    backgroundImage: user.profilePicture != null ? NetworkImage(user.profilePicture!) : null,
                    child: user.profilePicture == null ? const Icon(Icons.account_circle, color: AppColors.primary, size: 60) : null,
                  ),
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

            if (auth.isAdmin) ...[
              const Divider(),
              _buildMenuTile(icon: Icons.people, label: 'Gestion des comptes', index: 4),
            ],

            const Divider(),
            _buildMenuTile(icon: Icons.person, label: 'Mon profil', index: 5),
            
            ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.chat, color: AppColors.primary),
                  if (_unreadChatCount > 0)
                    Positioned(
                      right: -6, top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle),
                        child: Text('$_unreadChatCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              title: const Text('Chat d\'équipe'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())).then((_) {
                  setState(() => _unreadChatCount = 0);
                });
              },
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.secondary),
              title: const Text('Déconnexion', style: TextStyle(color: AppColors.secondary)),
              onTap: () async {
                await auth.logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
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

  // ── PAGE D'ACCUEIL : IMAGE EN HAUT, OPTIONS EN DESSOUS ──────
  Widget _buildHome(User user, AuthProvider auth) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1️⃣ LA BANNIÈRE (Image avec le texte à droite sur le mur bleu)
          SizedBox(
            height: 320, // Hauteur de la bannière
            child: Stack(
              fit: StackFit.expand,
              children: [
                // L'image de fond
                // ⚠️ Vérifie bien le nom de ton fichier (dashboard.png ou dashboard.jpg)
                Image.asset(
                  'assets/images/dashoard.png',
                  fit: BoxFit.cover,
                ),
                // Voile sombre pour assombrir légèrement la photo
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                // Le texte placé à DROITE (sur l'espace bleu)
                Align(
                  alignment: const Alignment(0.9, -0.15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Bienvenue,\n${user.prenom} !',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Consulter et gérer vos projets\navec toute simplicité.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2️⃣ LES OPTIONS (En dessous de l'image)
          Container(
            padding: const EdgeInsets.all(24),
            color: Theme.of(context).scaffoldBackgroundColor, // Fond de l'app classique
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Carte Générateur
                Card(
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 28),
                    ),
                    title: const Text('Générateur de documents', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Créer un devis ou une facture'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDocumentScreen())),
                  ),
                ),
                const SizedBox(height: 24),

                // Titre Vue d'ensemble
                Text(
                  auth.isTechnicien ? 'Vos publications' : 'Vue d\'ensemble',
                  style: const TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),

                // Les statistiques
                if (_isStatsLoading)
                  const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
                else if (auth.isTechnicien)
                  _buildTechStats()
                else
                  _buildStaffStats(),
              ],
            ),
          ),
        ],
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
              child: _buildStatCard(title: 'Dossiers', count: _dossiersCount, icon: Icons.folder, color: AppColors.primary, onTap: () => setState(() => _selectedIndex = 1)),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: _buildStatCard(title: 'Documents', count: _documentsCount, icon: Icons.description, color: Colors.orange, onTap: () => setState(() => _selectedIndex = 2)),
            ),
            SizedBox(
              width: isWide ? (constraints.maxWidth - 24) / 3 : constraints.maxWidth,
              child: _buildStatCard(title: 'Publications', count: _publicationsCount, icon: Icons.public, color: AppColors.success, onTap: () => setState(() => _selectedIndex = 3)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({required String title, required int count, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
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
              Text('$count', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }
}