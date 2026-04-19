import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/preferences_service.dart';

part 'reader_prefs_providers.g.dart';

/// Riverpod mirror for [PreferencesService.arabicFontNotifier].
///
/// Reader screens that need to react to a font-family change can now use
/// `ref.watch(arabicFontProvider)` instead of manually wiring
/// `addListener`/`removeListener` on the underlying [ValueNotifier].
///
/// Writes continue to go through
/// [PreferencesService.saveArabicFontFamily]: that method fires the
/// ValueNotifier, the notifier here listens to the ValueNotifier and
/// updates Riverpod state automatically. No write-side changes required
/// for this migration (see `docs/riverpod_audit.md` §5.2 Step 4).
@riverpod
class ArabicFontNotifier extends _$ArabicFontNotifier {
  @override
  String build() {
    final vn = PreferencesService.arabicFontNotifier;
    void listener() {
      state = vn.value;
    }

    vn.addListener(listener);
    ref.onDispose(() => vn.removeListener(listener));
    return vn.value;
  }
}

/// Back-compat alias for the pre-codegen `arabicFontProvider` symbol.
final arabicFontProvider = arabicFontNotifierProvider;
