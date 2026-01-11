import 'package:uuid/uuid.dart';

class AudioBookmark {
  final String id;
  final int surahId;
  final int positionMs;
  final int createdAt;
  final String? reciterId;
  final String? note; // Optional user note

  AudioBookmark({
    required this.id,
    required this.surahId,
    required this.positionMs,
    required this.createdAt,
    this.reciterId,
    this.note,
  });

  factory AudioBookmark.create({
    required int surahId,
    required int positionMs,
    String? reciterId,
    String? note,
  }) {
    return AudioBookmark(
      id: const Uuid().v4(),
      surahId: surahId,
      positionMs: positionMs,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      reciterId: reciterId,
      note: note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'surahId': surahId,
      'positionMs': positionMs,
      'createdAt': createdAt,
      'reciterId': reciterId,
      'note': note,
    };
  }

  factory AudioBookmark.fromJson(Map<String, dynamic> json) {
    return AudioBookmark(
      id: json['id'] as String,
      surahId: json['surahId'] as int,
      positionMs: json['positionMs'] as int,
      createdAt: json['createdAt'] as int,
      reciterId: json['reciterId'] as String?,
      note: json['note'] as String?,
    );
  }
}
