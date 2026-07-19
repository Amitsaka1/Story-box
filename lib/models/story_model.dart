/// Data structure for a single story. Backend se aane wale JSON ko
/// isi shape mein map karoge later -- abhi dummy data ke liye use hoga.
class StoryModel {
  final String id;
  final String title;
  final String coverImageUrl;
  final String category;
  final double rating; // 0.0 - 5.0
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final DateTime addedAt;

  const StoryModel({
    required this.id,
    required this.title,
    required this.coverImageUrl,
    required this.category,
    required this.rating,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.addedAt,
  });

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
