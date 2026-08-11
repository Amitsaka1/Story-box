import 'package:flutter/material.dart';

/// Bubble ka shape type. `none` matlab sirf plain caption text,
/// bina kisi bubble outline ke.
enum BubbleType { none, caption, dialogue, thought }

/// Ek editable element jo PDF page ke upar overlay hota hai —
/// ye kabhi bhi real PDF content ko touch nahi karta, sirf
/// canvas ke upar draw hota hai. Export ke waqt isi ko flatten
/// karke naya PDF banta hai.
class PdfEditElement {
  final String id;
  BubbleType type;
  String text;
  Offset position; // element ka center point, page canvas ke relative
  double fontSize;
  Color textColor;
  Color bubbleColor;

  PdfEditElement({
    required this.id,
    required this.type,
    required this.text,
    required this.position,
    this.fontSize = 18,
    this.textColor = Colors.black,
    this.bubbleColor = Colors.white,
  });

  PdfEditElement copyWith({
    BubbleType? type,
    String? text,
    Offset? position,
    double? fontSize,
    Color? textColor,
    Color? bubbleColor,
  }) {
    return PdfEditElement(
      id: id,
      type: type ?? this.type,
      text: text ?? this.text,
      position: position ?? this.position,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      bubbleColor: bubbleColor ?? this.bubbleColor,
    );
  }
}

/// Ek PDF page ke saare elements ko group karta hai, taaki
/// multi-page PDF me har page apni alag element-list rakh sake.
class PdfEditPage {
  final int pageNumber;
  final List<PdfEditElement> elements;

  PdfEditPage({required this.pageNumber, List<PdfEditElement>? elements})
      : elements = elements ?? [];
}
