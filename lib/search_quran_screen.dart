import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:qurani/services/media_item_compat.dart';
import 'package:flutter/services.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/audio_service.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/quran_search_service.dart';
import 'package:qurani/services/net_utils.dart';
import 'package:qurani/services/reciter_config_service.dart';

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
  int? _selectedSurah; // null = all Quran
  Map<int, String> _surahNames = {};
  Map<int, String> _surahNamesEn = {};
  String _selectedLanguage = 'ar'; // 'ar', 'en', 'fr'

  @override
  void initState() {
    super.initState();
    _loadSurahNames();
  }

  Future<void> _loadSurahNames() async {
    // Trigger search service initialization to load surah names
    await QuranSearchService.instance.search('');
    if (mounted) {
      setState(() {
        _surahNames = QuranSearchService.instance.surahNames;
        _surahNamesEn = QuranSearchService.instance.surahNamesEn;
      });
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    _focusNode.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    final l10n = AppLocalizations.of(context)!;
    // Preserve single spaces at start/end (helps search for standalone words)
    // but collapse multiple consecutive spaces to one
    // but collapse multiple consecutive spaces to one
    final q = query.replaceAll(RegExp(r' {2,}'), ' ');
    final normalized = QuranSearchService.normalize(q, language: _selectedLanguage);
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
      final res = await QuranSearchService.instance.search(q, surahOrder: _selectedSurah, language: _selectedLanguage);
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

    final normalizedQuery = QuranSearchService.normalize(query, language: _selectedLanguage);
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
      final normalizedSegment = QuranSearchService.normalize(segment, language: _selectedLanguage);
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
      String reciter;
      
      // Use translated audio if searching in English or French
      if (_selectedLanguage == 'en') {
        reciter = 'arabic_english';
      } else if (_selectedLanguage == 'fr') {
        reciter = 'arabic_french';
      } else {
        reciter = PreferencesService.getReciter();
      }
      
      // Check if selected reciter has ayah-by-ayah audio
      // If not, fallback to Alafasy (afs)
      final reciterConfig = await ReciterConfigService.getReciter(reciter);
      // For translations, we know they have verse-by-verse, but safer to check existing logic
      if (reciterConfig == null || !reciterConfig.hasVerseByVerse()) {
        debugPrint('Reciter $reciter has no ayah audio, falling back to Alafasy');
        reciter = 'afs'; // Alafasy
      }
      
      final uri = await AudioService.getVerseUriPreferLocal(
        reciterKeyAr: reciter,
        surahOrder: ayah.surahOrder,
        verseNumber: ayah.numberInSurah,
      );
      
      if (_isDisposed || !mounted) return;

      if (uri == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingAudio)),
        );
        return;
      }

      // If this is a network URL and there is no internet, show a clear message
      if (uri.scheme != 'file') {
        final hasNet = await _hasInternet();
        if (_isDisposed || !mounted) return;
        
        if (!hasNet) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.audioInternetRequired)),
          );
          return;
        }
      }

      debugPrint('Playing audio from: $uri');

      // Stop any current playback
      try {
        if (!_isDisposed) {
          await _player.stop();
        }
      } catch (_) {
        // Ignore errors from stop
      }
      
      if (_isDisposed) return;

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
      
      if (_isDisposed) return;

      final playlist = ConcatenatingAudioSource(children: sources);
      if (!_isDisposed) {
        await _player.setAudioSource(playlist, preload: true);
        if (!_isDisposed) {
          await _player.play();
        }
      }
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      debugPrint('Audio playback error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (!mounted) return;
      // We already captured messenger, but check mounted for SnackBar safety
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
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                dropdownColor: theme.appBarTheme.backgroundColor ?? theme.primaryColor,
                icon: const Icon(Icons.language, color: Colors.white),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
                items: [
                   DropdownMenuItem(
                     value: 'ar', 
                     child: Text(
                       l10n.searchLanguageArabic, 
                       style: TextStyle(color: _selectedLanguage == 'ar' ? theme.colorScheme.secondary : null),
                     ),
                   ),
                   DropdownMenuItem(
                     value: 'en', 
                     child: Text(
                       l10n.searchLanguageEnglish,
                       style: TextStyle(color: _selectedLanguage == 'en' ? theme.colorScheme.secondary : null),
                     ),
                   ),
                   DropdownMenuItem(
                     value: 'fr', 
                     child: Text(
                       l10n.searchLanguageFrench,
                       style: TextStyle(color: _selectedLanguage == 'fr' ? theme.colorScheme.secondary : null),
                     ),
                   ),
                ],
                onChanged: (val) {
                  if (val != null && val != _selectedLanguage) {
                    setState(() {
                       _selectedLanguage = val;
                       _results = []; // Clear results on language change
                       _lastQuery = '';
                       _isSearching = false;
                       _controller.clear();
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
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
          // Surah filter dropdown
          if (_surahNames.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    '${l10n.filterBySurah}:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _selectedSurah,
                      isExpanded: true,
                      isDense: true,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l10n.allQuran),
                        ),
                        ..._surahNames.entries.map((e) {
                          // Use English/Latin names for English/French, Arabic for Arabic
                          final langCode = Localizations.localeOf(context).languageCode;
                          final name = (langCode == 'ar') 
                              ? e.value 
                              : (_surahNamesEn[e.key] ?? e.value);
                          return DropdownMenuItem<int?>(
                            value: e.key,
                            child: Text(
                              '${e.key}. $name',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSurah = value;
                        });
                        // Re-run search if there's a query
                        if (_lastQuery.isNotEmpty) {
                          _doSearch(_lastQuery);
                        }
                      },
                    ),
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
                                      textDirection: _selectedLanguage == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
                                          textAlign: _selectedLanguage == 'ar' ? TextAlign.right : TextAlign.left,
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
