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

/// Reader-style vertical scroll editor for building ONE manhwa chapter.
///
/// Flow: pick page images (zero gap, like the real reader) -> set each
/// page's bubble count with "- [n] +" (numbers are cumulative across
/// the whole chapter, assigned in the background) -> pick a language
/// in the panel up top, paste ALL of that language's dialogue at once
/// as "1. ...", "2. ...", "3. ..." and hit Apply -> every numbered line
/// instantly appears as an overlay on its correct page, all at once --
/// no per-bubble popup, no typing directly on the image. Then just
/// scroll through and drag/resize each box into place. Position/size
/// live on the box itself (shared by every language, since a box is
/// one object holding a translations map) -- so once placed for the
/// first language, every other language pasted later reuses that exact
/// spot automatically.
class ManhwaChapterEditorScreen extends StatefulWidget {
  const ManhwaChapterEditorScreen({super.key});

  @override
  State<ManhwaChapterEditorScreen> createState() => _ManhwaChapterEditorScreenState();
}

class _ManhwaChapterEditorScreenState extends State<ManhwaChapterEditorScreen> {
  final _picker = ImagePicker();
  final List<EditablePage> _pages = [];
  final _bulkTextController = TextEditingController();
  String _activeLang = _supportedLanguages.keys.first;

  @override
  void dispose() {
    _bulkTextController.dispose();
    super.dispose();
  }

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

  /// Every box across every page, flattened -- since numbering is
  /// cumulative/global, this is what bulk-apply matches numbers
  /// against, not any single page's list.
  List<EditableTextBox> get _allBoxes => _pages.expand((p) => p.textBoxes).toList();

  /// Parses "1. text\n2. text\n3. text..." (each entry can also span
  /// multiple lines -- anything before the next "N." marker is
  /// appended to the current entry) into {number: text}.
  Map<int, String> _parseBulkText(String raw) {
    final result = <int, String>{};
    int? currentNumber;
    final buffer = StringBuffer();

    void flush() {
      if (currentNumber != null) {
        result[currentNumber!] = buffer.toString().trim();
      }
      buffer.clear();
    }

    final lineMatcher = RegExp(r'^\s*(\d+)\.\s*(.*)$');
    for (final line in raw.split('\n')) {
      final match = lineMatcher.firstMatch(line);
      if (match != null) {
        flush();
        currentNumber = int.parse(match.group(1)!);
        buffer.write(match.group(2) ?? '');
      } else if (currentNumber != null) {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(line.trim());
      }
    }
    flush();
    return result;
  }

  void _applyBulkText() {
    final parsed = _parseBulkText(_bulkTextController.text);
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No numbered lines found -- format each line as "1. dialogue text".')),
      );
      return;
    }

    final boxesByNumber = {for (final box in _allBoxes) box.number: box};
    var appliedCount = 0;
    setState(() {
      parsed.forEach((number, text) {
        final box = boxesByNumber[number];
        if (box == null || text.isEmpty) return;
        box.translations[_activeLang] = text;
        box.primaryLang ??= _activeLang; // first language ever filled owns the position
        appliedCount++;
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied text to $appliedCount bubble(s) for ${_supportedLanguages[_activeLang]}.')),
    );
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
      body: Column(
        children: [
          _BulkTextPanel(
            activeLang: _activeLang,
            controller: _bulkTextController,
            onLangChanged: (lang) => setState(() => _activeLang = lang),
            onApply: _applyBulkText,
          ),
          Expanded(
            child: _pages.isEmpty
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
                      previewLang: _activeLang,
                      onCountChanged: (delta) => _changeBubbleCount(index, delta),
                      onBoxMoved: () => setState(() {}),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Fixed panel at the top: pick which language you're currently
/// pasting, paste all numbered lines for it, hit Apply. Collapsible so
/// it doesn't eat scroll space while you're busy dragging boxes.
class _BulkTextPanel extends StatefulWidget {
  final String activeLang;
  final TextEditingController controller;
  final void Function(String lang) onLangChanged;
  final VoidCallback onApply;

  const _BulkTextPanel({
    required this.activeLang,
    required this.controller,
    required this.onLangChanged,
    required this.onApply,
  });

  @override
  State<_BulkTextPanel> createState() => _BulkTextPanelState();
}

class _BulkTextPanelState extends State<_BulkTextPanel> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.activeLang,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    items: _supportedLanguages.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (lang) {
                      if (lang != null) widget.onLangChanged(lang);
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  tooltip: _expanded ? 'Collapse' : 'Expand',
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              TextField(
                controller: widget.controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '1. Kya tum sach me aaogi?\n2. Haan zaroor.\n3. Toh theek hai.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: widget.onApply,
                  icon: const Icon(Icons.check),
                  label: const Text('Apply to bubbles'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One page: the image, its bubble counter overlay, and every text-box
/// marker (draggable by its body, resizable by its bottom-right
/// handle). No tap-to-edit anymore -- text comes from the bulk panel;
/// this view is purely for positioning/sizing what was just pasted.
class _EditablePageView extends StatelessWidget {
  final EditablePage page;
  final String previewLang;
  final void Function(int delta) onCountChanged;
  final VoidCallback onBoxMoved;

  const _EditablePageView({
    required this.page,
    required this.previewLang,
    required this.onCountChanged,
    required this.onBoxMoved,
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
                previewLang: previewLang,
                pageWidth: constraints.maxWidth,
                onChanged: onBoxMoved,
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

/// A single bubble marker: drag its body to move it, drag its
/// bottom-right handle to resize it. Shows whatever text exists for
/// [previewLang] (falling back to any available language) so you can
/// see what you're positioning. x/y/width/height are fractions of
/// [pageWidth] -- resolution independent, shared across every
/// language automatically since they live on the same box object.
class _DraggableTextBox extends StatelessWidget {
  final EditableTextBox box;
  final String previewLang;
  final double pageWidth;
  final VoidCallback onChanged;

  const _DraggableTextBox({
    required this.box,
    required this.previewLang,
    required this.pageWidth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // First time this box is rendered with no size set yet, give it a
    // sane default so it's visible and immediately draggable.
    if (box.width == 0) box.width = 0.35;
    if (box.height == 0) box.height = 0.08;

    final previewText = box.translations[previewLang] ??
        (box.translations.isNotEmpty ? box.translations.values.first : '#${box.number}');

    return Positioned(
      left: box.x * pageWidth,
      top: box.y * pageWidth,
      width: box.width * pageWidth,
      height: box.height * pageWidth,
      child: GestureDetector(
        onPanUpdate: (details) {
          box.x += details.delta.dx / pageWidth;
          box.y += details.delta.dy / pageWidth;
          onChanged();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              // Dashed-look editor guide only -- this border never
              // renders on the actual reader/published page, it just
              // shows the admin where the text will sit.
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orangeAccent, width: 1.5),
                color: Colors.orangeAccent.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(2),
              child: Text(
                previewText,
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
