import 'package:uuid/uuid.dart';

class TasbeehItem {
  /// NB: [count] is intentionally non-final. The Tasbeeh UI optimistically
  /// increments it in-place on each tap for immediate visual feedback, while
  /// the authoritative value lives in SQLite via atomic `count = count + 1`.
  /// A concurrent `_loadData()` will overwrite the optimistic value with the
  /// DB truth — this is acceptable because both converge to the same number.
  String id;
  String text;
  int count;

  TasbeehItem({
    required this.id,
    required this.text,
    this.count = 0,
  });

  factory TasbeehItem.create(String text) {
    return TasbeehItem(
      id: const Uuid().v4(),
      text: text,
      count: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'count': count,
    };
  }

  factory TasbeehItem.fromJson(Map<String, dynamic> json) {
    return TasbeehItem(
      id: json['id'] as String,
      text: json['text'] as String,
      count: json['count'] as int? ?? 0,
    );
  }
}

class TasbeehGroup {
  String id;
  String name;
  bool isCustom;
  List<TasbeehItem> items;

  TasbeehGroup({
    required this.id,
    required this.name,
    this.isCustom = false,
    required this.items,
  });

  factory TasbeehGroup.create(String name, {bool isCustom = true}) {
    return TasbeehGroup(
      id: const Uuid().v4(),
      name: name,
      isCustom: isCustom,
      items: [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isCustom': isCustom,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }

  factory TasbeehGroup.fromJson(Map<String, dynamic> json) {
    return TasbeehGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      isCustom: json['isCustom'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => TasbeehItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
