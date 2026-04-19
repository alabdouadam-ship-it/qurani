// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$queueNotifierHash() => r'7e803dd9d3fcf46b99f9c1cd2a4df17eab29a651';

/// Riverpod mirror for [QueueService.queueNotifier].
///
/// Audio screens that need the current listen-queue can use
/// `ref.watch(queueProvider)` instead of manually subscribing to
/// `QueueService().queueNotifier` via `addListener`/`removeListener`.
///
/// Writes (`addToQueue`, `removeFromQueue`, `clearQueue`) still go
/// through [QueueService]; every one of those methods fires the
/// underlying ValueNotifier, which this notifier listens to and mirrors
/// into Riverpod state. No write-side changes required.
///
/// Copied from [QueueNotifier].
@ProviderFor(QueueNotifier)
final queueNotifierProvider =
    AutoDisposeNotifierProvider<QueueNotifier, List<int>>.internal(
  QueueNotifier.new,
  name: r'queueNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$queueNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$QueueNotifier = AutoDisposeNotifier<List<int>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
