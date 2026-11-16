import 'dart:io';
import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class UploadDocumentScreen extends StatefulWidget {
  final String dossierId;
  final String dossierNom;
  final String clientParDefaut;
  final String chantierParDefaut;

  const UploadDocumentScreen({
    super.key,
    required this.dossierId,
    required this.dossierNom,
    this.clientParDefaut = '',
    this.chantierParDefaut = '',
  });

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  // On stocke les bytes pour le Web, ou le chemin pour le mobile/desktop
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;

  String _type = 'devis';
  DateTime _dateDocument = DateTime.now();
  
  final _nomController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _entrepriseController = TextEditingController();
  final _chantierController = TextEditingController();
  final _numeroController = TextEditingController();
  final _montantHTController = TextEditingController();
  final _montantTTCController = TextEditingController();

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _entrepriseController.text = widget.clientParDefaut;
    _chantierController.text = widget.chantierParDefaut;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _descriptionController.dispose();
    _entrepriseController.dispose();
    _chantierController.dispose();
    _numeroController.dispose();
    _montantHTController.dispose();
    _montantTTCController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      // ✅ Nouvelle API : pickFiles retourne directement une liste
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp4', 'mp3'],
      );

      if (files.isNotEmpty) {
        final platformFile = files.first;
        // ✅ On lit explicitement les bytes, comme recommandé pour le Web
        final bytes = await platformFile.readAsBytes();

        setState(() {
          _selectedFileName = platformFile.name;
          _selectedFileBytes = bytes; // On stocke les bytes
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection : $e'), backgroundColor: AppColors.secondary),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDocument,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dateDocument = picked);
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un fichier'), backgroundColor: AppColors.secondary),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // On passe fileBytes (pour le Web) et un File temporaire si nécessaire
      // ApiService gère les deux cas (bytes pour Web, chemin pour mobile)
      await _api.uploadDocument(
        fileBytes: _selectedFileBytes,
        fileName: _selectedFileName!,
        type: _type,
        nom: _nomController.text.trim(),
        description: _descriptionController.text.trim(),
        entrepriseCliente: _entrepriseController.text.trim(),
        nomChantier: _chantierController.text.trim(),
        dateDocument: _dateDocument,
        dossierId: widget.dossierId,
        numeroDevis: _type == 'devis' ? _numeroController.text.trim() : null,
        montantDevisHT: _type == 'devis' && _montantHTController.text.isNotEmpty 
            ? double.tryParse(_montantHTController.text) : null,
        montantDevisTTC: _type == 'devis' && _montantTTCController.text.isNotEmpty 
            ? double.tryParse(_montantTTCController.text) : null,
        numeroFacture: _type == 'facture' ? _numeroController.text.trim() : null,
        montantFactureTTC: _type == 'facture' && _montantTTCController.text.isNotEmpty 
            ? double.tryParse(_montantTTCController.text) : null,
      );

      if (mounted) {
        Navigator.pop(context, true); // true = succès
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier uploadé avec succès !'), backgroundColor: AppColors.success),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.secondary),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un fichier'),
      ),
      body: _isUploading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Upload en cours...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Sélection du fichier ──
                    Card(
                      child: InkWell(
                        onTap: _pickFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                _selectedFileName == null ? Icons.cloud_upload : Icons.check_circle,
                                size: 64,
                                color: _selectedFileName == null ? AppColors.primary : AppColors.success,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _selectedFileName ?? 'Appuyez pour sélectionner un fichier',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'PDF, JPG, PNG, MP4, MP3',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Type de document ──
                    DropdownButtonFormField<String>(
                      value: _type,
                      decoration: const InputDecoration(
                        labelText: 'Type de document *',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'devis', child: Text('Devis')),
                        DropdownMenuItem(value: 'facture', child: Text('Facture')),
                        DropdownMenuItem(value: 'pdf', child: Text('PDF (autre)')),
                        DropdownMenuItem(value: 'photo', child: Text('Photo')),
                        DropdownMenuItem(value: 'video', child: Text('Vidéo')),
                        DropdownMenuItem(value: 'audio', child: Text('Audio')),
                        DropdownMenuItem(value: 'autre', child: Text('Autre')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _type = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // ── Nom du document ──
                    TextFormField(
                      controller: _nomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du document *',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null,
                    ),
                    const SizedBox(height: 12),

                    // ── Date du document ──
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date du document *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(DateFormat('dd/MM/yyyy').format(_dateDocument)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Entreprise cliente ──
                    TextFormField(
                      controller: _entrepriseController,
                      decoration: const InputDecoration(
                        labelText: 'Entreprise cliente',
                        prefixIcon: Icon(Icons.business),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Nom du chantier ──
                    TextFormField(
                      controller: _chantierController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du chantier',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Champs spécifiques DEVIs / FACTURE ──
                    if (_type == 'devis' || _type == 'facture') ...[
                      TextFormField(
                        controller: _numeroController,
                        decoration: InputDecoration(
                          labelText: _type == 'devis' ? 'Numéro de devis' : 'Numéro de facture',
                          prefixIcon: const Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_type == 'devis') ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _montantHTController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Montant HT (€)',
                                prefixIcon: Icon(Icons.euro),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _montantTTCController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Montant TTC (€)',
                                prefixIcon: Icon(Icons.euro),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (_type == 'facture') ...[
                      TextFormField(
                        controller: _montantTTCController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Montant TTC (€)',
                          prefixIcon: Icon(Icons.euro),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Description ──
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Bouton Uploader ──
                    ElevatedButton.icon(
                      onPressed: _upload,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Uploader le fichier'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}