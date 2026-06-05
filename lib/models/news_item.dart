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
  final String? categoryAr;
  final String? categoryEn;
  final String? categoryFr;
  final List<String> targetLanguages;
  /// ISO 3166-1 alpha-2 country codes (uppercase). When non-empty, the item is
  /// shown ONLY to users whose device-locale country is in this list.
  final List<String> targetCountries;
  /// Country codes the item is hidden from. Takes precedence over everything.
  final List<String> excludedCountries;
  final bool isFeatured;
  final bool sendNotification;

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
    this.categoryAr,
    this.categoryEn,
    this.categoryFr,
    this.targetLanguages = const [],
    this.targetCountries = const [],
    this.excludedCountries = const [],
    this.isFeatured = false,
    this.sendNotification = false,
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
      categoryAr: json['category_ar'] as String?,
      categoryEn: json['category_en'] as String?,
      categoryFr: json['category_fr'] as String?,
      targetLanguages: (json['target_languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      targetCountries: _parseCountryList(json['target_countries']),
      excludedCountries: _parseCountryList(json['excluded_countries']),
      isFeatured: json['is_featured'] == true || json['featured'] == true,
      sendNotification: json['push'] == true,
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
      'category_ar': categoryAr,
      'category_en': categoryEn,
      'category_fr': categoryFr,
      'target_languages': targetLanguages,
      'target_countries': targetCountries,
      'excluded_countries': excludedCountries,
      'featured': isFeatured,
      'push': sendNotification,
    };
  }

  String? localizedCategory(String currentLang) {
    if (currentLang == 'ar') return categoryAr;
    if (currentLang == 'fr') return categoryFr;
    return categoryEn;
  }

  bool isVisibleForLanguage(String currentLang) {
    // Hide if targeted languages array exists but current language is not in it
    if (targetLanguages.isNotEmpty && !targetLanguages.contains(currentLang)) {
      return false;
    }
    
    // Strict logic: hide if the category for this language is missing but others exist
    bool hasAnyCategory = categoryAr != null || categoryEn != null || categoryFr != null;
    if (hasAnyCategory) {
      if (currentLang == 'ar' && categoryAr == null) return false;
      if (currentLang == 'fr' && categoryFr == null) return false;
      if (currentLang == 'en' && categoryEn == null) return false;
    }
    
    return true;
  }

  /// Country targeting check. [countryCode] is the device-locale country
  /// (ISO 3166-1 alpha-2). Case-insensitive.
  ///   * excluded_countries wins: if the user's country is excluded, hide.
  ///   * if target_countries is non-empty, show ONLY when the user's country
  ///     is in it.
  ///   * both empty → visible everywhere (default).
  /// A null/empty [countryCode] (locale has no country) is treated as "not in
  /// any specific country": excluded lists can't match it, and a target list
  /// hides it (since we can't confirm membership) — except when there's no
  /// targeting at all, where it stays visible.
  bool isVisibleForCountry(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();

    if (excludedCountries.isNotEmpty &&
        code.isNotEmpty &&
        excludedCountries.contains(code)) {
      return false;
    }

    if (targetCountries.isNotEmpty) {
      if (code.isEmpty) return false; // can't confirm membership
      return targetCountries.contains(code);
    }

    return true;
  }

  /// Normalises a country-list field (from JSON array or comma string) into a
  /// list of uppercase ISO codes.
  static List<String> _parseCountryList(dynamic raw) {
    if (raw == null) return const [];
    Iterable<dynamic> items;
    if (raw is List) {
      items = raw;
    } else if (raw is String) {
      items = raw.split(',');
    } else {
      return const [];
    }
    return items
        .map((e) => e.toString().trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toList();
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
