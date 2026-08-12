import 'package:flutter/material.dart';

/// Bubble ka shape type. `none` matlab sirf plain caption text,
/// bina kisi bubble outline ke.
enum BubbleType { none, caption, dialogue, thought }

/// Har bubble type ka default size jab naya element add kiya jaata hai.
/// User baad me corner handle se ise kabhi bhi resize kar sakta hai.
const Map<BubbleType, Size> kBubbleDefaultSizes = {
  BubbleType.caption: Size(160, 60),
  BubbleType.dialogue: Size(180, 90),
  BubbleType.thought: Size(180, 100),
  BubbleType.none: Size(140, 50),
};

/// Ek editable element jo PDF page ke upar overlay hota hai -- ye kabhi
/// bhi real PDF content ko touch nahi karta, sirf canvas ke upar draw
/// hota hai.
///
/// Bubble ka size (width/height) free-form resizable hai (chota/bada/
/// patla/chauda/lamba -- koi bhi shape). Uske andar ka text hamesha
/// isi box ke hisab se auto-fit hota hai: font apne aap chhota-bada
/// hota hai aur wrap bhi hota hai, sirf single-line tak simit nahi
/// rehta. Color fixed hai: bubble white, text black.
class PdfEditElement {
  final String id;
  BubbleType type;
  String text;
  Offset position; // bubble ka top-left corner, page canvas ke relative
  double width;
  double height;

  PdfEditElement({
    required this.id,
    required this.type,
    required this.text,
    required this.position,
    double? width,
    double? height,
  })  : width = width ?? (kBubbleDefaultSizes[type]?.width ?? 160),
        height = height ?? (kBubbleDefaultSizes[type]?.height ?? 60);
}

/// Ek PDF page ke saare elements ko group karta hai, taaki
/// multi-page PDF me har page apni alag element-list rakh sake.
class PdfEditPage {
  final int pageNumber;
  final List<PdfEditElement> elements;

  PdfEditPage({required this.pageNumber, List<PdfEditElement>? elements})
      : elements = elements ?? [];
}
