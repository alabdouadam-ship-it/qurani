import 'package:flutter/material.dart';

enum NewsType { text, image, youtube }

class NewsItem {
  final String id;
  final String title;
  final String description;
  final NewsType type;
  final String mediaUrl;
  final String sourceUrl;
  final DateTime publishDate;
  final DateTime validUntil;
  final String language;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.mediaUrl,
    required this.sourceUrl,
    required this.publishDate,
    required this.validUntil,
    this.language = 'ar',
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr as String);
      } catch (e) {
        debugPrint('[NewsItem] Error parsing date: $dateStr - $e');
        return DateTime.now();
      }
    }

    return NewsItem(
      id: json['id'] as String? ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'No Title',
      description: json['description'] as String? ?? '',
      type: _parseType(json['type'] as String? ?? 'text'),
      mediaUrl: json['mediaUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      publishDate: parseDate(json['publishDate']),
      validUntil: parseDate(json['validUntil']),
      language: json['language'] as String? ?? 'ar',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'sourceUrl': sourceUrl,
      'publishDate': publishDate.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'language': language,
    };
  }

  static NewsType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'image':
        return NewsType.image;
      case 'youtube':
        return NewsType.youtube;
      default:
        return NewsType.text;
    }
  }

  Color get backgroundColor {
    switch (type) {
      case NewsType.image:
        return const Color(0xFFF0F9F5); // Soft emerald/mint
      case NewsType.youtube:
        return const Color(0xFFF6F1FB); // Soft lavender/rose
      case NewsType.text:
        return const Color(0xFFF4F9FE); // Soft sky blue/cream
    }
  }

  bool get isExpired => validUntil.isBefore(DateTime.now());

  bool get isRtl => language == 'ar';
}
