import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
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
  final List<PdfPageImage?> _pageImages = [];
  final List<PdfEditPage> _pages = [];

  int _currentPageIndex = 0;
  bool _loading = false;
  bool _exporting = false;
  String? _error;

  // Kaunsa element selected hai (border + delete icon dikhta hai) aur
  // kaunsa element abhi text-edit mode me hai (TextField dikhta hai).
  String? _selectedId;
  String? _editingId;

  // Har page ka canvas (image + overlay) isi key se wrap hoga, taaki
  // Step 7 (export) me RepaintBoundary.toImage() se capture kar sakein.
  final GlobalKey _canvasKey = GlobalKey();

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

      _pageImages
        ..clear()
        ..addAll(List<PdfPageImage?>.filled(document.pagesCount, null));
      _pages
        ..clear()
        ..addAll(List.generate(
          document.pagesCount,
          (i) => PdfEditPage(pageNumber: i + 1),
        ));

      // Sirf pehla page turant render karo taaki editor turant khule.
      await _renderPage(document, 0);

      setState(() {
        _document = document;
        _currentPageIndex = 0;
        _loading = false;
      });

      // Baaki pages background me, ek-ek karke render hote rahenge.
      _renderRemainingPages(document);
    } catch (e) {
      setState(() {
        _error = 'PDF open nahi ho paya: $e';
        _loading = false;
      });
    }
  }

  Future<void> _renderPage(PdfDocument document, int index) async {
    final page = await document.getPage(index + 1);
    final rendered = await page.render(
      width: page.width * 1.5,
      height: page.height * 1.5,
      format: PdfPageImageFormat.jpeg,
      quality: 85,
    );
    await page.close();
    if (!mounted || _document != document) return;
    setState(() => _pageImages[index] = rendered);
  }

  Future<void> _renderRemainingPages(PdfDocument document) async {
    for (int i = 1; i < document.pagesCount; i++) {
      if (_document != document) return; // user ne doosri PDF khol li
      await _renderPage(document, i);
    }
  }

  void _addElement() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    setState(() {
      _pages[_currentPageIndex].elements.add(
            PdfEditElement(
              id: id,
              type: BubbleType.caption,
              text: 'Text',
              position: const Offset(80, 80),
            ),
          );
      _selectedId = id;
      _editingId = id;
    });
  }

  void _deleteElement(String id) {
    setState(() {
      _pages[_currentPageIndex].elements.removeWhere((e) => e.id == id);
      if (_selectedId == id) _selectedId = null;
      if (_editingId == id) _editingId = null;
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedId = null;
      _editingId = null;
    });
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length || index == _currentPageIndex) {
      return;
    }
    setState(() {
      _currentPageIndex = index;
      _selectedId = null;
      _editingId = null;
    });
  }

  // Ek page ka bubble/text element ko raw Canvas pe draw karta hai --
  // widget tree ki zaroorat nahi, isliye har page (chahe screen pe
  // dikh raha ho ya na ho) export ke waqt sahi se render ho jaata hai.
  void _drawElementOnCanvas(Canvas canvas, PdfEditElement el) {
    final innerH = el.type == BubbleType.none ? 4.0 : 14.0;
    final innerV = el.type == BubbleType.none ? 4.0 : 10.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: el.text,
        style: TextStyle(fontSize: el.fontSize, color: el.textColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bubbleSize = Size(
      textPainter.width + innerH * 2,
      textPainter.height + innerV * 2,
    );

    // Outer Container ka 4px all-round padding match karne ke liye.
    final stackOrigin = el.position + const Offset(4, 4);

    canvas.save();
    canvas.translate(stackOrigin.dx, stackOrigin.dy);
    _BubblePainter(type: el.type, color: el.bubbleColor).paint(canvas, bubbleSize);
    canvas.restore();

    textPainter.paint(canvas, stackOrigin + Offset(innerH, innerV));
  }

  Future<void> _exportPdf() async {
    if (_document == null || _exporting) return;
    setState(() => _exporting = true);

    try {
      final document = _document!;
      final pdfDoc = pw.Document();

      for (int i = 0; i < _pages.length; i++) {
        var image = _pageImages[i];
        // Agar background render abhi tak complete nahi hua, yahin turant karo.
        if (image == null) {
          await _renderPage(document, i);
          image = _pageImages[i];
        }
        if (image == null) continue;

        final codec = await ui.instantiateImageCodec(image.bytes);
        final frame = await codec.getNextFrame();
        final baseImage = frame.image;

        final width = baseImage.width.toDouble();
        final height = baseImage.height.toDouble();

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

        canvas.drawImage(baseImage, Offset.zero, Paint());
        for (final el in _pages[i].elements) {
          _drawElementOnCanvas(canvas, el);
        }

        final picture = recorder.endRecording();
        final composed = await picture.toImage(width.round(), height.round());
        final pngBytes = await composed.toByteData(format: ui.ImageByteFormat.png);
        if (pngBytes == null) continue;

        final pdfImage = pw.MemoryImage(pngBytes.buffer.asUint8List());
        pdfDoc.addPage(
          pw.Page(
            build: (context) => pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
          ),
        );
      }

      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/story_box_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await outFile.writeAsBytes(await pdfDoc.save());

      if (!mounted) return;
      await Share.shareXFiles([XFile(outFile.path)], text: 'Edited PDF');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export fail ho gaya: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Editor'),
        actions: [
          if (_document != null && !_exporting)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'PDF Export Karo',
              onPressed: _exportPdf,
            ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            ),
          if (_document != null && !_exporting)
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: 'Doosri PDF kholo',
              onPressed: _pickAndOpenPdf,
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _document == null
          ? null
          : FloatingActionButton(
              onPressed: _addElement,
              child: const Icon(Icons.add_comment_outlined),
            ),
      bottomNavigationBar: (_document == null || _pages.length <= 1)
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPageIndex > 0
                          ? () => _goToPage(_currentPageIndex - 1)
                          : null,
                    ),
                    Text('Page ${_currentPageIndex + 1} / ${_pages.length}'),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPageIndex < _pages.length - 1
                          ? () => _goToPage(_currentPageIndex + 1)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
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

    final image = _pageImages[_currentPageIndex];
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final elements = _pages[_currentPageIndex].elements;

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Center(
        child: RepaintBoundary(
          key: _canvasKey,
          child: GestureDetector(
            // Khaali jagah tap karne se selection/edit mode band ho jaye.
            onTap: _deselectAll,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Image.memory(image.bytes),
                for (final el in elements) _buildElement(el),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildElement(PdfEditElement el) {
    final isSelected = _selectedId == el.id;
    final isEditing = _editingId == el.id;

    return Positioned(
      left: el.position.dx,
      top: el.position.dy,
      child: GestureDetector(
        // Editing mode me drag disable, taaki TextField ke andar
        // cursor place karna aasan rahe.
        onPanUpdate: isEditing
            ? null
            : (details) {
                setState(() => el.position += details.delta);
              },
        onTap: () {
          setState(() {
            if (_selectedId != el.id) {
              // Pehla tap: sirf select karo (border + delete icon dikhao).
              _selectedId = el.id;
              _editingId = null;
            } else {
              // Dubara tap (already selected): edit mode me jao.
              _editingId = el.id;
            }
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 1.5),
                    )
                  : null,
              padding: const EdgeInsets.all(4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BubblePainter(type: el.type, color: el.bubbleColor),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: el.type == BubbleType.none ? 4 : 14,
                      vertical: el.type == BubbleType.none ? 4 : 10,
                    ),
                    child: isEditing
                        ? IntrinsicWidth(
                            child: TextField(
                              autofocus: true,
                              controller: TextEditingController(text: el.text)
                                ..selection = TextSelection.collapsed(offset: el.text.length),
                              style: TextStyle(fontSize: el.fontSize, color: el.textColor),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (v) => el.text = v,
                              onSubmitted: (_) => setState(() => _editingId = null),
                              onTapOutside: (_) => setState(() => _editingId = null),
                            ),
                          )
                        : Text(
                            el.text,
                            style: TextStyle(fontSize: el.fontSize, color: el.textColor),
                          ),
                  ),
                ],
              ),
            ),
            if (isSelected && !isEditing)
              Positioned(
                right: -10,
                top: -10,
                child: GestureDetector(
                  onTap: () => _deleteElement(el.id),
                  child: const CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.red,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bubble ka background shape banata hai -- caption ke liye simple
/// rounded box, dialogue ke liye box + neeche tail, thought ke liye
/// oval + chhote bubbles. `none` type ke liye kuch draw nahi hota
/// (sirf plain text upar dikhta hai).
class _BubblePainter extends CustomPainter {
  final BubbleType type;
  final Color color;

  _BubblePainter({required this.type, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (type == BubbleType.none) return;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    switch (type) {
      case BubbleType.none:
        return;

      case BubbleType.caption:
        final rect = RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(6),
        );
        canvas.drawRRect(rect, fillPaint);
        canvas.drawRRect(rect, strokePaint);
        break;

      case BubbleType.dialogue:
        final bodyHeight = size.height - 14;
        final path = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, size.width, bodyHeight),
              const Radius.circular(16),
            ),
          );
        final tail = Path()
          ..moveTo(size.width * 0.22, bodyHeight - 1)
          ..lineTo(size.width * 0.12, size.height)
          ..lineTo(size.width * 0.40, bodyHeight - 1)
          ..close();
        path.addPath(tail, Offset.zero);
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
        break;

      case BubbleType.thought:
        final bodyHeight = size.height - 18;
        final oval = RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, bodyHeight),
          Radius.circular(bodyHeight / 2),
        );
        canvas.drawRRect(oval, fillPaint);
        canvas.drawRRect(oval, strokePaint);

        final bubble1 = Offset(size.width * 0.22, bodyHeight + 6);
        canvas.drawCircle(bubble1, 5, fillPaint);
        canvas.drawCircle(bubble1, 5, strokePaint);

        final bubble2 = Offset(size.width * 0.12, size.height - 2);
        canvas.drawCircle(bubble2, 3, fillPaint);
        canvas.drawCircle(bubble2, 3, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}
