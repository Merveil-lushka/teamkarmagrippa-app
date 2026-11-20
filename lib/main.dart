import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart'; // 👈 Import ajouté

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  // 👇 Initialisation requise pour utiliser les formats de date locaux
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const TeamKarmagrippaApp(),
    ),
  );
}

class TeamKarmagrippaApp extends StatelessWidget {
  const TeamKarmagrippaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'TeamKarmagrippa Cloud',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const AuthWrapper(),
    );
  }
}

/// Ce widget vérifie si l'utilisateur a déjà un token sauvegardé
/// au démarrage de l'app. Si oui, il tente un autoLogin.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final auth = context.read<AuthProvider>();
    await auth.autoLogin();
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Chargement...'),
            ],
          ),
        ),
      );
    }

    final auth = context.watch<AuthProvider>();
    return auth.isAuthenticated ? DashboardScreen() : LoginScreen();
  }
}