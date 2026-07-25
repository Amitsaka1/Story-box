/// Shared shape for both Story and Documentary comments (identical
/// JSON from both backends) -- story-wide/documentary-wide, not
/// per-episode.
class CommentModel {
  final String id;
  final String username;
  final String text;
  final DateTime createdAt;

  const CommentModel({
    required this.id,
    required this.username,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['id'] as String,
      username: json['username'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
