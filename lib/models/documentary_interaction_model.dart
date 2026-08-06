/// Mirrors StoryInteractionModel exactly, for Documentary.
class DocumentaryInteractionModel {
  final bool isLiked;
  final int? myRating;
  final double progress;
  final bool completed;
  final int lastChapterNo;

  const DocumentaryInteractionModel({
    required this.isLiked,
    required this.myRating,
    required this.progress,
    required this.completed,
    required this.lastChapterNo,
  });

  factory DocumentaryInteractionModel.fromJson(Map<String, dynamic> json) {
    return DocumentaryInteractionModel(
      isLiked: json['isLiked'] as bool,
      myRating: json['myRating'] as int?,
      progress: (json['progress'] as num).toDouble(),
      completed: json['completed'] as bool,
      lastChapterNo: json['lastChapterNo'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isLiked': isLiked,
      'myRating': myRating,
      'progress': progress,
      'completed': completed,
      'lastChapterNo': lastChapterNo,
    };
  }

  DocumentaryInteractionModel copyWith({
    bool? isLiked,
    int? myRating,
    double? progress,
    bool? completed,
    int? lastChapterNo,
  }) {
    return DocumentaryInteractionModel(
      isLiked: isLiked ?? this.isLiked,
      myRating: myRating ?? this.myRating,
      progress: progress ?? this.progress,
      completed: completed ?? this.completed,
      lastChapterNo: lastChapterNo ?? this.lastChapterNo,
    );
  }
}
