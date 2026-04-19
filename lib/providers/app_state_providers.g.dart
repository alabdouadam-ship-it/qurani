// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_state_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$localeNotifierHash() => r'5c76717184df19e366ad0e71d2c04aa38f51498a';

/// Notifier for the app locale.
///
/// Class is intentionally named `LocaleNotifier` rather than `Locale` because
/// `Locale` would collide with `dart:ui.Locale` (the state type). Codegen
/// therefore generates `localeNotifierProvider`; the `localeProvider`
/// forwarder below preserves the pre-codegen public name so every
/// `ref.watch(localeProvider)` / `ref.read(localeProvider.notifier).setLocale`
/// callsite continues to work unchanged.
///
/// Copied from [LocaleNotifier].
@ProviderFor(LocaleNotifier)
final localeNotifierProvider =
    AutoDisposeNotifierProvider<LocaleNotifier, Locale>.internal(
  LocaleNotifier.new,
  name: r'localeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$localeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$LocaleNotifier = AutoDisposeNotifier<Locale>;
String _$themeNotifierHash() => r'09467a7120a23266481ec55df0b90fe656bad0a8';

/// Notifier for the app theme id.
///
/// Name stays `ThemeNotifier` to avoid colliding with Material's `Theme`
/// widget when callers import both `material.dart` and this file. See the
/// `localeProvider` note above.
///
/// Copied from [ThemeNotifier].
@ProviderFor(ThemeNotifier)
final themeNotifierProvider =
    AutoDisposeNotifierProvider<ThemeNotifier, String>.internal(
  ThemeNotifier.new,
  name: r'themeNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$themeNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ThemeNotifier = AutoDisposeNotifier<String>;
String _$disabledScreensNotifierHash() =>
    r'5c9e8bfc48dcf161a58c1dea7180328de0d87b4f';

/// Notifier for the set of user-disabled screen ids.
///
/// Copied from [DisabledScreensNotifier].
@ProviderFor(DisabledScreensNotifier)
final disabledScreensNotifierProvider =
    AutoDisposeNotifierProvider<DisabledScreensNotifier, Set<String>>.internal(
  DisabledScreensNotifier.new,
  name: r'disabledScreensNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$disabledScreensNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$DisabledScreensNotifier = AutoDisposeNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
