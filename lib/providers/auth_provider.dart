import 'package:material_ui/material_ui.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  User? _user;
  bool _loading = false;
  String? _error;

  // ── Getters ──────────────────────────────────────────────
  User? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String get role => _user?.role ?? '';

  bool get isAdmin => role == 'admin';
  bool get isSecretaire => role == 'secretaire';
  bool get isDesigner => role == 'designer';
  bool get isDG => role == 'dg';
  bool get isTechnicien => role == 'technicien';

  /// Rôles autorisés à créer / gérer des dossiers
  bool get canManageDossiers =>
      isAdmin || isSecretaire || isDesigner || isDG;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  void _setError(String? msg) {
    _error = msg;
    notifyListeners();
  }

  // ═════════════════════════════════════════════════════════
  // AUTO-LOGIN (au démarrage de l'app)
  // ═════════════════════════════════════════════════════════
  Future<bool> autoLogin() async {
    _setLoading(true);
    _setError(null);
    try {
      final token = await _api.getToken();
      if (token == null || token.isEmpty) {
        _setLoading(false);
        return false;
      }

      // Récupère les infos fraîches du user depuis le backend
      final user = await _api.getMe();
      _user = user;
      await _api.saveUser(user);
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      // Token expiré ou invalide → nettoyage
      await _api.logout();
      _user = null;
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Erreur de connexion au serveur');
      _setLoading(false);
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════
  // LOGIN
  // ═════════════════════════════════════════════════════════
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = await _api.login(email.trim(), password);
      _user = user;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Erreur de connexion. Vérifiez le réseau.');
      _setLoading(false);
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════
  // REGISTER
  // ═════════════════════════════════════════════════════════
  Future<bool> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = await _api.register(
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        password: password,
      );
      _user = user;
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Erreur de connexion. Vérifiez le réseau.');
      _setLoading(false);
      return false;
    }
  }

  // ═════════════════════════════════════════════════════════
  // LOGOUT
  // ═════════════════════════════════════════════════════════
  Future<void> logout() async {
    await _api.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  // 👇 NOUVELLE MÉTHODE : Mise à jour locale après modification du profil
  void updateUserData(User updatedUser) {
    _user = updatedUser;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}