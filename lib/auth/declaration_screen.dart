import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'terms_and_conditions_screen.dart';

class DeclarationScreen extends StatefulWidget {
  const DeclarationScreen({super.key});
  @override State<DeclarationScreen> createState() => _DeclarationScreenState();
}

class _DeclarationScreenState extends State<DeclarationScreen> {
  final SignatureController _signatureController = SignatureController(penStrokeWidth: 3, penColor: Colors.black);
  final GlobalKey _repaintKey = GlobalKey();
  bool _acceptedDeclaration = false;
  bool _acceptedTerms = false;
  List<String> _declarationPoints = [];
  List<Map<String, dynamic>> _termsList = [];
  String? _userName;

  @override void didChangeDependencies() {
    super.didChangeDependencies();
    _userName ??= ModalRoute.of(context)!.settings.arguments as String?;
  }

  @override void initState() {
    super.initState();
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final declDoc = await FirebaseFirestore.instance.collection('declarations').doc('default').get();
      final pp = declDoc.data()?['points'];
      if (pp is List) _declarationPoints = List<String>.from(pp);

      final termSnap = await FirebaseFirestore.instance.collection('terms_and_conditions').orderBy('section').get();
      _termsList = termSnap.docs.map((d) => d.data()).toList();
      setState(() {});
    } catch (e) {
      debugPrint('❗ Firestore error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    }
  }

  @override void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _submitDeclaration() async {
    if (!_acceptedDeclaration || !_acceptedTerms || _signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all required fields')));
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not logged in')));
      return;
    }

    try {
      // Render form to image
      await Future.delayed(const Duration(milliseconds: 100));
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to extract image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Generate PDF
      final pdf = pw.Document();
      final imageProvider = pw.MemoryImage(pngBytes);
      pdf.addPage(pw.Page(build: (pw.Context ctx) {
        return pw.Center(child: pw.Image(imageProvider));
      }));

      // Upload to Firebase Storage
      final pdfBytes = await pdf.save();
      final ref = FirebaseStorage.instance.ref().child('declarations/$uid.pdf');
      final task = await ref.putData(pdfBytes, SettableMetadata(contentType: 'application/pdf'));
      final downloadUrl = await ref.getDownloadURL();

      // Store URL in Firestore
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'declaration_accepted': true,
        'terms_accepted': true,
        'signed_at': DateTime.now().toIso8601String(),
        'declaration_pdf_url': downloadUrl,
      });

      Navigator.pushReplacementNamed(context, '/timetable');

    } catch (e) {
      debugPrint('❗ Submission failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildDeclarationPoint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.circle, size: 6, color: Color(0xFFBDA25B)),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    if (_declarationPoints.isEmpty || _termsList.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RepaintBoundary(
            key: _repaintKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Center(child: Column(children: [
                  const Icon(Icons.assignment, size: 60, color: Color(0xFFBDA25B)),
                  const SizedBox(height: 10),
                  Text('MEMBER DECLARATION', style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  )),
                  const SizedBox(height: 20),
                ])),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    RichText(
                      text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 16), children: [
                        const TextSpan(text: 'I, ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: _userName ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFBDA25B))),
                        const TextSpan(text: ', hereby declare that:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    ..._declarationPoints.map(_buildDeclarationPoint),
                    const SizedBox(height: 20),
                    Text('Date: ${DateFormat('dd MMMM yyyy').format(DateTime.now())}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  ]),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Checkbox(value: _acceptedDeclaration, onChanged: (v) => setState(() => _acceptedDeclaration = v ?? false), activeColor: const Color(0xFFBDA25B)),
                  const Expanded(child: Text('I acknowledge and agree to the above declarations', style: TextStyle(fontSize: 14))),
                ]),
                Row(children: [
                  Checkbox(value: _acceptedTerms, onChanged: (v) => setState(() => _acceptedTerms = v ?? false), activeColor: const Color(0xFFBDA25B)),
                  Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 14), children: [
                    const TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms and Conditions',
                      style: const TextStyle(color: Color(0xFFBDA25B), decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => TermsAndConditionsScreen()));
                        },
                    ),
                    const TextSpan(text: ' of the app'),
                  ]))),
                ]),
                const SizedBox(height: 20),
                const Text('Your Signature:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                  child: Signature(controller: _signatureController, backgroundColor: Colors.grey.shade50),
                ),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => _signatureController.clear(),
                    style: TextButton.styleFrom(foregroundColor: Colors.red, overlayColor: Colors.red.withOpacity(0.1)),
                    child: const Text('Clear Signature'),
                  )
                ]),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  onPressed: _submitDeclaration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFBDA25B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('SUBMIT DECLARATION', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
