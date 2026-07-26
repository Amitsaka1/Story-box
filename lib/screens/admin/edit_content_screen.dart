import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/category_model.dart';
import 'package:my_app/services/documentary_service.dart';
import 'package:my_app/services/story_service.dart';

enum _ContentType { story, documentary }

/// Admin-only: edit an existing Story or Documentary -- title,
/// category, status, add/remove episodes, replace the cover image.
class EditContentScreen extends StatefulWidget {
  final bool isStory;
  final String id;

  const EditContentScreen({super.key, required this.isStory, required this.id});

  @override
  State<EditContentScreen> createState() => _EditContentScreenState();
}

class _EditContentScreenState extends State<EditContentScreen> {
  final _storyService = StoryService();
  final _documentaryService = DocumentaryService();
  final _picker = ImagePicker();

  late final _ContentType _type = widget.isStory ? _ContentType.story : _ContentType.documentary;

  late Future<void> _loadFuture;

  final _titleController = TextEditingController();
  String? _currentCoverImageUrl;
  Uint8List? _newCoverBytes;
  String? _newCoverFilename;

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  String _status = 'ongoing';

  final List<TextEditingController> _chapterControllers = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _chapterControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final categories = _type == _ContentType.story
        ? await _storyService.fetchCategories()
        : await _documentaryService.fetchDocumentaryCategories();

    String title;
    String categoryId;
    String status;
    String coverImageUrl;
    String contentUrl;

    if (_type == _ContentType.story) {
      final story = await _storyService.fetchStoryById(widget.id);
      title = story.title;
      categoryId = story.categoryId;
      status = story.status;
      coverImageUrl = story.coverImageUrl;
      contentUrl = story.contentUrl;
    } else {
      final documentary = await _documentaryService.fetchDocumentaryById(widget.id);
      title = documentary.title;
      categoryId = documentary.categoryId;
      status = documentary.status;
      coverImageUrl = documentary.coverImageUrl;
      contentUrl = documentary.contentUrl;
    }

    final content = contentUrl.isNotEmpty
        ? (_type == _ContentType.story
            ? await _storyService.fetchStoryContent(contentUrl)
            : await _documentaryService.fetchDocumentaryContent(contentUrl))
        : null;

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _titleController.text = title;
      _selectedCategory = categories.where((c) => c.id == categoryId).isNotEmpty
          ? categories.firstWhere((c) => c.id == categoryId)
          : null;
      _status = status;
      _currentCoverImageUrl = coverImageUrl;
      _chapterControllers.clear();
      if (content != null && content.chapters.isNotEmpty) {
        final sorted = [...content.chapters]..sort((a, b) => a.chapterNo.compareTo(b.chapterNo));
        for (final c in sorted) {
          _chapterControllers.add(TextEditingController(text: c.text));
        }
      } else {
        _chapterControllers.add(TextEditingController());
      }
    });
  }

  Future<void> _pickNewCover() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _newCoverBytes = bytes;
      _newCoverFilename = picked.name;
    });
  }

  void _addChapterField() {
    setState(() => _chapterControllers.add(TextEditingController()));
  }

  void _removeChapterField(int index) {
    if (_chapterControllers.length == 1) return;
    setState(() {
      _chapterControllers[index].dispose();
      _chapterControllers.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.')));
      return;
    }
    final hasEmptyChapter = _chapterControllers.any((c) => c.text.trim().isEmpty);
    if (hasEmptyChapter) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Every chapter needs some text.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final chapters = List.generate(
        _chapterControllers.length,
        (i) => {'chapterNo': i + 1, 'text': _chapterControllers[i].text.trim()},
      );

      if (_type == _ContentType.story) {
        await _storyService.updateStory(
          widget.id,
          title: _titleController.text.trim(),
          categoryId: _selectedCategory!.id,
          status: _status,
          chapters: chapters,
        );
        if (_newCoverBytes != null) {
          await _storyService.replaceCover(widget.id, _newCoverBytes!, _newCoverFilename!);
        }
      } else {
        await _documentaryService.updateDocumentary(
          widget.id,
          title: _titleController.text.trim(),
          categoryId: _selectedCategory!.id,
          status: _status,
          chapters: chapters,
        );
        if (_newCoverBytes != null) {
          await _documentaryService.replaceCover(widget.id, _newCoverBytes!, _newCoverFilename!);
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit ${_type == _ContentType.story ? 'Story' : 'Documentary'}')),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => setState(() => _loadFuture = _load()), child: const Text('Retry')),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<CategoryModel>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (c) => setState(() => _selectedCategory = c),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              Text('Status', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ongoing', label: Text('Ongoing')),
                  ButtonSegment(value: 'completed', label: Text('Completed')),
                ],
                selected: {_status},
                onSelectionChanged: (selection) => setState(() => _status = selection.first),
              ),
              const SizedBox(height: 24),

              Text('Cover image', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _newCoverBytes != null
                    ? Image.memory(_newCoverBytes!, height: 160, fit: BoxFit.cover, width: double.infinity)
                    : Image.network(
                        _currentCoverImageUrl ?? '',
                        height: 160,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) => Container(
                          height: 160,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickNewCover,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Replace cover image'),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Episodes', style: Theme.of(context).textTheme.labelLarge),
                  Text('${_chapterControllers.length} total'),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(_chapterControllers.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Episode ${i + 1}', style: Theme.of(context).textTheme.bodyMedium),
                          const Spacer(),
                          if (_chapterControllers.length > 1)
                            IconButton(
                              onPressed: () => _removeChapterField(i),
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Remove episode',
                            ),
                        ],
                      ),
                      TextField(
                        controller: _chapterControllers[i],
                        maxLines: 6,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _addChapterField,
                icon: const Icon(Icons.add),
                label: const Text('Add episode'),
              ),

              const SizedBox(height: 28),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}
