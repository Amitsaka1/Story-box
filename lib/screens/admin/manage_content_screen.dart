import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/screens/admin/edit_content_screen.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/models/story_model.dart';
import 'package:my_app/services/documentary_service.dart';
import 'package:my_app/services/story_service.dart';

enum _ContentType { story, documentary }

/// Admin-only: browse every Story/Documentary (search + infinite
/// scroll, 20/page), tap one to Edit or Delete.
class ManageContentScreen extends StatefulWidget {
  const ManageContentScreen({super.key});

  @override
  State<ManageContentScreen> createState() => _ManageContentScreenState();
}

class _ManageContentScreenState extends State<ManageContentScreen> {
  final _storyService = StoryService();
  final _documentaryService = DocumentaryService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  static const int _pageSize = 20;

  _ContentType _type = _ContentType.story;
  String _search = '';

  // Story results
  final List<StoryModel> _stories = [];
  // Documentary results
  final List<DocumentaryModel> _documentaries = [];

  int _page = 1;
  bool _hasMore = true;
  bool _initialLoading = true;
  bool _loadingMore = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _initialLoading) return;
    final threshold = _scrollController.position.maxScrollExtent - 400;
    if (_scrollController.position.pixels >= threshold) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      setState(() => _search = value.trim());
      _loadInitial();
    });
  }

  void _onTypeChanged(Set<_ContentType> selection) {
    setState(() {
      _type = selection.first;
      _stories.clear();
      _documentaries.clear();
    });
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
      _stories.clear();
      _documentaries.clear();
    });
    try {
      if (_type == _ContentType.story) {
        final result = await _storyService.fetchStoriesPaged(page: 1, limit: _pageSize, search: _search);
        if (!mounted) return;
        setState(() {
          _stories.addAll(result.data);
          _hasMore = result.hasMore;
          _initialLoading = false;
        });
      } else {
        final result = await _documentaryService.fetchDocumentariesPaged(page: 1, limit: _pageSize, search: _search);
        if (!mounted) return;
        setState(() {
          _documentaries.addAll(result.data);
          _hasMore = result.hasMore;
          _initialLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      if (_type == _ContentType.story) {
        final result = await _storyService.fetchStoriesPaged(page: nextPage, limit: _pageSize, search: _search);
        if (!mounted) return;
        setState(() {
          _stories.addAll(result.data);
          _hasMore = result.hasMore;
          _page = nextPage;
          _loadingMore = false;
        });
      } else {
        final result = await _documentaryService.fetchDocumentariesPaged(page: nextPage, limit: _pageSize, search: _search);
        if (!mounted) return;
        setState(() {
          _documentaries.addAll(result.data);
          _hasMore = result.hasMore;
          _page = nextPage;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _showActions({required String id, required String title}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), dense: true),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(context).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EditContentScreen(isStory: _type == _ContentType.story, id: id)),
      );
      if (saved == true) _loadInitial();
    } else if (action == 'delete') {
      await _confirmDelete(id: id, title: title);
    }
  }

  Future<void> _confirmDelete({required String id, required String title}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this?'),
        content: Text('"$title" will be permanently deleted, along with all its comments, likes, and ratings. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (_type == _ContentType.story) {
        await _storyService.deleteStory(id);
        setState(() => _stories.removeWhere((s) => s.id == id));
      } else {
        await _documentaryService.deleteDocumentary(id);
        setState(() => _documentaries.removeWhere((d) => d.id == id));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"$title" deleted.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Content')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                SegmentedButton<_ContentType>(
                  segments: const [
                    ButtonSegment(value: _ContentType.story, label: Text('Story'), icon: Icon(Icons.menu_book_outlined)),
                    ButtonSegment(
                      value: _ContentType.documentary,
                      label: Text('Documentary'),
                      icon: Icon(Icons.movie_creation_outlined),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: _onTypeChanged,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by title...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList(colorScheme)),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme) {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _loadInitial, child: const Text('Retry')),
          ],
        ),
      );
    }

    final items = _type == _ContentType.story ? _stories : _documentaries;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _search.isEmpty ? 'Nothing here yet.' : 'No results for "$_search".',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _loadingMore
              ? const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
              : const SizedBox(height: 20);
        }

        final String id;
        final String title;
        final String coverImageUrl;
        final String status;
        final String category;

        if (_type == _ContentType.story) {
          final s = _stories[index];
          id = s.id;
          title = s.title;
          coverImageUrl = s.coverImageUrl;
          status = s.status;
          category = s.category;
        } else {
          final d = _documentaries[index];
          id = d.id;
          title = d.title;
          coverImageUrl = d.coverImageUrl;
          status = d.status;
          category = d.category;
        }

        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              coverImageUrl,
              width: 44,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 44,
                height: 60,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, size: 18, color: colorScheme.outline),
              ),
            ),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('$category · ${status == 'completed' ? 'Completed' : 'Ongoing'}'),
          trailing: const Icon(Icons.more_vert),
          onTap: () => _showActions(id: id, title: title),
        );
      },
    );
  }
}
