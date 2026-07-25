/// Data structure for a single documentary. Mirrors StoryModel's shape
/// exactly -- own category system, chapters, status.
class DocumentaryModel {
  final String id;
  final String title;
  final String coverImageUrl;
  final String contentUrl;
  final String category;
  final String categoryId;
  final String status; // "ongoing" | "completed"
  final double rating; // 0.0 - 5.0
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime addedAt;

  final bool isWatching;
  final double watchProgress;

  /// Only present when this came from GET /documentaries/history.
  final DateTime? viewedAt;

  const DocumentaryModel({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.contentUrl,
    required this.category,
    required this.categoryId,
    required this.status,
    required this.rating,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.addedAt,
    this.isWatching = false,
    this.watchProgress = 0.0,
    this.viewedAt,
  });

  factory DocumentaryModel.fromJson(Map<String, dynamic> json) {
    final watchProgress = json['watchProgress'] != null ? (json['watchProgress'] as num).toDouble() : 0.0;
    return DocumentaryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImageUrl: json['coverImageUrl'] as String,
      contentUrl: json['contentUrl'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      status: json['status'] as String? ?? 'ongoing',
      rating: (json['rating'] as num).toDouble(),
      viewCount: json['viewCount'] as int,
      likeCount: json['likeCount'] as int,
      commentCount: json['commentCount'] as int,
      addedAt: DateTime.parse(json['addedAt'] as String),
      isWatching: json['watchProgress'] != null,
      watchProgress: watchProgress,
      viewedAt: json['viewedAt'] != null ? DateTime.parse(json['viewedAt'] as String) : null,
    );
  }

  static String formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  double get popularityScore {
    return (viewCount * 1.0) + (likeCount * 4.0) + (commentCount * 8.0) + (rating * 20000);
  }
}
