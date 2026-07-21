/// The CURRENT user's personal relationship with a story -- separate
/// from StoryModel (which is the public, shared data). Comes from
/// GET /stories/:id/interactions.
class StoryInteractionModel {
  final bool isLiked;
  final int? myRating; // 1-5, or null if this user hasn't rated it
  final double progress; // 0.0 - 1.0
  final bool completed;

  const StoryInteractionModel({
    required this.isLiked,
    required this.myRating,
    required this.progress,
    required this.completed,
  });

  factory StoryInteractionModel.fromJson(Map<String, dynamic> json) {
    return StoryInteractionModel(
      isLiked: json['isLiked'] as bool,
      myRating: json['myRating'] as int?,
      progress: (json['progress'] as num).toDouble(),
      completed: json['completed'] as bool,
    );
  }

  StoryInteractionModel copyWith({
    bool? isLiked,
    int? myRating,
    double? progress,
    bool? completed,
  }) {
    return StoryInteractionModel(
      isLiked: isLiked ?? this.isLiked,
      myRating: myRating ?? this.myRating,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
    );
  }
}
