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
      floatingActionButton: _document == null
          ? null
          : FloatingActionButton(
              onPressed: _addElement,
              child: const Icon(Icons.add_comment_outlined),
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
      return const Center(child: Text('Page render nahi ho paya.'));
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
