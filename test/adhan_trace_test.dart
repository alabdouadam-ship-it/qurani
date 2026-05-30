import 'package:flutter_test/flutter_test.dart';
import 'package:qurani/services/adhan_audio_manager.dart';
import 'package:qurani/services/logger.dart';

void main() {
  group('AdhanAudioManager.trace', () {
    late List<LogRecord> records;

    setUp(() {
      records = [];
      Log.onRecord = records.add;
    });

    tearDown(() {
      Log.onRecord = null;
    });

    test('emits a single AdhanTrace record with the event verb', () {
      AdhanAudioManager.trace('fired');
      expect(records.length, 1);
      expect(records.single.tag, 'AdhanTrace');
      expect(records.single.message, 'event=fired');
    });

    test('appends key=value fields in order', () {
      AdhanAudioManager.trace('engine', fields: {
        'prayer': 'fajr',
        'engine': 'native',
        'sound': 'afs',
      });
      expect(
        records.single.message,
        'event=engine prayer=fajr engine=native sound=afs',
      );
    });

    test('renders numeric and null field values', () {
      AdhanAudioManager.trace('scheduled', fields: {
        'id': 202511251,
        'missing': null,
      });
      expect(
        records.single.message,
        'event=scheduled id=202511251 missing=null',
      );
    });
  });
}
