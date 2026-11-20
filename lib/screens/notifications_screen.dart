import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.listNotifications();
      await _api.markNotificationsAsRead();
      if (mounted) setState(() { _notifications = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('Aucune notification.'))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, i) {
                    final n = _notifications[i];
                    final isRead = n['isRead'] ?? false;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isRead ? Colors.grey.shade200 : AppColors.primary.withValues(alpha: 0.2),
                        child: Icon(
                          n['type'] == 'comment' ? Icons.chat_bubble : Icons.public,
                          color: isRead ? Colors.grey : AppColors.primary,
                        ),
                      ),
                      title: Text(n['message'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(n['createdAt']))),
                    );
                  },
                ),
    );
  }
}