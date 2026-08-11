import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdfx/pdfx.dart';
import 'package:my_app/models/pdf_edit_element_model.dart';

/// Admin-only: koi bhi PDF open karke uske upar bubbles/captions
/// overlay karke naya PDF export karne ka screen. Real PDF content
/// kabhi edit nahi hota -- har page image ke roop me render hota hai
/// aur uske upar hamara editable canvas layer baithta hai.
class PdfEditScreen extends StatefulWidget {
  const PdfEditScreen({super.key});

  @override
  State<PdfEditScreen> createState() => _PdfEditScreenState();
}

class _PdfEditScreenState extends State<PdfEditScreen> {
  PdfDocument? _document;
  final List<PdfImage?> _pageImages = [];
  final List<PdfEditPage> _pages = [];

  int _currentPageIndex = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  Future<void> _pickAndOpenPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final path = result.files.single.path!;
      final document = await PdfDocument.openFile(path);

      _pageImages.clear();
      _pages.clear();

      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        final rendered = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();
        _pageImages.add(rendered);
        _pages.add(PdfEditPage(pageNumber: i));
      }

      setState(() {
        _document = document;
        _currentPageIndex = 0;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'PDF open nahi ho paya: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Editor'),
        actions: [
          if (_document != null)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Doosri PDF kholo',
              onPressed: _pickAndOpenPdf,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_document == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _pickAndOpenPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('PDF Select Karo'),
        ),
      );
    }

    // Abhi sirf current page ka rendered image dikha rahe hain.
    // Overlay canvas (bubbles/text) Step 4 me isi jagah add hoga.
    final image = _pageImages[_currentPageIndex];
    if (image == null) {
      return const Center(child: Text('Page render nahi ho paya.'));
    }

    return Center(
      child: Image.memory(image.bytes),
    );
  }
}
