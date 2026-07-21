/// R2/CDN pe pade JSON file ka shape -- story ka actual padhne wala
/// text. Backend ye file khud nahi rakhta, sirf uska URL (contentUrl)
/// batata hai; app seedha CDN se ye JSON fetch karta hai.
class StoryContentModel {
  final List<StoryChapter> chapters;

  const StoryContentModel({required this.chapters});

  factory StoryContentModel.fromJson(Map<String, dynamic> json) {
    final chaptersJson = json['chapters'] as List? ?? [];
    return StoryContentModel(
      chapters: chaptersJson
          .map((c) => StoryChapter.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StoryChapter {
  final int chapterNo;
  final String text;

  const StoryChapter({required this.chapterNo, required this.text});

  factory StoryChapter.fromJson(Map<String, dynamic> json) {
    return StoryChapter(
      chapterNo: json['chapterNo'] as int? ?? 1,
      text: json['text'] as String? ?? '',
    );
  }
}
