import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../config/api_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final msgs = await _api.getMessages();
      if (mounted) {
        setState(() {
          _messages = msgs;
          _isLoading = false;
        });
        if (!silent) _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    try {
      await _api.sendMessage(text);
      _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles();

      if (result.isNotEmpty) {
        final platformFile = result.first;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Envoi du fichier...')),
          );
        }

        final path = platformFile.path;
        final file = path != null ? File(path) : null;
        final fileBytes = await platformFile.readAsBytes();
        await _api.sendMessageFile(file, fileBytes, platformFile.name);
        _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _deleteMessage(ChatMessage msg) async {
    try {
      await _api.deleteMessage(msg.id);
      _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    String finalUrl = url;
    if (!url.startsWith('http')) {
      final origin = ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
      finalUrl = '$origin$url';
    }
    if (!await launchUrl(Uri.parse(finalUrl), mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Discussion d\'équipe')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.senderId == currentUser?.id;
                      final canDelete = isMe || currentUser?.role == 'admin';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    Text(
                                      '${msg.senderName} (${msg.senderRole})',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.primaryLight : AppColors.primaryDark),
                                    ),
                                  if (!isMe) const SizedBox(height: 4),
                                  
                                  if (msg.text.isNotEmpty)
                                    Text(msg.text, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                                  
                                  if (msg.fileUrl != null) ...[
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => _openFile(msg.fileUrl),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isMe ? Colors.white24 : Colors.black12,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.insert_drive_file, color: isMe ? Colors.white : AppColors.primary, size: 20),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                msg.fileName ?? 'Fichier',
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      DateFormat('HH:mm').format(msg.createdAt),
                                      style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                              
                              // 👇 Menu de suppression (bouton 3 points)
                              if (canDelete)
                                Positioned(
                                  top: -8, right: -8,
                                  child: PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, size: 16, color: isMe ? Colors.white70 : Colors.grey),
                                    padding: EdgeInsets.zero,
                                    onSelected: (val) {
                                      if (val == 'delete') _deleteMessage(msg);
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: AppColors.secondary), SizedBox(width: 8), Text('Supprimer')])),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.attach_file, color: AppColors.primary), onPressed: _pickFile),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendText(),
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}