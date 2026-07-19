import 'package:my_app/models/story_model.dart';

/// Sample data so the UI has something to render. Replace this with a
/// real API call later (e.g. StoryService.fetchStories()) -- the widgets
/// don't care where the List<StoryModel> comes from.
final List<StoryModel> dummyStories = [
  StoryModel(
    id: '1',
    title: 'The Last Lighthouse',
    coverImageUrl: 'https://picsum.photos/seed/story1/400/560',
    category: 'Drama',
    rating: 4.7,
    viewCount: 1250000,
    likeCount: 98000,
    commentCount: 4300,
    addedAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  StoryModel(
    id: '2',
    title: 'Shadows of Kolkata',
    coverImageUrl: 'https://picsum.photos/seed/story2/400/560',
    category: 'Thriller',
    rating: 4.9,
    viewCount: 3400000,
    likeCount: 210000,
    commentCount: 15200,
    addedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
  StoryModel(
    id: '3',
    title: 'Monsoon Diaries',
    coverImageUrl: 'https://picsum.photos/seed/story3/400/560',
    category: 'Romance',
    rating: 4.3,
    viewCount: 890000,
    likeCount: 67000,
    commentCount: 2100,
    addedAt: DateTime.now().subtract(const Duration(hours: 12)),
  ),
  StoryModel(
    id: '4',
    title: 'The Silent Hunt',
    coverImageUrl: 'https://picsum.photos/seed/story4/400/560',
    category: 'Thriller',
    rating: 4.8,
    viewCount: 5200000,
    likeCount: 340000,
    commentCount: 22000,
    addedAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
  StoryModel(
    id: '5',
    title: 'Letters to Nowhere',
    coverImageUrl: 'https://picsum.photos/seed/story5/400/560',
    category: 'Drama',
    rating: 4.1,
    viewCount: 430000,
    likeCount: 29000,
    commentCount: 980,
    addedAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  StoryModel(
    id: '6',
    title: 'Beyond the Horizon',
    coverImageUrl: 'https://picsum.photos/seed/story6/400/560',
    category: 'Adventure',
    rating: 4.6,
    viewCount: 2100000,
    likeCount: 145000,
    commentCount: 8700,
    addedAt: DateTime.now().subtract(const Duration(days: 7)),
  ),
  StoryModel(
    id: '7',
    title: 'Whispers in the Wall',
    coverImageUrl: 'https://picsum.photos/seed/story7/400/560',
    category: 'Horror',
    rating: 4.4,
    viewCount: 1780000,
    likeCount: 112000,
    commentCount: 6300,
    addedAt: DateTime.now().subtract(const Duration(hours: 20)),
  ),
  StoryModel(
    id: '8',
    title: 'The Paper Boat',
    coverImageUrl: 'https://picsum.photos/seed/story8/400/560',
    category: 'Family',
    rating: 4.2,
    viewCount: 560000,
    likeCount: 41000,
    commentCount: 1500,
    addedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

/// Unique category names, "All" first -- used to build the filter chips.
List<String> get storyCategories {
  final categories = dummyStories.map((s) => s.category).toSet().toList();
  categories.sort();
  return ['All', ...categories];
}
