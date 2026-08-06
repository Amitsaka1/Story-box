/// R2/CDN pe pade JSON file ka shape -- manhwa chapter ka actual data:
/// har chapter ek ordered list of page-images hai. Episodes fully-ready
/// upload hote hain (text pehle se images ke andar embedded), isliye
/// yaha koi bubble/text-overlay data nahi hai -- sirf image URLs, sahi
/// order me. Backend ye file khud nahi rakhta, sirf uska URL
/// (contentUrl) batata hai; app seedha CDN se ye JSON fetch karta hai.
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

  Map<String, dynamic> toJson() => {'chapters': chapters.map((c) => c.toJson()).toList()};
}

class StoryChapter {
  final int chapterNo;
  final List<StoryPage> pages;

  const StoryChapter({required this.chapterNo, required this.pages});

  factory StoryChapter.fromJson(Map<String, dynamic> json) {
    final pagesJson = json['pages'] as List? ?? [];
    return StoryChapter(
      chapterNo: json['chapterNo'] as int? ?? 1,
      pages: pagesJson.map((p) => StoryPage.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterNo': chapterNo,
        'pages': pages.map((p) => p.toJson()).toList(),
      };
}

/// One manhwa page -- just the fully-ready image, in its correct
/// reading order (pageNo).
class StoryPage {
  final int pageNo;
  final String imageUrl;

  const StoryPage({required this.pageNo, required this.imageUrl});

  factory StoryPage.fromJson(Map<String, dynamic> json) {
    return StoryPage(
      pageNo: json['pageNo'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'pageNo': pageNo, 'imageUrl': imageUrl};
}
