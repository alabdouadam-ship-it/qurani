import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../models/news_item.dart';
import '../widgets/modern_ui.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';

class NewsCard extends StatefulWidget {
  final NewsItem item;
  final bool isSaved;
  final bool isNew;
  final VoidCallback onToggleSave;

  const NewsCard({
    super.key,
    required this.item,
    required this.isSaved,
    required this.isNew,
    required this.onToggleSave,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ModernSurfaceCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: widget.item.backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Media Section
            if (widget.item.type != NewsType.text) _buildMedia(context),

            // 2. Content Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Directionality(
                          textDirection: widget.item.isRtl ? TextDirection.rtl : TextDirection.ltr,
                          child: Row(
                            children: [
                              if (widget.isNew)
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.newItemBadge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  widget.item.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          widget.isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: widget.isSaved ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: widget.onToggleSave,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Rich Text Description with Show More/Less
                  _buildDescription(context),
                  
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(widget.item.publishDate),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                        ),
                      ),
                      if (widget.item.sourceUrl.trim().isNotEmpty)
                        TextButton(
                          onPressed: () => _launchURL(widget.item.sourceUrl),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.newsSource,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedia(BuildContext context) {
    if (widget.item.type == NewsType.image) {
      return _buildImage(context);
    } else if (widget.item.type == NewsType.youtube) {
      return _buildYoutubeThumbnail(context);
    }
    return const SizedBox.shrink();
  }

  Widget _buildImage(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: CachedNetworkImage(
        imageUrl: widget.item.mediaUrl,
        height: 180,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) => _buildPlaceholder(),
        fadeInDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  Widget _buildYoutubeThumbnail(BuildContext context) {
    final videoId = _extractYoutubeId(widget.item.mediaUrl);
    final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

    return GestureDetector(
      onTap: () => _playVideo(context, widget.item.mediaUrl),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: CachedNetworkImage(
              imageUrl: thumbnailUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildPlaceholder(),
              errorWidget: (context, url, error) => _buildPlaceholder(),
              fadeInDuration: const Duration(milliseconds: 500),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(150),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(50),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
    );
  }

  Widget _buildDescription(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface.withAlpha(210),
      height: 1.5,
    );

    // Check if text is long enough to need expansion
    final isLongText = widget.item.description.length > 150;

    return Directionality(
      textDirection: widget.item.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.item.description,
            maxLines: _isExpanded ? null : 3,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: style,
          ),
          if (isLongText)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  _isExpanded 
                    ? AppLocalizations.of(context)!.showLess 
                    : AppLocalizations.of(context)!.showMore,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    try {
      final locale = Localizations.localeOf(context).toString();
      return intl.DateFormat.yMMMMd(locale).format(date);
    } catch (e) {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _extractYoutubeId(String url) {
    RegExp regExp = RegExp(
      r'^(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    final match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<void> _playVideo(BuildContext context, String url) async {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) {
        final videoId = _extractYoutubeId(url);
        final embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=1&origin=https://qurani.info';
        
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36')
          ..setBackgroundColor(Colors.black);

        // Enable autoplay for Android (Samsumg/Mobile focus)
        if (controller.platform is AndroidWebViewController) {
          (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
        }

        controller.loadRequest(
          Uri.parse('$embedUrl&mute=0&rel=0&showinfo=0'),
          headers: {
            'referer': 'https://qurani.info',
          },
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.width * 9 / 16 + 80, // Aspect ratio + padding
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: WebViewWidget(controller: controller),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
