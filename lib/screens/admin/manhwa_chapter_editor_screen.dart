import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/manhwa_editor_models.dart';

/// Reader-style vertical scroll editor for building ONE manhwa chapter:
/// pick page images (zero gap between them, like the actual reader),
/// then set how many bubbles each page has with a "- [n] +" counter.
/// Numbers themselves are never shown/typed here -- renumberPages()
/// assigns them cumulatively across the whole chapter in the
/// background (used later by the text-box + bulk-text steps).
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
              itemBuilder: (context, index) {
                final page = _pages[index];
                return Stack(
                  children: [
                    // Zero gap: full-width image, no margin/padding, no
                    // rounded corners between consecutive pages so the
                    // whole chapter reads as one continuous strip.
                    Image.memory(page.bytes!, width: double.infinity, fit: BoxFit.fitWidth),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _BubbleCounter(
                        count: page.bubbleCount,
                        onDecrement: () => _changeBubbleCount(index, -1),
                        onIncrement: () => _changeBubbleCount(index, 1),
                      ),
                    ),
                  ],
                );
              },
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
