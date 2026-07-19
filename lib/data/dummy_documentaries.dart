import 'package:my_app/models/documentary_model.dart';

/// Sample data so the UI has something to render. Replace this with a
/// real API call later -- the widgets don't care where the
/// List<DocumentaryModel> comes from.
///
/// addedAt values are spread across today / yesterday / this week /
/// this month / this year on purpose, so you can see the time filters
/// naturally split them without any manual "which bucket" tagging.
final List<DocumentaryModel> dummyDocumentaries = [
  DocumentaryModel(
    id: 'd1',
    title: 'Ocean Depths Unveiled',
    coverImageUrl: 'https://picsum.photos/seed/doc1/400/560',
    rating: 4.8,
    viewCount: 2100000,
    likeCount: 145000,
    commentCount: 8700,
    addedAt: DateTime.now().subtract(const Duration(hours: 3)), // Today
  ),
  DocumentaryModel(
    id: 'd2',
    title: 'The Himalayan Trail',
    coverImageUrl: 'https://picsum.photos/seed/doc2/400/560',
    rating: 4.9,
    viewCount: 3400000,
    likeCount: 210000,
    commentCount: 15200,
    addedAt: DateTime.now().subtract(const Duration(hours: 10)), // Today
  ),
  DocumentaryModel(
    id: 'd3',
    title: 'Silicon Valley Origins',
    coverImageUrl: 'https://picsum.photos/seed/doc3/400/560',
    rating: 4.3,
    viewCount: 890000,
    likeCount: 67000,
    commentCount: 2100,
    addedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)), // Yesterday
  ),
  DocumentaryModel(
    id: 'd4',
    title: 'Wildlife of the Sundarbans',
    coverImageUrl: 'https://picsum.photos/seed/doc4/400/560',
    rating: 4.7,
    viewCount: 5200000,
    likeCount: 340000,
    commentCount: 22000,
    addedAt: DateTime.now().subtract(const Duration(days: 1, hours: 6)), // Yesterday
  ),
  DocumentaryModel(
    id: 'd5',
    title: 'Ancient Ruins of Hampi',
    coverImageUrl: 'https://picsum.photos/seed/doc5/400/560',
    rating: 4.1,
    viewCount: 430000,
    likeCount: 29000,
    commentCount: 980,
    addedAt: DateTime.now().subtract(const Duration(days: 4)), // This Week
  ),
  DocumentaryModel(
    id: 'd6',
    title: 'The Rise of Renewable Energy',
    coverImageUrl: 'https://picsum.photos/seed/doc6/400/560',
    rating: 4.6,
    viewCount: 2100000,
    likeCount: 145000,
    commentCount: 8700,
    addedAt: DateTime.now().subtract(const Duration(days: 6)), // This Week
  ),
  DocumentaryModel(
    id: 'd7',
    title: 'Voices of the Sahara',
    coverImageUrl: 'https://picsum.photos/seed/doc7/400/560',
    rating: 4.4,
    viewCount: 1780000,
    likeCount: 112000,
    commentCount: 6300,
    addedAt: DateTime.now().subtract(const Duration(days: 15)), // This Month
  ),
  DocumentaryModel(
    id: 'd8',
    title: 'The Last Printing Press',
    coverImageUrl: 'https://picsum.photos/seed/doc8/400/560',
    rating: 4.2,
    viewCount: 560000,
    likeCount: 41000,
    commentCount: 1500,
    addedAt: DateTime.now().subtract(const Duration(days: 20)), // This Month
  ),
  DocumentaryModel(
    id: 'd9',
    title: 'Empires of the Deccan',
    coverImageUrl: 'https://picsum.photos/seed/doc9/400/560',
    rating: 4.5,
    viewCount: 990000,
    likeCount: 71000,
    commentCount: 3400,
    addedAt: DateTime.now().subtract(const Duration(days: 120)), // This Year
  ),
  DocumentaryModel(
    id: 'd10',
    title: 'Space Race: The Untold Story',
    coverImageUrl: 'https://picsum.photos/seed/doc10/400/560',
    rating: 4.9,
    viewCount: 6100000,
    likeCount: 480000,
    commentCount: 31000,
    addedAt: DateTime.now().subtract(const Duration(days: 200)), // This Year
  ),
];
