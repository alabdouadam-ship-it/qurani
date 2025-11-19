class MediaItem {
  final String id;
  final String? title;
  final String? album;
  final Uri? artUri;
  final Map<String, Object?>? extras;

  const MediaItem({
    required this.id,
    this.title,
    this.album,
    this.artUri,
    this.extras,
  });
}


