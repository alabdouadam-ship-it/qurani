import 'package:flutter/foundation.dart';

class QueueService {
  static final QueueService _instance = QueueService._internal();
  factory QueueService() => _instance;
  QueueService._internal();

  final List<int> _queue = [];
  final ValueNotifier<List<int>> _queueNotifier = ValueNotifier<List<int>>([]);

  ValueNotifier<List<int>> get queueNotifier => _queueNotifier;

  List<int> get queue => List.unmodifiable(_queue);

  void addToQueue(int surahOrder) {
    if (!_queue.contains(surahOrder)) {
      _queue.add(surahOrder);
      _queueNotifier.value = List.from(_queue);
    }
  }

  void removeFromQueue(int surahOrder) {
    _queue.remove(surahOrder);
    _queueNotifier.value = List.from(_queue);
  }

  void clearQueue() {
    _queue.clear();
    _queueNotifier.value = [];
  }

  int? getNext({bool peek = false}) {
    if (_queue.isEmpty) return null;
    if (peek) {
      return _queue.first;
    }
    return _queue.removeAt(0);
  }

  bool contains(int surahOrder) => _queue.contains(surahOrder);
}

