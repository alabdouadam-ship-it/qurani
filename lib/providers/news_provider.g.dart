// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'news_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$unreadNewsIdsHash() => r'475cc8d307ce022868556be0b9e6484dbb4083e1';

/// Provider for unread news IDs. Derived from [newsProvider].
///
/// Copied from [unreadNewsIds].
@ProviderFor(unreadNewsIds)
final unreadNewsIdsProvider = AutoDisposeFutureProvider<Set<String>>.internal(
  unreadNewsIds,
  name: r'unreadNewsIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unreadNewsIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnreadNewsIdsRef = AutoDisposeFutureProviderRef<Set<String>>;
String _$unseenNewsCountHash() => r'487d83bc539637de58714505648d7a671c1131e6';

/// Provider for the number of unseen news items. Derived from
/// [unreadNewsIdsProvider].
///
/// Copied from [unseenNewsCount].
@ProviderFor(unseenNewsCount)
final unseenNewsCountProvider = AutoDisposeProvider<int>.internal(
  unseenNewsCount,
  name: r'unseenNewsCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$unseenNewsCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UnseenNewsCountRef = AutoDisposeProviderRef<int>;
String _$newsHash() => r'1d1f6e2b5490120723ab304d08598063afabd46f';

/// Provider for the list of NewsItems.
///
/// Codegen generates `newsProvider` (AsyncNotifierProvider) from this class
/// so existing callsites `ref.watch(newsProvider)` /
/// `ref.read(newsProvider.notifier).refresh()` continue to work unchanged.
///
/// Copied from [News].
@ProviderFor(News)
final newsProvider =
    AutoDisposeAsyncNotifierProvider<News, List<NewsItem>>.internal(
  News.new,
  name: r'newsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$newsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$News = AutoDisposeAsyncNotifier<List<NewsItem>>;
String _$savedNewsIdsHash() => r'eb37a87c47e191c2a2feef8655f9d6367ce4772e';

/// Provider for saved (bookmarked) news IDs.
///
/// Replaces the legacy `SavedNewsNotifier extends StateNotifier<Set<String>>`
/// with a codegen'd NotifierProvider. Same exposed API: state is a plain
/// `Set<String>` and callers use `ref.read(savedNewsIdsProvider.notifier)
/// .toggleSave(id)`.
///
/// Copied from [SavedNewsIds].
@ProviderFor(SavedNewsIds)
final savedNewsIdsProvider =
    AutoDisposeNotifierProvider<SavedNewsIds, Set<String>>.internal(
  SavedNewsIds.new,
  name: r'savedNewsIdsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$savedNewsIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SavedNewsIds = AutoDisposeNotifier<Set<String>>;
String _$hiddenNewsIdsHash() => r'8ad6e6727fa7c63d250fc7100f18c1c1d221cffd';

/// Provider for hidden (swipe-to-dismiss) news IDs.
///
/// Replaces the legacy `HiddenNewsNotifier extends StateNotifier<Set<String>>`
/// with a codegen'd NotifierProvider. Same exposed API.
///
/// Copied from [HiddenNewsIds].
@ProviderFor(HiddenNewsIds)
final hiddenNewsIdsProvider =
    AutoDisposeNotifierProvider<HiddenNewsIds, Set<String>>.internal(
  HiddenNewsIds.new,
  name: r'hiddenNewsIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hiddenNewsIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$HiddenNewsIds = AutoDisposeNotifier<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
