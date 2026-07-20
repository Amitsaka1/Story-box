/// Data structure for a single documentary. Backend se aane wale JSON
/// ko isi shape mein map karoge later -- abhi dummy data ke liye use hoga.
class DocumentaryModel {
  final String id;
  final String title;
  final String coverImageUrl;
  final double rating; // 0.0 - 5.0
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime addedAt;

  const DocumentaryModel({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.rating,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.addedAt,
  });

  /// Maps the JSON shape returned by GET /documentaries.
  factory DocumentaryModel.fromJson(Map<String, dynamic> json) {
    return DocumentaryModel(
      id: json['id'] as String,
      title: json['title'] as String,
      coverImageUrl: json['coverImageUrl'] as String,
      rating: (json['rating'] as num).toDouble(),
      viewCount: json['viewCount'] as int,
      likeCount: json['likeCount'] as int,
      commentCount: json['commentCount'] as int,
      addedAt: DateTime.parse(json['addedAt'] as String),
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

  /// Single combined "popularity" score used to sort the "All" filter
  /// so the most popular documentaries float to the top automatically.
  /// Weighted so views (usually largest numbers) don't completely
  /// drown out likes/comments/rating.
  double get popularityScore {
    return (viewCount * 1.0) +
        (likeCount * 4.0) +
        (commentCount * 8.0) +
        (rating * 20000);
  }
}
