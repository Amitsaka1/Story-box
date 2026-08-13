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

  // Kaunsa element selected hai (border + delete/resize/type-toolbar
  // dikhta hai) aur kaunsa element abhi text-edit mode me hai (TextField
  // dikhta hai).
  String? _selectedId;
  String? _editingId;

  // Jab tak koi element drag/resize ho raha hai, InteractiveViewer ka
  // apna pan gesture disable rehta hai -- warna dono gesture aapas me
  // fight karte hain aur bubble move karne ki jagah poora page pan
  // ho jaata hai.
  String? _draggingElementId;

  // Zoom/scale track karne ke liye -- drag delta ko current scale se
  // divide karna padta hai warna zoom-in karne par bubble finger se
  // zyada/kam move hota hai.
  final TransformationController _transformationController =
      TransformationController();
  double get _currentScale =>
      _transformationController.value.getMaxScaleOnAxis();

  // Har text element ka apna TextEditingController -- id se persist
  // hota hai taaki har rebuild par naya controller na bane (jo cursor
  // position glitch karta tha).
  final Map<String, TextEditingController> _textControllers = {};

  // Har page ka canvas (image + overlay) isi key se wrap hoga, taaki
  // Step 7 (export) me RepaintBoundary.toImage() se capture kar sakein.
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void dispose() {
    _document?.close();
    _transformationController.dispose();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(PdfEditElement el) {
    return _textControllers.putIfAbsent(
      el.id,
      () => TextEditingController(text: el.text),
    );
  }

  void _enterEditMode(PdfEditElement el) {
    final controller = _controllerFor(el);
    controller.text = el.text;
    controller.selection = TextSelection.collapsed(offset: el.text.length);
    _editingId = el.id;
    _growBoxIfTextOverflows(el);
  }

  // Agar current text, minimum font size (8) par bhi box ki height me
  // fit nahi hota, to box ki height apne aap thodi badha do. Isse text
  // kabhi bhi TextField ke andar "chhup" (internally scroll ho kar
  // hide) nahi hota -- box hamesha itna bada rehta hai ki poora text
  // dikhe. Export bhi isi el.height ko use karta hai, isliye jo UI me
  // dikhta hai wahi PDF me bhi aata hai.
  void _growBoxIfTextOverflows(PdfEditElement el) {
    const double minFontSize = 8;
    final innerH = el.type == BubbleType.none ? 4.0 : 14.0;
    final innerV = el.type == BubbleType.none ? 4.0 : 10.0;
    final availW = (el.width - innerH * 2).clamp(10.0, double.infinity);

    final content = el.text.isEmpty ? ' ' : el.text;
    final tp = TextPainter(
      text: TextSpan(text: content, style: const TextStyle(fontSize: minFontSize)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: availW);

    // Thoda extra buffer (4px) taaki TextField ke apne internal padding
    // se bhi na takraaye.
    final requiredHeight = tp.height + innerV * 2 + 4;
    if (requiredHeight > el.height) {
      el.height = requiredHeight.clamp(30.0, 700.0);
    }
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
    final el = PdfEditElement(
      id: id,
      type: BubbleType.caption,
      text: 'Text',
      position: const Offset(80, 80),
    );
    setState(() {
      _pages[_currentPageIndex].elements.add(el);
      _selectedId = id;
      _enterEditMode(el);
    });
  }

  void _deleteElement(String id) {
    setState(() {
      _pages[_currentPageIndex].elements.removeWhere((e) => e.id == id);
      if (_selectedId == id) _selectedId = null;
      if (_editingId == id) _editingId = null;
      if (_draggingElementId == id) _draggingElementId = null;
      _textControllers.remove(id)?.dispose();
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

  IconData _iconForType(BubbleType type) {
    switch (type) {
      case BubbleType.caption:
        return Icons.crop_square;
      case BubbleType.dialogue:
        return Icons.chat_bubble_outline;
      case BubbleType.thought:
        return Icons.cloud_outlined;
      case BubbleType.none:
        return Icons.text_fields;
    }
  }

  // Diye gaye box (maxWidth x maxHeight) ke andar text ko wrap karke
  // sabse bada font size dhoondta hai jisse text poore box me fit ho
  // jaaye -- na to horizontal me overflow ho, na box se bahar jaaye.
  // Chota text bhi box ke hisab se bada font paayega, bada text apne
  // aap chhota font le lega. Ye hi function UI aur PDF export dono me
  // use hota hai taaki dono ek jaisa dikhein.
  double _fitFontSize({
    required String text,
    required double maxWidth,
    required double maxHeight,
    double minFontSize = 8,
    double maxFontSize = 34,
  }) {
    final content = text.isEmpty ? ' ' : text;
    bool fits(double fontSize) {
      final tp = TextPainter(
        text: TextSpan(text: content, style: TextStyle(fontSize: fontSize)),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: maxWidth);
      return tp.height <= maxHeight;
    }

    if (fits(maxFontSize)) return maxFontSize;
    if (!fits(minFontSize)) return minFontSize;

    double lo = minFontSize;
    double hi = maxFontSize;
    while (hi - lo > 0.5) {
      final mid = (lo + hi) / 2;
      if (fits(mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  // Ek page ka bubble/text element ko raw Canvas pe draw karta hai --
  // widget tree ki zaroorat nahi, isliye har page (chahe screen pe
  // dikh raha ho ya na ho) export ke waqt sahi se render ho jaata hai.
  // Bubble ka size hamesha el.width x el.height (fixed) hota hai --
  // text usi ke andar wrap + auto-fit hota hai, exact UI jaisa.
  void _drawElementOnCanvas(Canvas canvas, PdfEditElement el) {
    final innerH = el.type == BubbleType.none ? 4.0 : 14.0;
    final innerV = el.type == BubbleType.none ? 4.0 : 10.0;
    final availW = (el.width - innerH * 2).clamp(10.0, double.infinity);
    final availH = (el.height - innerV * 2).clamp(10.0, double.infinity);

    final fontSize = _fitFontSize(text: el.text, maxWidth: availW, maxHeight: availH);

    final textPainter = TextPainter(
      text: TextSpan(
        text: el.text,
        style: TextStyle(fontSize: fontSize, color: el.textColor),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: availW);

    final bubbleSize = Size(el.width, el.height);

    canvas.save();
    canvas.translate(el.position.dx, el.position.dy);
    _BubblePainter(type: el.type, color: el.bubbleColor).paint(canvas, bubbleSize);
    canvas.restore();

    final textX = el.position.dx + innerH + (availW - textPainter.width) / 2;
    final textY = el.position.dy + innerV + (availH - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));
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
      transformationController: _transformationController,
      // Jab tak koi bubble drag/resize ho raha hai, page ka apna pan
      // disable -- warna dono gesture aapas me clash karte hain.
      panEnabled: _draggingElementId == null,
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

    final innerH = el.type == BubbleType.none ? 4.0 : 14.0;
    final innerV = el.type == BubbleType.none ? 4.0 : 10.0;
    final availW = (el.width - innerH * 2).clamp(10.0, double.infinity);
    final availH = (el.height - innerV * 2).clamp(10.0, double.infinity);
    final fitFontSize = _fitFontSize(text: el.text, maxWidth: availW, maxHeight: availH);

    // --- Hit-test fix ---------------------------------------------------
    // Pehle toolbar/delete/resize Positioned(left/right/top/bottom: -10
    // ya -38) jaise negative offsets se bubble-box ke BAAHAR paint ho
    // rahe the. `clipBehavior: Clip.none` unhe VISUALLY dikhata to hai,
    // lekin Flutter ka hit-testing hamesha parent Stack ke apne size
    // (yaani sirf el.width x el.height) tak hi kaam karta hai -- jo bhi
    // us box ke bahar paint hota hai wahan tap register hi nahi hota,
    // tap seedha neeche wale canvas tak chala jaata hai. Isi wajah se
    // ye teeno control "dikhte the par kaam nahi karte the".
    //
    // Fix: ab poore element ke around ek invisible margin add kar diya
    // hai (top/side/bottom space) aur bubble-box ko us margin ke andar
    // Positioned kiya hai. Toolbar/delete/resize ab is margin ke andar
    // hi (non-negative offsets se) paint hote hain, isliye Stack ka
    // hit-testable area unhe bhi cover karta hai aur taps reliably
    // fire hote hain.
    const double topSpace = 50.0; // toolbar (upar) ke liye jagah
    const double bottomSpace = 20.0; // resize handle (neeche) ke liye
    const double sideSpaceBase = 20.0; // delete/resize (dayen) ke liye
    // Toolbar me 4 icons hote hain -- agar bubble bahut patla (narrow)
    // resize kiya gaya ho to toolbar uski width se bada ho sakta hai,
    // isliye zaroorat padne par side-space aur badha do taaki toolbar
    // bhi hamesha hit-test area ke andar hi rahe.
    const double toolbarWidth = 8 + 4 * 29.0;
    final double extraForToolbar =
        (toolbarWidth - el.width).clamp(0.0, double.infinity);
    final double sideSpace = sideSpaceBase + extraForToolbar;

    return Positioned(
      left: el.position.dx - sideSpace,
      top: el.position.dy - topSpace,
      child: SizedBox(
        width: el.width + sideSpace * 2,
        height: el.height + topSpace + bottomSpace,
        child: Stack(
        clipBehavior: Clip.none,
        children: [
          // --- Move + select/edit area: SIRF bubble body tak scoped hai,
          // taaki delete/resize/type buttons is drag-gesture ke andar
          // na aayein aur unke taps humesha reliably fire hon. ---
          Positioned(
            left: sideSpace,
            top: topSpace,
            child: GestureDetector(
            onPanStart: isEditing
                ? null
                : (_) => setState(() => _draggingElementId = el.id),
            onPanUpdate: isEditing
                ? null
                : (details) {
                    setState(() => el.position += details.delta / _currentScale);
                  },
            onPanEnd: (_) => setState(() => _draggingElementId = null),
            onPanCancel: () => setState(() => _draggingElementId = null),
            onTap: () {
              setState(() {
                if (_selectedId != el.id) {
                  // Pehla tap: sirf select karo (border + toolbar dikhao).
                  _selectedId = el.id;
                  _editingId = null;
                } else {
                  // Dubara tap (already selected): edit mode me jao.
                  _enterEditMode(el);
                }
              });
            },
            child: Container(
              width: el.width,
              height: el.height,
              decoration: isSelected
                  ? BoxDecoration(
                      border: Border.all(color: Colors.blueAccent, width: 1.5),
                    )
                  : null,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BubblePainter(type: el.type, color: el.bubbleColor),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: innerH, vertical: innerV),
                    child: Center(
                      child: isEditing
                          ? TextField(
                              autofocus: true,
                              controller: _controllerFor(el),
                              maxLines: null,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: fitFontSize, color: el.textColor),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() {
                                el.text = v;
                                _growBoxIfTextOverflows(el);
                              }),
                              onSubmitted: (_) => setState(() => _editingId = null),
                              onTapOutside: (_) => setState(() => _editingId = null),
                            )
                          : Text(
                              el.text,
                              textAlign: TextAlign.center,
                              softWrap: true,
                              style: TextStyle(fontSize: fitFontSize, color: el.textColor),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),

          // --- Selection-only controls: har ek APNA gesture detector
          // leke bubble-move detector ke BAAHAR (sibling) baitha hai,
          // isliye inka tap kabhi bhi drag-gesture se clash nahi karta.
          // Ab in sabke offsets non-negative hain (sideSpace/topSpace
          // margin ke andar), isliye ye hamesha hit-testable rehte hain. ---
          if (isSelected && !isEditing) ...[
            // Type switcher toolbar (caption / dialogue / thought / none)
            Positioned(
              left: sideSpace,
              top: topSpace - 38,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: BubbleType.values.map((t) {
                    final active = el.type == t;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => el.type = t),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: active ? Colors.blueAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(_iconForType(t), size: 15, color: Colors.white),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Delete button
            Positioned(
              left: sideSpace + el.width - 12,
              top: topSpace - 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _deleteElement(el.id),
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: Colors.red,
                  child: Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),

            // Resize handle -- bottom-right corner se drag karke
            // bubble ka width/height badhao-ghataao.
            Positioned(
              left: sideSpace + el.width - 12,
              top: topSpace + el.height - 10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() => _draggingElementId = el.id),
                onPanUpdate: (details) {
                  final scale = _currentScale;
                  setState(() {
                    el.width = (el.width + details.delta.dx / scale).clamp(40.0, 700.0);
                    el.height = (el.height + details.delta.dy / scale).clamp(30.0, 700.0);
                    _growBoxIfTextOverflows(el);
                  });
                },
                onPanEnd: (_) => setState(() => _draggingElementId = null),
                onPanCancel: () => setState(() => _draggingElementId = null),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
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
    return oldDelegate.type != type ||
        oldDelegate.color != color;
  }
}
