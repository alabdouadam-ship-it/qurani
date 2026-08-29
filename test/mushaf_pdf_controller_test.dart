// Tests for MushafPdfController's pure logic.
//
// The Quran-page <-> PDF-index conversion is the part worth pinning down: the
// mushaf PDFs have cover pages before Quran page 1 (3 for blue/green, 9 for
// tajweed), and before this extraction that `(page - 1) + offset` arithmetic was
// open-coded in five separate places inside read_quran_screen.dart. Getting it
// wrong by one silently shows the reader the wrong page, which is exactly the
// kind of bug that is easy to ship and hard to notice.
//
// Download and availability are deliberately not covered here: they touch the
// network and the filesystem. They are isolated behind `select()` /
// `refreshAvailability()` so they can be faked later if wanted.

import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/read_quran/mushaf_pdf_controller.dart';
import 'package:qurani/services/mushaf_pdf_service.dart';

void main() {
  group('page offset arithmetic', () {
    test('blue and green place Quran page 1 at PDF index 3', () {
      for (final type in [MushafType.blue, MushafType.green]) {
        final c = MushafPdfController(initialType: type);
        expect(c.pageOffset, 3, reason: '${type.name} offset');
        expect(c.pdfIndexForQuranPage(1), 3);
        expect(c.quranPageForPdfIndex(3), 1);
        c.dispose();
      }
    });

    test('tajweed places Quran page 1 at PDF index 9', () {
      final c = MushafPdfController(initialType: MushafType.tajweed);
      expect(c.pageOffset, 9);
      expect(c.pdfIndexForQuranPage(1), 9);
      expect(c.quranPageForPdfIndex(9), 1);
      c.dispose();
    });

    test('round-trips every Quran page for every style', () {
      for (final type in MushafType.values) {
        final c = MushafPdfController(initialType: type);
        for (var page = 1; page <= 604; page++) {
          expect(c.quranPageForPdfIndex(c.pdfIndexForQuranPage(page)), page,
              reason: '${type.name} page $page');
        }
        c.dispose();
      }
    });

    test('cover pages map to Quran pages below 1', () {
      final c = MushafPdfController(initialType: MushafType.blue);
      // PDF indices 0..2 are cover pages for blue; callers range-check the
      // result rather than relying on clamping here.
      expect(c.quranPageForPdfIndex(0), lessThan(1));
      expect(c.quranPageForPdfIndex(2), 0);
      c.dispose();
    });

    test('the last Quran page maps inside a real document', () {
      final c = MushafPdfController(initialType: MushafType.tajweed);
      expect(c.pdfIndexForQuranPage(604), 612);
      c.dispose();
    });
  });

  group('state transitions', () {
    test('starts unavailable with no download in flight', () {
      final c = MushafPdfController(initialType: MushafType.blue);
      expect(c.isAvailable, isFalse);
      expect(c.path, isNull);
      expect(c.isDownloading, isFalse);
      expect(c.progress, isNull);
      expect(c.documentFuture, isNull,
          reason: 'must not try to open a document when no file is present');
      c.dispose();
    });

    test('resetTo switches style, clears the cached path, and notifies', () {
      final c = MushafPdfController(initialType: MushafType.blue);
      var notifications = 0;
      c.addListener(() => notifications++);

      c.resetTo(MushafType.tajweed);

      expect(c.type, MushafType.tajweed);
      expect(c.path, isNull);
      expect(c.pageOffset, 9, reason: 'offset must follow the new style');
      expect(notifications, 1);
      c.dispose();
    });

    test('cancelDownload is safe when nothing is downloading', () {
      final c = MushafPdfController(initialType: MushafType.blue);
      expect(c.cancelDownload, returnsNormally);
      c.dispose();
    });

    test('does not notify after dispose', () {
      final c = MushafPdfController(initialType: MushafType.blue);
      var notifications = 0;
      c.addListener(() => notifications++);
      c.dispose();
      // A late download callback or a resolved availability check must not
      // notify a disposed controller.
      c.resetTo(MushafType.green);
      expect(notifications, 0);
    });
  });
}
