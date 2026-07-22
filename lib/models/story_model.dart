/// Data structure for a single story. Backend se aane wale JSON ko
/// isi shape mein map karoge later -- abhi dummy data ke liye use hoga.
class StoryModel {
  final String id;
  final String title;
  final String coverImageUrl;
  final String contentUrl;
  final String category;
  final double rating; // 0.0 - 5.0
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime addedAt;

  /// True if the current user has started (but not finished) this
  /// story -- drives the "Watching" section. In a real backend this
  /// would come from a per-user progress record, not the story itself.
  final bool isWatching;

  /// 0.0 - 1.0 progress, only meaningful when [isWatching] is true.
  final double watchProgress;

  /// Combined "popularity" score, same idea as the Documentary model --
  /// used to rank the "Top 20" trending screen.
  double get popularityScore =>
      (viewCount * 1.0) + (likeCount * 4.0) + (commentCount * 8.0) + (rating * 20000);

  /// Only present when this StoryModel came from GET /stories/history --
  /// null for every other endpoint (list/detail/watching).
  final DateTime? viewedAt;

  const StoryModel({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.contentUrl,
    required this.category,
    required this.rating,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.addedAt,
    this.isWatching = false,
    this.watchProgress = 0.0,
    this.viewedAt,
  });

  /// Maps the JSON shape returned by GET /stories (list/detail) and
  /// GET /stories/watching. The watching endpoint additionally sends
  /// a `watchProgress` field -- when present, isWatching is derived
  /// from it automatically (list/detail responses simply omit it).
  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final watchProgress = json['watchProgress'] != null ? (json['watchProgress'] as num).toDouble() : 0.0;
    return StoryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImageUrl: json['coverImageUrl'] as String,
      contentUrl: json['contentUrl'] as String? ?? '',
      category: json['category'] as String,
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

  /// Compact display like "12K", "3.4M" for view/like/comment counts.
  static String formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
