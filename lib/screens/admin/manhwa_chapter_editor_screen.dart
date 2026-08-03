import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/manhwa_editor_models.dart';

/// Languages the admin panel currently supports. Extend this map to
/// add more -- nothing else needs to change.
const _supportedLanguages = <String, String>{
  'en': 'English',
  'hi': 'Hindi',
  'ko': 'Korean',
  'ja': 'Japanese',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
};

/// Reader-style vertical scroll editor for building ONE manhwa chapter:
/// pick page images (zero gap between them, like the actual reader),
/// set how many bubbles each page has, then drag/resize + type text
/// into each bubble marker. Numbers themselves are never shown/typed --
/// renumberPages() assigns them cumulatively in the background.
class ManhwaChapterEditorScreen extends StatefulWidget {
  const ManhwaChapterEditorScreen({super.key});

  @override
  State<ManhwaChapterEditorScreen> createState() => _ManhwaChapterEditorScreenState();
}

class _ManhwaChapterEditorScreenState extends State<ManhwaChapterEditorScreen> {
  final _picker = ImagePicker();
  final List<EditablePage> _pages = [];

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;

    final newPages = <EditablePage>[];
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      newPages.add(EditablePage(
        localId: '${DateTime.now().microsecondsSinceEpoch}_${newPages.length}',
        bytes: bytes,
        filename: file.name,
      ));
    }

    setState(() {
      _pages.addAll(newPages);
      renumberPages(_pages);
    });
  }

  void _changeBubbleCount(int index, int delta) {
    setState(() {
      final page = _pages[index];
      page.bubbleCount = (page.bubbleCount + delta).clamp(0, 20);
      renumberPages(_pages);
    });
  }

  Future<void> _editBoxText(EditableTextBox box) async {
    final result = await showDialog<_BubbleDialogResult>(
      context: context,
      builder: (context) => _BubbleTextDialog(box: box),
    );
    if (result == null) return;
    setState(() {
      box.primaryLang = result.primaryLang;
      box.translations
        ..clear()
        ..addAll(result.translations);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manhwa Chapter Editor'),
        actions: [
          IconButton(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Upload images',
          ),
        ],
      ),
      body: _pages.isEmpty
          ? Center(
              child: OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload page images'),
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _pages.length,
              itemBuilder: (context, index) => _EditablePageView(
                page: _pages[index],
                onCountChanged: (delta) => _changeBubbleCount(index, delta),
                onBoxMoved: () => setState(() {}),
                onBoxTapped: _editBoxText,
              ),
            ),
    );
  }
}

/// One page: the image, its bubble counter overlay, and every text-box
/// marker (draggable by its body, resizable by its bottom-right handle).
/// Coordinates are fractions (0.0-1.0) of this page's own rendered
/// size -- resolution independent, and trivially reproducible on the
/// reader side regardless of screen width.
class _EditablePageView extends StatelessWidget {
  final EditablePage page;
  final void Function(int delta) onCountChanged;
  final VoidCallback onBoxMoved;
  final void Function(EditableTextBox box) onBoxTapped;

  const _EditablePageView({
    required this.page,
    required this.onCountChanged,
    required this.onBoxMoved,
    required this.onBoxTapped,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Image.memory(page.bytes!, width: double.infinity, fit: BoxFit.fitWidth),
            for (final box in page.textBoxes)
              _DraggableTextBox(
                box: box,
                pageWidth: constraints.maxWidth,
                onChanged: onBoxMoved,
                onTap: () => onBoxTapped(box),
              ),
            Positioned(
              right: 12,
              bottom: 12,
              child: _BubbleCounter(
                count: page.bubbleCount,
                onDecrement: () => onCountChanged(-1),
                onIncrement: () => onCountChanged(1),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single bubble marker: tap to edit its text, drag its body to move
/// it, drag its bottom-right handle to resize it. x/y/width/height on
/// [box] are fractions of [pageWidth] (height uses the same fraction
/// scale, i.e. a "square" fraction system, which is fine since these
/// are just editor-time coordinates, not the rendered image height).
class _DraggableTextBox extends StatelessWidget {
  final EditableTextBox box;
  final double pageWidth;
  final VoidCallback onChanged;
  final VoidCallback onTap;

  const _DraggableTextBox({
    required this.box,
    required this.pageWidth,
    required this.onChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // First time this box is rendered with no size set yet, give it a
    // sane default so it's visible and immediately draggable.
    if (box.width == 0) box.width = 0.35;
    if (box.height == 0) box.height = 0.08;

    return Positioned(
      left: box.x * pageWidth,
      top: box.y * pageWidth,
      width: box.width * pageWidth,
      height: box.height * pageWidth,
      child: GestureDetector(
        onTap: onTap,
        onPanUpdate: (details) {
          box.x += details.delta.dx / pageWidth;
          box.y += details.delta.dy / pageWidth;
          onChanged();
        },
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orangeAccent, width: 2),
                color: Colors.orangeAccent.withValues(alpha: 0.15),
              ),
              alignment: Alignment.center,
              child: Text(
                box.translations.values.isNotEmpty ? box.translations.values.first : '#${box.number}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (details) {
                  box.width += details.delta.dx / pageWidth;
                  box.height += details.delta.dy / pageWidth;
                  if (box.width < 0.05) box.width = 0.05;
                  if (box.height < 0.03) box.height = 0.03;
                  onChanged();
                },
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(color: Colors.orangeAccent, shape: BoxShape.circle),
                  child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "- [n] +" control overlaid on each page image.
class _BubbleCounter extends StatelessWidget {
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _BubbleCounter({required this.count, required this.onDecrement, required this.onIncrement});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove, color: Colors.white, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _BubbleDialogResult {
  final String? primaryLang;
  final Map<String, String> translations;
  _BubbleDialogResult({required this.primaryLang, required this.translations});
}

/// Edits every language's text for ONE bubble. The first language row
/// (index 0) is the "primary" -- it owns the drag/resize position on
/// the page. Every language added after via "+ Add language" shares
/// that exact same position; only the text content differs, and font
/// size will auto-shrink per-language at render time (a later step) so
/// nothing overflows the shared box.
class _BubbleTextDialog extends StatefulWidget {
  final EditableTextBox box;
  const _BubbleTextDialog({required this.box});

  @override
  State<_BubbleTextDialog> createState() => _BubbleTextDialogState();
}

class _BubbleTextDialogState extends State<_BubbleTextDialog> {
  late List<String> _langOrder;
  late Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _langOrder = widget.box.translations.keys.toList();
    if (widget.box.primaryLang != null && _langOrder.remove(widget.box.primaryLang)) {
      _langOrder.insert(0, widget.box.primaryLang!);
    }
    if (_langOrder.isEmpty) _langOrder.add(_supportedLanguages.keys.first);
    _controllers = {
      for (final lang in _langOrder) lang: TextEditingController(text: widget.box.translations[lang]),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addLanguageRow() {
    final available = _supportedLanguages.keys.where((l) => !_langOrder.contains(l)).toList();
    if (available.isEmpty) return;
    setState(() {
      final lang = available.first;
      _langOrder.add(lang);
      _controllers[lang] = TextEditingController();
    });
  }

  void _removeLanguageRow(String lang) {
    if (_langOrder.first == lang && _langOrder.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remove the other languages first before removing the primary one.')),
      );
      return;
    }
    setState(() {
      _langOrder.remove(lang);
      _controllers.remove(lang)?.dispose();
    });
  }

  void _changeLanguageAt(int index, String newLang) {
    setState(() {
      final oldLang = _langOrder[index];
      final controller = _controllers.remove(oldLang)!;
      _langOrder[index] = newLang;
      _controllers[newLang] = controller;
    });
  }

  void _save() {
    final translations = <String, String>{};
    for (final lang in _langOrder) {
      final text = _controllers[lang]!.text.trim();
      if (text.isNotEmpty) translations[lang] = text;
    }
    Navigator.of(context).pop(
      _BubbleDialogResult(
        primaryLang: translations.isEmpty ? null : _langOrder.first,
        translations: translations,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bubble #${widget.box.number}'),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _langOrder.length; i++) _buildLanguageRow(i),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _addLanguageRow,
                icon: const Icon(Icons.add),
                label: const Text('Add language'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }

  Widget _buildLanguageRow(int index) {
    final lang = _langOrder[index];
    final isPrimary = index == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: lang,
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  items: _supportedLanguages.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (newLang) {
                    if (newLang == null || newLang == lang) return;
                    _changeLanguageAt(index, newLang);
                  },
                ),
              ),
              if (isPrimary)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: "Primary -- owns this bubble's position",
                    child: Icon(Icons.star, color: Colors.amber),
                  ),
                ),
              if (!isPrimary)
                IconButton(onPressed: () => _removeLanguageRow(lang), icon: const Icon(Icons.close, size: 18)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _controllers[lang],
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Dialogue text...', border: OutlineInputBorder()),
          ),
        ],
      ),
    );
  }
}
