import 'dart:typed_data';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LigneFacture {
  String designation;
  double quantite;
  double prixUnitaire;
  
  LigneFacture({required this.designation, required this.quantite, required this.prixUnitaire});

  double get total => quantite * prixUnitaire;
}

class CreateDocumentScreen extends StatefulWidget {
  const CreateDocumentScreen({super.key});

  @override
  State<CreateDocumentScreen> createState() => _CreateDocumentScreenState();
}

class _CreateDocumentScreenState extends State<CreateDocumentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();
  
  String _typeDocument = 'Devis';
  String _titre = 'Travaux';
  String _devise = 'USD'; 
  DateTime _dateDocument = DateTime.now(); 
  
  final _clientController = TextEditingController();
  final _chantierController = TextEditingController();
  final _adresseController = TextEditingController(); 
  final _descriptionController = TextEditingController();
  
  final _typeAutreController = TextEditingController();
  final _titreAutreController = TextEditingController();

  final List<LigneFacture> _lignes = [
    LigneFacture(designation: '', quantite: 1, prixUnitaire: 0),
  ];

  bool _isGenerating = false;

  double get _totalGeneral => _lignes.fold(0, (sum, ligne) => sum + ligne.total);

  void _ajouterLigne() {
    setState(() {
      _lignes.add(LigneFacture(designation: '', quantite: 1, prixUnitaire: 0));
    });
  }

  void _supprimerLigne(int index) {
    setState(() {
      _lignes.removeAt(index);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDocument,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dateDocument = picked);
  }

  Future<void> _genererDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lignes.isEmpty || _lignes.every((l) => l.designation.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un article valide'), backgroundColor: AppColors.secondary),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final pdf = pw.Document();
      final symbol = _devise == 'USD' ? '\$' : _devise == 'CDF' ? 'FC' : '€';
      final finalType = _typeDocument == 'Autre' ? _typeAutreController.text : _typeDocument;
      final finalTitre = _titre == 'Autre' ? _titreAutreController.text : _titre;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TeamKarmagrippa', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(finalType.toUpperCase(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date : ${DateFormat('dd/MM/yyyy').format(_dateDocument)}'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('CLIENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.Text(_clientController.text),
              if (_adresseController.text.isNotEmpty) pw.Text(_adresseController.text),
              pw.SizedBox(height: 10),
              pw.Text('CHANTIER : $finalTitre - ${_chantierController.text}'),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headers: ['Désignation', 'Quantité', 'Prix Unitaire', 'Total'],
                data: _lignes.map((l) {
                  return [
                    l.designation,
                    l.quantite.toString(),
                    '$symbol ${l.prixUnitaire.toStringAsFixed(2)}',
                    '$symbol ${l.total.toStringAsFixed(2)}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                  child: pw.Text(
                    'TOTAL : $symbol ${_totalGeneral.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              if (_descriptionController.text.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Notes :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(_descriptionController.text),
              ],
            ];
          },
        ),
      );

      final Uint8List bytes = await pdf.save();
      final fileName = '${finalType}_${_clientController.text.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd').format(_dateDocument)}.pdf';

      await _api.uploadDocument(
        fileBytes: bytes,
        fileName: fileName,
        type: finalType.toLowerCase() == 'devis' ? 'devis' : finalType.toLowerCase() == 'facture' ? 'facture' : 'pdf',
        nom: '$finalType - ${_clientController.text}',
        description: _descriptionController.text,
        entrepriseCliente: _clientController.text,
        nomChantier: _chantierController.text,
        adresseChantier: _adresseController.text,
        devise: _devise,
        dateDocument: _dateDocument,
        montantDevisTTC: _totalGeneral, 
      );

      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF généré et enregistré dans "Mes documents" !'), backgroundColor: AppColors.success),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération : $e'), backgroundColor: AppColors.secondary),
        );
      }
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _chantierController.dispose();
    _adresseController.dispose();
    _descriptionController.dispose();
    _typeAutreController.dispose();
    _titreAutreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Générer un document')),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Génération du PDF et envoi en cours...'),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _typeDocument,
                            decoration: const InputDecoration(labelText: 'Type de document *'),
                            items: ['Devis', 'BAT', 'Facture', 'Autre'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _typeDocument = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_typeDocument == 'Autre')
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _typeAutreController,
                              decoration: const InputDecoration(labelText: 'Précisez le type *'),
                              validator: (v) => v!.isEmpty ? 'Requis' : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _titre,
                            decoration: const InputDecoration(labelText: 'Prestation *'),
                            items: ['Travaux', 'Fenêtre', 'Porte', 'Guichet', 'Autre'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _titre = v!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (_titre == 'Autre')
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _titreAutreController,
                              decoration: const InputDecoration(labelText: 'Précisez la prestation *'),
                              validator: (v) => v!.isEmpty ? 'Requis' : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Date du document *', prefixIcon: Icon(Icons.calendar_today)),
                              child: Text(DateFormat('dd/MM/yyyy').format(_dateDocument)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _devise,
                            decoration: const InputDecoration(labelText: 'Devise *'),
                            items: const [
                              DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                              DropdownMenuItem(value: 'CDF', child: Text('CDF (FC)')),
                              DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                            ],
                            onChanged: (v) => setState(() => _devise = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientController,
                      decoration: const InputDecoration(labelText: 'Nom du client / Entreprise *', prefixIcon: Icon(Icons.person)),
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _chantierController,
                      decoration: const InputDecoration(labelText: 'Nom du chantier *', prefixIcon: Icon(Icons.location_city)),
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _adresseController,
                      decoration: const InputDecoration(labelText: 'Adresse du client *', prefixIcon: Icon(Icons.map)),
                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Articles / Prestations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        TextButton.icon(onPressed: _ajouterLigne, icon: const Icon(Icons.add), label: const Text('Ajouter')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._lignes.asMap().entries.map((entry) {
                      final index = entry.key;
                      final ligne = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: ligne.designation,
                                      decoration: const InputDecoration(labelText: 'Désignation de l\'article *', isDense: true),
                                      onChanged: (v) => ligne.designation = v,
                                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                                    ),
                                  ),
                                  IconButton(icon: const Icon(Icons.delete, color: AppColors.secondary), onPressed: () => _supprimerLigne(index)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: ligne.quantite.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Quantité *', isDense: true),
                                      onChanged: (v) => setState(() => ligne.quantite = double.tryParse(v) ?? 0),
                                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: ligne.prixUnitaire.toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(labelText: 'Prix Unit. ($_devise) *', isDense: true),
                                      onChanged: (v) => setState(() => ligne.prixUnitaire = double.tryParse(v) ?? 0),
                                      validator: (v) => v!.isEmpty ? 'Requis' : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'Total ligne : ${NumberFormat.currency(locale: 'fr_FR', symbol: _devise == 'USD' ? '\$' : _devise == 'CDF' ? 'FC' : '€').format(ligne.total)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const Divider(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL GÉNÉRAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            NumberFormat.currency(locale: 'fr_FR', symbol: _devise == 'USD' ? '\$' : _devise == 'CDF' ? 'FC' : '€').format(_totalGeneral),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(controller: _descriptionController, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes ou conditions particulières')),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _genererDocument,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Générer le PDF et Enregistrer'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}