import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/models/news_item.dart';
import 'package:qurani/services/news_service.dart';

void main() {
  group('NewsService Merging Logic', () {
    late NewsItem assetItem;
    late NewsItem remoteItem;
    late NewsItem expiredItem;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      assetItem = NewsItem(
        id: '1',
        title: 'Asset Title',
        description: 'Asset Desc',
        type: NewsType.text,
        mediaUrl: '',
        sourceUrl: '',
        publishDate: now.subtract(const Duration(hours: 2)),
        validUntil: now.add(const Duration(days: 1)),
      );

      remoteItem = NewsItem(
        id: '1', // Same ID
        title: 'Remote Title',
        description: 'Remote Desc',
        type: NewsType.text,
        mediaUrl: '',
        sourceUrl: '',
        publishDate: now.subtract(const Duration(hours: 1)),
        validUntil: now.add(const Duration(days: 2)),
      );

      expiredItem = NewsItem(
        id: 'expired',
        title: 'Expired',
        description: '',
        type: NewsType.text,
        mediaUrl: '',
        sourceUrl: '',
        publishDate: now.subtract(const Duration(days: 10)),
        validUntil: now.subtract(const Duration(days: 1)),
      );
    });

    test('remote item should overwrite asset item with same ID', () {
      final merged = NewsService.mergeAndFilterNews(
        assetItems: [assetItem],
        remoteItems: [remoteItem],
        savedIds: {},
      );

      expect(merged.length, 1);
      expect(merged.first.title, 'Remote Title');
      expect(merged.first.description, 'Remote Desc');
    });

    test('expired items should be filtered out by default', () {
      final merged = NewsService.mergeAndFilterNews(
        assetItems: [assetItem, expiredItem],
        remoteItems: [],
        savedIds: {},
      );

      expect(merged.length, 1);
      expect(merged.any((item) => item.id == 'expired'), false);
    });

    test('expired items should be kept if they are saved', () {
      final merged = NewsService.mergeAndFilterNews(
        assetItems: [assetItem, expiredItem],
        remoteItems: [],
        savedIds: {'expired'},
      );

      expect(merged.length, 2);
      expect(merged.any((item) => item.id == 'expired'), true);
    });

    test('news should be sorted by publish date (newest first)', () {
      final older = NewsItem(
        id: 'older',
        title: 'Older',
        description: '',
        type: NewsType.text,
        mediaUrl: '',
        sourceUrl: '',
        publishDate: now.subtract(const Duration(days: 5)),
        validUntil: now.add(const Duration(days: 5)),
      );

      final merged = NewsService.mergeAndFilterNews(
        assetItems: [older, assetItem],
        remoteItems: [remoteItem], // '1' is newer than 'older'
        savedIds: {},
      );

      expect(merged.length, 2);
      expect(merged.first.id, '1');
      expect(merged.last.id, 'older');
    });
  });
}
