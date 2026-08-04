import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/services/story_service.dart';

/// One picked page image, waiting to be uploaded.
class _PickedPage {
  final String localId;
  final Uint8List bytes;
  final String filename;

  _PickedPage({required this.localId, required this.bytes, required this.filename});
}

/// Fully-ready-episode upload screen: pick every page image for one
/// chapter (in reading order), preview them stacked with zero gap
/// (exactly like the reader will show them), reorder/remove as needed,
/// then hit "Upload Chapter" -- each image goes to R2 via
/// uploadPageImage(), and the resulting {chapterNo, pages: [...]} map
/// is popped back to whoever pushed this screen.
class ManhwaChapterUploadScreen extends StatefulWidget {
  final int chapterNo;
  const ManhwaChapterUploadScreen({super.key, required this.chapterNo});

  @override
  State<ManhwaChapterUploadScreen> createState() => _ManhwaChapterUploadScreenState();
}

class _ManhwaChapterUploadScreenState extends State<ManhwaChapterUploadScreen> {
  final _picker = ImagePicker();
  final _storyService = StoryService();
  final List<_PickedPage> _pages = [];
  bool _uploading = false;
  String? _uploadProgress;

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty) return;

    final newPages = <_PickedPage>[];
    for (final file in picked) {
      final bytes = await file.readAsBytes();
      newPages.add(_PickedPage(
        localId: '${DateTime.now().microsecondsSinceEpoch}_${newPages.length}',
        bytes: bytes,
        filename: file.name,
      ));
    }
    setState(() => _pages.addAll(newPages));
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  void _reorderPage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
    });
  }

  Future<void> _uploadChapter() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one page before uploading.')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      final uploadedPages = <Map<String, dynamic>>[];
      for (var i = 0; i < _pages.length; i++) {
        setState(() => _uploadProgress = 'Uploading page ${i + 1} of ${_pages.length}...');
        final imageUrl = await _storyService.uploadPageImage(_pages[i].bytes, _pages[i].filename);
        uploadedPages.add({'pageNo': i + 1, 'imageUrl': imageUrl});
      }

      final chapterData = {'chapterNo': widget.chapterNo, 'pages': uploadedPages};

      if (!mounted) return;
      Navigator.of(context).pop(chapterData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${widget.chapterNo} -- Upload Pages'),
        actions: [
          IconButton(
            onPressed: _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Add pages',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _pages.isEmpty
                ? Center(
                    child: OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Select page images'),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _pages.length,
                    onReorder: _reorderPage,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return Stack(
                        key: ValueKey(page.localId),
                        children: [
                          // Zero gap: full-width image, no margin/padding
                          // between consecutive pages -- reads as one
                          // continuous strip, exactly like the reader.
                          Image.memory(page.bytes, width: double.infinity, fit: BoxFit.fitWidth),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: _PageBadge(number: index + 1),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _RemoveButton(onTap: () => _removePage(index)),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _uploading ? null : _uploadChapter,
                icon: _uploading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(_uploading ? (_uploadProgress ?? 'Uploading...') : 'Upload Chapter ${widget.chapterNo}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small page-number badge, top-left of each page (helps confirm
/// reading order while reordering).
class _PageBadge extends StatelessWidget {
  final int number;
  const _PageBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(12)),
      child: Text('#$number', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

/// Small remove (x) button, top-right of each page.
class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RemoveButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), shape: BoxShape.circle),
        child: const Icon(Icons.close, size: 16, color: Colors.white),
      ),
    );
  }
}
