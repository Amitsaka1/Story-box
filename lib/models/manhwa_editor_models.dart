import 'dart:typed_data';

/// Local, in-memory editing state for one manhwa page while the admin
/// is building a chapter. Mirrors StoryPage/StoryTextBox (the published
/// JSON shape) but stays mutable and also carries the locally-picked
/// image bytes before they're uploaded via uploadPageImage().
class EditablePage {
  final String localId; // stable widget key, not sent to backend
  Uint8List? bytes; // local picked bytes, before upload
  String? filename;
  String? uploadedImageUrl; // set once uploadPageImage() succeeds
  int bubbleCount; // the "- [n] +" counter for this image
  List<EditableTextBox> textBoxes;

  EditablePage({
    required this.localId,
    this.bytes,
    this.filename,
    this.uploadedImageUrl,
    this.bubbleCount = 0,
    List<EditableTextBox>? textBoxes,
  }) : textBoxes = textBoxes ?? [];
}

/// One bubble's editable state. `number` is the cumulative, series-wide
/// bubble number -- assigned by [renumberPages], never typed manually.
/// Position/size is set ONCE by whichever language is entered first
/// (the "primary") and shared by every other language added after --
/// switching/adding language never moves or resizes the box.
class EditableTextBox {
  int number;
  double x;
  double y;
  double width;
  double height;
  double fontSize; // starting point for auto-shrink-per-language at render time
  int colorValue; // ARGB int, e.g. 0xFF000000 for black
  String? primaryLang; // which language "owns" this box's position
  Map<String, String> translations;

  EditableTextBox({
    required this.number,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.fontSize = 14,
    this.colorValue = 0xFF000000,
    this.primaryLang,
    Map<String, String>? translations,
  }) : translations = translations ?? {};
}

/// Recomputes every page's textBoxes list to match its bubbleCount, and
/// reassigns cumulative numbers across the whole chapter in page order
/// (page 1 with count 2 -> #1,#2; page 2 with count 2 -> #3,#4; etc).
/// Call this any time a page's bubbleCount changes, or pages are
/// added/removed/reordered. Existing box data (position/translations)
/// is preserved wherever possible so bumping a count doesn't wipe out
/// work already done on that page's other boxes.
void renumberPages(List<EditablePage> pages) {
  int nextNumber = 1;
  for (final page in pages) {
    if (page.textBoxes.length < page.bubbleCount) {
      while (page.textBoxes.length < page.bubbleCount) {
        page.textBoxes.add(EditableTextBox(number: 0));
      }
    } else if (page.textBoxes.length > page.bubbleCount) {
      page.textBoxes.removeRange(page.bubbleCount, page.textBoxes.length);
    }
    for (final box in page.textBoxes) {
      box.number = nextNumber;
      nextNumber++;
    }
  }
}
