import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/services/download_issue_service.dart';
import 'package:qurani/services/download_batch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  const item = DownloadIssue(reciter: 'afs', surah: 2, verse: 12);
  test('failed item persists and a successful retry clears it', () async {
    await expectLater(
        DownloadIssueService.track(item, () async => throw StateError('file')),
        throwsStateError);
    final issue = (await DownloadIssueService.load()).single;
    expect(issue.status, 'failed');
    expect(issue.attempts, 1);
    expect(issue.verse, 12);
    await DownloadIssueService.track(item, () async {});
    expect(await DownloadIssueService.load(), isEmpty);
  });
  test('cancellation is retained separately from errors', () async {
    final token = CancelToken()..cancel();
    await expectLater(
        DownloadIssueService.track(item, () async {}, cancelToken: token),
        throwsA(isA<DioException>()));
    expect((await DownloadIssueService.load()).single.status, 'cancelled');
  });
  test(
      'active state is persisted before transfer, without exposing raw exception text',
      () async {
    await DownloadIssueService.track(item, () async {
      final issue = (await DownloadIssueService.load()).single;
      expect(issue.status, 'interrupted');
      expect(DownloadIssueService.isActive(item), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(item.key), isNot(contains('https://')));
    });
    expect(DownloadIssueService.isActive(item), isFalse);
  });
  test('cancelled retry stops before task starts', () async {
    final token = CancelToken();
    await expectLater(
        DownloadIssueService.track(item, () async {
          token.cancel();
          checkDownloadCancellation(token);
        }, cancelToken: token),
        throwsA(isA<DioException>()));
    expect((await DownloadIssueService.load()).single.status, 'cancelled');
  });
  test('an incomplete bulk job survives for resuming unattempted files', () async {
    const batch = DownloadIssue(reciter: 'afs', surah: 0);
    final result = await DownloadIssueService.track(batch, () async =>
        const DownloadBatchResult(total: 114, completed: 7, failed: 0, cancelled: true));
    expect(result.cancelled, isTrue);
    final persisted = (await DownloadIssueService.load()).single;
    expect(persisted.surah, 0);
    expect(persisted.status, 'cancelled');
    await DownloadIssueService.track(batch, () async =>
        const DownloadBatchResult(total: 114, completed: 114, failed: 0, cancelled: false));
    expect(await DownloadIssueService.load(), isEmpty);
  });

  test('full-surah and verse-by-verse bulk jobs have independent persisted identities', () async {
    const full = DownloadIssue(reciter: 'afs', surah: 0);
    const ayahs = DownloadIssue(reciter: 'afs', surah: 0, verse: 0);
    const interrupted = DownloadBatchResult(total: 114, completed: 0, failed: 0, cancelled: true);
    expect(full.key, isNot(ayahs.key));
    await DownloadIssueService.track(full, () async => interrupted);
    await DownloadIssueService.track(ayahs, () async => interrupted);
    expect((await DownloadIssueService.load()).length, 2);
    await DownloadIssueService.track(full, () async {});
    expect((await DownloadIssueService.load()).single.verse, 0);
  });

}
