/// R2/CDN pe pade JSON file ka shape -- manhwa chapter ka actual data:
/// pages (clean images) ke andar textBoxes (bubble number-wise
/// position + per-language translations). Backend ye file khud nahi
/// rakhta, sirf uska URL (contentUrl) batata hai; app seedha CDN se ye
/// JSON fetch karta hai.
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
  final List<StoryPage> pages;

  const StoryChapter({required this.chapterNo, required this.pages});

  factory StoryChapter.fromJson(Map<String, dynamic> json) {
    final pagesJson = json['pages'] as List? ?? [];
    return StoryChapter(
      chapterNo: json['chapterNo'] as int? ?? 1,
      pages: pagesJson.map((p) => StoryPage.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

/// One manhwa page -- the clean/textless image plus every text-box
/// (bubble) overlaid on it. Numbering is cumulative across the whole
/// chapter (page 1 might end at #2, page 2 continues from #3) -- the
/// `number` on each box (not pageNo) is what the admin-panel counter
/// assigns and what the bulk-text-input matches against.
class StoryPage {
  final int pageNo;
  final String imageUrl;
  final List<StoryTextBox> textBoxes;

  const StoryPage({required this.pageNo, required this.imageUrl, required this.textBoxes});

  factory StoryPage.fromJson(Map<String, dynamic> json) {
    final boxesJson = json['textBoxes'] as List? ?? [];
    return StoryPage(
      pageNo: json['pageNo'] as int? ?? 1,
      imageUrl: json['imageUrl'] as String? ?? '',
      textBoxes: boxesJson.map((b) => StoryTextBox.fromJson(b as Map<String, dynamic>)).toList(),
    );
  }
}

/// One bubble. x/y/width/height are set ONCE (by whichever language
/// was entered first, the "primary") and shared by every language --
/// switching language never moves or resizes the box, it only swaps
/// which string from [translations] gets rendered inside it.
class StoryTextBox {
  final int number;
  final double x;
  final double y;
  final double width;
  final double height;
  final Map<String, String> translations;

  const StoryTextBox({
    required this.number,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.translations,
  });

  factory StoryTextBox.fromJson(Map<String, dynamic> json) {
    final rawTranslations = json['translations'] as Map? ?? {};
    return StoryTextBox(
      number: json['number'] as int? ?? 0,
      x: (json['x'] as num? ?? 0).toDouble(),
      y: (json['y'] as num? ?? 0).toDouble(),
      width: (json['width'] as num? ?? 0).toDouble(),
      height: (json['height'] as num? ?? 0).toDouble(),
      translations: rawTranslations.map((k, v) => MapEntry(k.toString(), v.toString())),
    );
  }

  /// Text for [lang], falling back to whatever language IS available
  /// (never render a blank bubble just because one translation is
  /// missing).
  String textFor(String lang) {
    if (translations.containsKey(lang)) return translations[lang]!;
    return translations.isNotEmpty ? translations.values.first : '';
  }
}
