import 'package:flutter/material.dart';
import 'package:my_app/models/category_model.dart';
import 'package:my_app/services/documentary_service.dart';
import 'package:my_app/services/story_service.dart';

enum _ContentType { story, documentary }

/// Admin-only screen to add new content. Flow is deliberately minimal:
/// pick Story or Documentary, then --
///   Story -> just pick an existing category from a dropdown (or add a
///            new one inline if none exist yet) -- the story gets
///            created directly under that category.
///   Documentary -> no category needed, it's a standalone list.
/// Title + cover image URL are the only other fields; everything else
/// (rating/views/likes/comments) defaults to 0 on the backend and can
/// be edited later once an edit screen exists.
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
  final _coverUrlController = TextEditingController();

  _ContentType _type = _ContentType.story;
  late Future<List<CategoryModel>> _categoriesFuture;
  CategoryModel? _selectedCategory;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _storyService.fetchCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _coverUrlController.dispose();
    super.dispose();
  }

  Future<void> _refreshCategories({CategoryModel? autoSelect}) async {
    final future = _storyService.fetchCategories();
    setState(() => _categoriesFuture = future);
    final categories = await future;
    if (!mounted) return;
    setState(() {
      _selectedCategory = autoSelect ??
          (categories.contains(_selectedCategory) ? _selectedCategory : null);
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final category = await _storyService.addCategory(name: name);
      await _refreshCategories(autoSelect: category);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "${category.name}" added.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == _ContentType.story && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      if (_type == _ContentType.story) {
        await _storyService.addStory(
          title: _titleController.text.trim(),
          coverImageUrl: _coverUrlController.text.trim(),
          categoryId: _selectedCategory!.id,
        );
      } else {
        await _documentaryService.addDocumentary(
          title: _titleController.text.trim(),
          coverImageUrl: _coverUrlController.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _type == _ContentType.story ? 'Story added.' : 'Documentary added.',
          ),
        ),
      );
      _titleController.clear();
      _coverUrlController.clear();
      setState(() => _selectedCategory = null);
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
                ButtonSegment(
                  value: _ContentType.story,
                  label: Text('Story'),
                  icon: Icon(Icons.menu_book_outlined),
                ),
                ButtonSegment(
                  value: _ContentType.documentary,
                  label: Text('Documentary'),
                  icon: Icon(Icons.movie_creation_outlined),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 24),
            if (_type == _ContentType.story) ...[
              Text('Category', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<CategoryModel>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    );
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
                          hint: Text(
                            categories.isEmpty ? 'No categories yet' : 'Select a category',
                          ),
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: categories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                              .toList(),
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
            ],
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required.' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _coverUrlController,
              decoration: const InputDecoration(
                labelText: 'Cover image URL',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Cover image URL is required.';
                final uri = Uri.tryParse(v.trim());
                if (uri == null || !uri.hasScheme) return 'Enter a valid URL.';
                return null;
              },
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_type == _ContentType.story ? 'Add Story' : 'Add Documentary'),
            ),
          ],
        ),
      ),
    );
  }
}
