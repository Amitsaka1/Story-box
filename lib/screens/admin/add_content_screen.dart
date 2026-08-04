import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:my_app/models/category_model.dart';
import 'package:my_app/screens/admin/manhwa_chapter_upload_screen.dart';
import 'package:my_app/services/documentary_service.dart';
import 'package:my_app/services/story_service.dart';

enum _ContentType { manhwa, documentary }

/// Admin-only screen to add new content. Manhwa and Documentary use the
/// EXACT same flow: category select + title + cover image (file) +
/// episodes (each episode = one set of fully-ready page images,
/// uploaded via ManhwaChapterUploadScreen) + ongoing/completed status.
/// Only which service gets called (and which category list is used)
/// differs.
class AddContentScreen extends StatefulWidget {
  const AddContentScreen({super.key});

  @override
  State<AddContentScreen> createState() => _AddContentScreenState();
}

class _AddContentScreenState extends State<AddContentScreen> {
  final _storyService = StoryService();
  final _documentaryService = DocumentaryService();
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();

  final _picker = ImagePicker();
  Uint8List? _coverBytes;
  String? _coverFilename;

  // Each entry is exactly the {chapterNo, pages: [{pageNo, imageUrl}]}
  // shape returned by ManhwaChapterUploadScreen -- ready to send as-is.
  final List<Map<String, dynamic>> _episodes = [];

  _ContentType _type = _ContentType.manhwa;
  late Future<List<CategoryModel>> _categoriesFuture;
  CategoryModel? _selectedCategory;
  String _status = 'ongoing';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _fetchCategoriesForType();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<List<CategoryModel>> _fetchCategoriesForType() {
    return _type == _ContentType.manhwa
        ? _storyService.fetchCategories()
        : _documentaryService.fetchDocumentaryCategories();
  }

  Future<void> _pickCoverImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _coverBytes = bytes;
      _coverFilename = picked.name;
    });
  }

  Future<void> _addEpisode() async {
    final nextChapterNo = _episodes.length + 1;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => ManhwaChapterUploadScreen(chapterNo: nextChapterNo)),
    );
    if (result == null) return;
    setState(() => _episodes.add(result));
  }

  Future<void> _editEpisode(int index) async {
    final chapterNo = _episodes[index]['chapterNo'] as int;
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => ManhwaChapterUploadScreen(chapterNo: chapterNo)),
    );
    if (result == null) return;
    setState(() => _episodes[index] = result);
  }

  void _removeEpisode(int index) {
    setState(() {
      _episodes.removeAt(index);
      // Keep chapterNo sequential after a removal -- pages already
      // uploaded to R2 don't need re-uploading, only the number label
      // shifts down.
      for (var i = 0; i < _episodes.length; i++) {
        _episodes[i]['chapterNo'] = i + 1;
      }
    });
  }

  Future<void> _refreshCategories({CategoryModel? autoSelect}) async {
    final future = _fetchCategoriesForType();
    setState(() => _categoriesFuture = future);
    final categories = await future;
    if (!mounted) return;
    setState(() {
      _selectedCategory = autoSelect ?? (categories.contains(_selectedCategory) ? _selectedCategory : null);
    });
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Horror'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final category = _type == _ContentType.manhwa
          ? await _storyService.addCategory(name: name)
          : await _documentaryService.addDocumentaryCategory(name: name);
      await _refreshCategories(autoSelect: category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Category "${category.name}" added.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.')));
      return;
    }
    if (_coverBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick a cover image.')));
      return;
    }
    if (_episodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one episode.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_type == _ContentType.manhwa) {
        await _storyService.addStory(
          title: _titleController.text.trim(),
          categoryId: _selectedCategory!.id,
          chapters: _episodes,
          coverBytes: _coverBytes!,
          coverFilename: _coverFilename!,
          status: _status,
        );
      } else {
        await _documentaryService.addDocumentary(
          title: _titleController.text.trim(),
          categoryId: _selectedCategory!.id,
          chapters: _episodes,
          coverBytes: _coverBytes!,
          coverFilename: _coverFilename!,
          status: _status,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_type == _ContentType.manhwa ? 'Manhwa added.' : 'Documentary added.')),
      );
      _titleController.clear();
      setState(() {
        _coverBytes = null;
        _coverFilename = null;
        _episodes.clear();
        _selectedCategory = null;
        _status = 'ongoing';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Content')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<_ContentType>(
              segments: const [
                ButtonSegment(value: _ContentType.manhwa, label: Text('Manhwa'), icon: Icon(Icons.menu_book_outlined)),
                ButtonSegment(
                  value: _ContentType.documentary,
                  label: Text('Documentary'),
                  icon: Icon(Icons.movie_creation_outlined),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() {
                  _type = selection.first;
                  _selectedCategory = null;
                  _categoriesFuture = _fetchCategoriesForType();
                });
              },
            ),
            const SizedBox(height: 24),

            Text('Category', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<CategoryModel>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Could not load categories: ${snapshot.error}');
                }
                final categories = snapshot.data ?? const [];
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CategoryModel>(
                        value: _selectedCategory,
                        isExpanded: true,
                        hint: Text(categories.isEmpty ? 'No categories yet' : 'Select a category'),
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: (c) => setState(() => _selectedCategory = c),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      tooltip: 'New category',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
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
            if (_coverBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_coverBytes!, height: 160, fit: BoxFit.cover, width: double.infinity),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickCoverImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_coverBytes == null ? 'Pick cover image' : 'Change cover image'),
            ),
            const SizedBox(height: 24),

            Text('Episodes', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ...List.generate(_episodes.length, (i) {
              final episode = _episodes[i];
              final pageCount = (episode['pages'] as List).length;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${episode['chapterNo']}')),
                  title: Text('Episode ${episode['chapterNo']}'),
                  subtitle: Text('$pageCount page(s)'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editEpisode(i),
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Re-upload / edit pages',
                      ),
                      IconButton(
                        onPressed: () => _removeEpisode(i),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove episode',
                      ),
                    ],
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addEpisode,
              icon: const Icon(Icons.add),
              label: const Text('Add episode'),
            ),

            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_type == _ContentType.manhwa ? 'Add Manhwa' : 'Add Documentary'),
            ),
          ],
        ),
      ),
    );
  }
}
