// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_prefs_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$arabicFontNotifierHash() =>
    r'48c3b9850dc073b27f5cd36b77803a572fc1d3e8';

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
///
/// Copied from [ArabicFontNotifier].
@ProviderFor(ArabicFontNotifier)
final arabicFontNotifierProvider =
    AutoDisposeNotifierProvider<ArabicFontNotifier, String>.internal(
  ArabicFontNotifier.new,
  name: r'arabicFontNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$arabicFontNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ArabicFontNotifier = AutoDisposeNotifier<String>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
