import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // 👈 Ajouté

import '../models/document.dart';
import '../models/comment.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/auth_provider.dart'; // 👈 Ajouté

class PublicationDetailScreen extends StatefulWidget {
  final Document document;
  const PublicationDetailScreen({super.key, required this.document});

  @override
  State<PublicationDetailScreen> createState() => _PublicationDetailScreenState();
}

class _PublicationDetailScreenState extends State<PublicationDetailScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commentController = TextEditingController();
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _api.getComments(widget.document.id);
      if (mounted) setState(() => _comments = comments);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final newComment = await _api.addComment(widget.document.id, text);
      setState(() {
        _comments.insert(0, newComment);
        _commentController.clear();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // 👇 Fonction de suppression du commentaire
  Future<void> _deleteComment(Comment comment) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce commentaire ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.secondary)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.deleteComment(widget.document.id, comment.id);
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commentaire supprimé')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user; // Récupère l'utilisateur connecté

    return Scaffold(
      appBar: AppBar(title: Text(widget.document.nom)),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardTheme.color,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Publié le : ${DateFormat('dd/MM/yyyy').format(widget.document.dateDocument)}'),
                if (widget.document.entrepriseCliente.isNotEmpty)
                  Text('Client : ${widget.document.entrepriseCliente}'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                    ? const Center(child: Text('Aucun commentaire pour le moment.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          
                          // 👇 On vérifie si on affiche le bouton supprimer
                          final canDelete = currentUser != null && (currentUser.id == c.authorId || currentUser.role == 'admin');

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c.authorName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm').format(c.createdAt),
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                          if (canDelete) ...[
                                            const SizedBox(width: 8),
                                            InkWell(
                                              onTap: () => _deleteComment(c),
                                              child: const Icon(Icons.delete_outline, size: 18, color: AppColors.secondary),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.text),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Écrire un commentaire...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _isSending ? null : _submitComment,
                  icon: _isSending 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}