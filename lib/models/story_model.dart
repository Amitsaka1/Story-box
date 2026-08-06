/// Data structure for a single story. Backend se aane wale JSON ko
/// isi shape mein map karoge later -- abhi dummy data ke liye use hoga.
class StoryModel {
  final String id;
  final String title;
  final String coverImageUrl;
  final String contentUrl;
  final String category;
  final String categoryId;
  final String status; // "ongoing" | "completed"
  final double rating;
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

  /// Only present when this came from GET /stories/watching or
  /// GET /stories/completed -- used to sort the History tab.
  final DateTime? lastWatchedAt;

  const StoryModel({
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
    this.lastWatchedAt,
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
      lastWatchedAt: json['lastWatchedAt'] != null ? DateTime.parse(json['lastWatchedAt'] as String) : null,
    );
  }

  /// Inverse of fromJson -- used to persist a fetched list into
  /// LocalCache so it can be re-hydrated instantly on next app open.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverImageUrl': coverImageUrl,
      'contentUrl': contentUrl,
      'category': category,
      'categoryId': categoryId,
      'status': status,
      'rating': rating,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'addedAt': addedAt.toIso8601String(),
      'watchProgress': isWatching ? watchProgress : null,
      'viewedAt': viewedAt?.toIso8601String(),
      'lastWatchedAt': lastWatchedAt?.toIso8601String(),
    };
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
