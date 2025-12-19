import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/services/media_item_compat.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_search_service.dart';
import 'package:qurani/services/net_utils.dart';

class SearchQuranScreen extends StatefulWidget {
  const SearchQuranScreen({super.key});

  @override
  State<SearchQuranScreen> createState() => _SearchQuranScreenState();
}

class _SearchQuranScreenState extends State<SearchQuranScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final AudioPlayer _player = AudioPlayer();
  List<SearchAyah> _results = const <SearchAyah>[];
  int _totalOccurrences = 0;
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    final l10n = AppLocalizations.of(context)!;
    final q = query.trim();
    final normalized = QuranSearchService.normalize(q);
    if (normalized.length < 2) {
      setState(() => _results = const <SearchAyah>[]);
      if (normalized.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.searchTooShort)),
        );
      }
      return;
    }
    setState(() {
      _isSearching = true;
      _lastQuery = q;
    });
    try {
      final res = await QuranSearchService.instance.search(q);
      if (!mounted) return;
      setState(() {
        _results = res.ayahs;
        _totalOccurrences = res.totalOccurrences;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Search error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unknownError)),
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  InlineSpan _buildHighlightedText(String text, String query, ColorScheme colorScheme) {
    if (text.isEmpty) {
      return const TextSpan(text: '');
    }

    final normalizedQuery = QuranSearchService.normalize(query);
    if (normalizedQuery.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: colorScheme.onSurface),
      );
    }

    final StringBuffer normalizedBuffer = StringBuffer();
    final List<int> startIndices = <int>[];
    final List<int> endIndices = <int>[];
    int offset = 0;
    for (final rune in text.runes) {
      final segment = String.fromCharCode(rune);
      final normalizedSegment = QuranSearchService.normalize(segment);
      final segmentLength = segment.length;
      final nextOffset = offset + segmentLength;

      if (normalizedSegment.isNotEmpty) {
        for (int i = 0; i < normalizedSegment.length; i++) {
          normalizedBuffer.write(normalizedSegment[i]);
          startIndices.add(offset);
          endIndices.add(nextOffset);
        }
      }
      offset = nextOffset;
    }

    final normalizedText = normalizedBuffer.toString();
    if (normalizedText.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: colorScheme.onSurface),
      );
    }

    final List<TextSpan> spans = <TextSpan>[];
    int lastOriginalIndex = 0;
    int searchStart = 0;

    while (true) {
      final matchIndex = normalizedText.indexOf(normalizedQuery, searchStart);
      if (matchIndex == -1) {
        break;
      }

      final matchStartOriginal = startIndices[matchIndex];
      final matchEndOriginal = endIndices[matchIndex + normalizedQuery.length - 1];

      if (matchStartOriginal > lastOriginalIndex) {
        spans.add(TextSpan(
          text: text.substring(lastOriginalIndex, matchStartOriginal),
          style: TextStyle(color: colorScheme.onSurface),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(matchStartOriginal, matchEndOriginal),
        style: TextStyle(
          backgroundColor: colorScheme.primary.withAlpha((255 * 0.4).round()),
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ));

      lastOriginalIndex = matchEndOriginal;
      searchStart = matchIndex + normalizedQuery.length;
    }

    if (spans.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: colorScheme.onSurface),
      );
    }

    if (lastOriginalIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastOriginalIndex),
        style: TextStyle(color: colorScheme.onSurface),
      ));
    }

    return TextSpan(children: spans);
  }

  Future<void> _playAyah(SearchAyah ayah) async {
    final l10n = AppLocalizations.of(context)!;
    // Capture context-dependent values before any await
    final langCode = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    
    try {
      final reciter = PreferencesService.getReciter();
      final uri = await AudioService.getVerseUriPreferLocal(
        reciterKeyAr: reciter,
        surahOrder: ayah.surahOrder,
        verseNumber: ayah.numberInSurah,
      );
      if (uri == null) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingAudio)),
        );
        return;
      }

      // If this is a network URL and there is no internet, show a clear message
      if (uri.scheme != 'file') {
        final hasNet = await _hasInternet();
        if (!hasNet) {
          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.audioInternetRequired)),
          );
          return;
        }
      }

      debugPrint('Playing audio from: $uri');

      // Stop any current playback
      try {
        await _player.stop();
      } catch (_) {
        // Ignore errors from stop
      }

      // Get surah name for MediaItem
      final surahName = QuranSearchService.instance.surahName(ayah.surahOrder);
      final reciterName = AudioService.reciterDisplayName(reciter, langCode);

      // Create MediaItem (required for just_audio_background)
      final mediaItem = MediaItem(
        id: '${reciter}_${ayah.surahOrder}_${ayah.numberInSurah}',
        title: '$surahName • Ayah ${ayah.numberInSurah}',
        album: reciterName,
        artUri: null,
        extras: {
          'surahOrder': ayah.surahOrder,
          'verseNumber': ayah.numberInSurah,
        },
      );

      // Create a single-item playlist with MediaItem tag
      final sources = <AudioSource>[];
      sources.add(AudioSource.uri(uri, tag: mediaItem));

      if (sources.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingAudio)),
        );
        return;
      }

      final playlist = ConcatenatingAudioSource(children: sources);
      await _player.setAudioSource(playlist, preload: true);
      await _player.play();
    } catch (e, stackTrace) {
      debugPrint('Audio playback error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final hasNet = await _hasInternet();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(hasNet ? l10n.errorLoadingAudio : l10n.audioInternetRequired)),
      );
    }
  }

  Future<bool> _hasInternet() => NetUtils.hasInternet();

  Future<void> _copyAyah(SearchAyah ayah) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: ayah.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.copiedToClipboard)),
    );
  }

  Widget _buildNoResultsPlaceholder(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFound,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdlePlaceholder(
    AppLocalizations l10n,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.travel_explore,
              size: 48,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.searchQuran,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasQuery = _lastQuery.trim().isNotEmpty;
    final showNoResults = !_isSearching && hasQuery && _results.isEmpty;
    final showResultsHeader = hasQuery && (_results.isNotEmpty || showNoResults);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.searchQuran),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _doSearch,
                    decoration: InputDecoration(
                      hintText: l10n.searchQuran,
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isSearching ? null : () => _doSearch(_controller.text),
                  child: _isSearching
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.search),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Column(
              children: [
                if (showResultsHeader) ...[
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withAlpha((255 * 0.85).round()),
                      border: Border(
                        bottom: BorderSide(
                          color: colorScheme.outlineVariant.withAlpha((255 * 0.4).round()),
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: colorScheme.onPrimaryContainer.withAlpha((255 * 0.15).round()),
                          child: Icon(
                            Icons.manage_search,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.searchResultsDetailed(
                                  showNoResults ? 0 : _totalOccurrences,
                                  showNoResults ? 0 : _results.length,
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_lastQuery.isNotEmpty)
                                Text(
                                  '"${_lastQuery.trim()}"',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer.withAlpha((255 * 0.8).round()),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
                Expanded(
                  child: showNoResults
                      ? _buildNoResultsPlaceholder(l10n, theme, colorScheme)
                      : _results.isEmpty
                          ? _buildIdlePlaceholder(l10n, theme, colorScheme)
                          : ListView.builder(
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                final a = _results[index];
                                final surahName = QuranSearchService.instance.surahName(a.surahOrder);
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    title: Directionality(
                                      textDirection: TextDirection.rtl,
                                      child: DefaultTextStyle(
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                              fontSize: PreferencesService.getFontSize(),
                                              height: 1.8,
                                              color: colorScheme.onSurface,
                                            ) ??
                                            TextStyle(
                                              fontSize: PreferencesService.getFontSize(),
                                              height: 1.8,
                                              color: colorScheme.onSurface,
                                            ),
                                        child: RichText(
                                          textAlign: TextAlign.right,
                                          text: _buildHighlightedText(a.text, _lastQuery, colorScheme),
                                        ),
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        '$surahName • ${a.numberInSurah} • ${l10n.juzLabel} ${a.juz}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.content_copy),
                                          onPressed: () => _copyAyah(a),
                                          tooltip: 'Copy',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.play_arrow),
                                          onPressed: () => _playAyah(a),
                                          tooltip: 'Play',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
