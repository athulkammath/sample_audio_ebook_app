import 'dart:convert';

class BookmarkItem {
  final String cfi;
  final String title;
  final double percentage;
  final DateTime createdAt;

  BookmarkItem({
    required this.cfi,
    required this.title,
    required this.percentage,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'cfi': cfi,
        'title': title,
        'percentage': percentage,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BookmarkItem.fromJson(Map<String, dynamic> json) => BookmarkItem(
        cfi: json['cfi'] as String,
        title: json['title'] as String,
        percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String encode() => jsonEncode(toJson());
  factory BookmarkItem.decode(String str) =>
      BookmarkItem.fromJson(jsonDecode(str));
}

class HighlightItem {
  final String cfi;
  final String text;
  final String colorHex;
  final String? note;
  final DateTime createdAt;

  HighlightItem({
    required this.cfi,
    required this.text,
    required this.colorHex,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'cfi': cfi,
        'text': text,
        'colorHex': colorHex,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HighlightItem.fromJson(Map<String, dynamic> json) => HighlightItem(
        cfi: json['cfi'] as String,
        text: json['text'] as String,
        colorHex: json['colorHex'] as String? ?? 'FFFF00',
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String encode() => jsonEncode(toJson());
  factory HighlightItem.decode(String str) =>
      HighlightItem.fromJson(jsonDecode(str));
}
