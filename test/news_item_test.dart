import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/models/news_item.dart';

void main() {
  group('NewsItem.fromJson', () {
    test('should parse valid JSON correctly', () {
      final json = {
        'id': '1',
        'title': 'Test Title',
        'description': 'Test Description',
        'type': 'image',
        'mediaUrl': 'http://image.com',
        'sourceUrl': 'http://source.com',
        'publishDate': '2024-03-14T10:00:00Z',
        'validUntil': '2024-12-31T23:59:59Z',
        'language': 'en',
      };

      final item = NewsItem.fromJson(json);

      expect(item.id, '1');
      expect(item.title, 'Test Title');
      expect(item.type, NewsType.image);
      expect(item.publishDate.year, 2024);
      expect(item.publishDate.month, 3);
      expect(item.language, 'en');
      expect(item.isRtl, false);
    });

    test('should handle missing fields with defaults', () {
      final json = {
        'title': 'Minimal News',
      };

      final item = NewsItem.fromJson(json);

      expect(item.id, startsWith('temp_'));
      expect(item.title, 'Minimal News');
      expect(item.description, '');
      expect(item.type, NewsType.text);
      expect(item.language, 'ar');
      expect(item.isRtl, true);
    });

    test('should handle invalid date gracefully', () {
      final json = {
        'id': 'date-test',
        'publishDate': 'not-a-date',
      };

      final item = NewsItem.fromJson(json);

      expect(item.id, 'date-test');
      // Falling back to DateTime.now()
      expect(item.publishDate, isA<DateTime>());
    });

    test('should parse different news types correctly', () {
      expect(NewsItem.fromJson({'type': 'image'}).type, NewsType.image);
      expect(NewsItem.fromJson({'type': 'youtube'}).type, NewsType.youtube);
      expect(NewsItem.fromJson({'type': 'text'}).type, NewsType.text);
      expect(NewsItem.fromJson({'type': 'UNKNOWN'}).type, NewsType.text);
    });
  });

  group('NewsItem Logic', () {
    test('isExpired should return true for past dates', () {
      final item = NewsItem(
        id: '1',
        title: 'Old',
        description: '',
        type: NewsType.text,
        mediaUrl: '',
        sourceUrl: '',
        publishDate: DateTime.now().subtract(const Duration(days: 10)),
        validUntil: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(item.isExpired, true);
    });

    test('isExpired should return false for future dates', () {
      final item = NewsItem(
        id: '1',
        title: 'New',
        description: '',
        type: NewsType.text,
        mediaUrl: '',
        sourceUrl: '',
        publishDate: DateTime.now().subtract(const Duration(days: 1)),
        validUntil: DateTime.now().add(const Duration(days: 1)),
      );

      expect(item.isExpired, false);
    });
  });
}
