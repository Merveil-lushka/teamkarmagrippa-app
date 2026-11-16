import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/document.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class EditDocumentScreen extends StatefulWidget {
  final Document document;
  const EditDocumentScreen({super.key, required this.document});

  @override
  State<EditDocumentScreen> createState() => _EditDocumentScreenState();
}

class _EditDocumentScreenState extends State<EditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  Uint8List? _selectedFileBytes;
  File? _selectedFile;
  String? _selectedFileName;

  late String _type;
  late DateTime _dateDocument;
  late TextEditingController _nomController;
  late TextEditingController _descController;
  late TextEditingController _entrepriseController;
  late TextEditingController _chantierController;
  late TextEditingController _numeroController;
  late TextEditingController _montantHTController;
  late TextEditingController _montantTTCController;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final doc = widget.document;
    _type = doc.type;
    _dateDocument = doc.dateDocument;
    _nomController = TextEditingController(text: doc.nom);
    _descController = TextEditingController(text: doc.description);
    _entrepriseController = TextEditingController(text: doc.entrepriseCliente);
    _chantierController = TextEditingController(text: doc.nomChantier);
    
    // On récupère les métadonnées si elles existent (il faudrait les exposer dans le modèle Document, 
    // mais pour l'instant on met juste ce qui est commun)
    _numeroController = TextEditingController(); 
    _montantHTController = TextEditingController();
    _montantTTCController = TextEditingController();
  }

  @override
  void dispose() {
    _nomController.dispose(); _descController.dispose(); _entrepriseController.dispose(); _chantierController.dispose();
    _numeroController.dispose(); _montantHTController.dispose(); _montantTTCController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mp3', 'zip', 'rar', '7z', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
      );
      if (files.isNotEmpty) {
        final bytes = await files.first.readAsBytes();
        setState(() {
          _selectedFileName = files.first.name;
          _selectedFileBytes = bytes;
          _selectedFile = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isUploading = true);

    try {
      await _api.updateDocument(
        widget.document.id,
        file: _selectedFile,
        fileBytes: _selectedFileBytes,
        fileName: _selectedFileName,
        nom: _nomController.text.trim(),
        description: _descController.text.trim(),
        entrepriseCliente: _entrepriseController.text.trim(),
        nomChantier: _chantierController.text.trim(),
        dateDocument: _dateDocument,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifié avec succès !'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.secondary));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le document')),
      body: _isUploading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: InkWell(
                        onTap: _pickFile,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(_selectedFileName == null ? Icons.cloud_upload : Icons.check_circle, size: 64, color: _selectedFileName == null ? AppColors.primary : AppColors.success),
                              const SizedBox(height: 12),
                              Text(_selectedFileName ?? 'Appuyez pour remplacer le fichier actuel', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(labelText: 'Type *'),
                      items: const [
                        DropdownMenuItem(value: 'devis', child: Text('Devis')),
                        DropdownMenuItem(value: 'facture', child: Text('Facture')),
                        DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                        DropdownMenuItem(value: 'photo', child: Text('Photo')),
                        DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                        DropdownMenuItem(value: 'audio', child: Text('Audio')),
                        DropdownMenuItem(value: 'archive', child: Text('Archive')),
                        DropdownMenuItem(value: 'document', child: Text('Document')),
                        DropdownMenuItem(value: 'autre', child: Text('Autre')),
                      ],
                      onChanged: (v) { if (v != null) setState(() => _type = v); },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _nomController, decoration: const InputDecoration(labelText: 'Nom *'), validator: (v) => v!.isEmpty ? 'Requis' : null),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: _dateDocument, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (picked != null) setState(() => _dateDocument = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date *'),
                        child: Text(DateFormat('dd/MM/yyyy').format(_dateDocument)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: _entrepriseController, decoration: const InputDecoration(labelText: 'Entreprise cliente')),
                    const SizedBox(height: 12),
                    TextFormField(controller: _chantierController, decoration: const InputDecoration(labelText: 'Nom du chantier')),
                    const SizedBox(height: 12),
                    if (_type == 'devis' || _type == 'facture') ...[
                      TextFormField(controller: _numeroController, decoration: const InputDecoration(labelText: 'Numéro (auto-généré si vide)')),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(controller: _descController, maxLines: 2, decoration: const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(onPressed: _submit, icon: const Icon(Icons.save), label: const Text('Enregistrer les modifications')),
                  ],
                ),
              ),
            ),
    );
  }
}