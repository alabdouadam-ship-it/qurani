import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/hadith_model.dart';
import 'package:qurani/services/hadith_service.dart';
import 'package:qurani/services/chapter_translation_service.dart';
import 'package:qurani/services/hadith_grade_translation_service.dart';

class HadithReadScreen extends StatefulWidget {
  final String bookId;
  final String bookName;

  const HadithReadScreen({
    super.key,
    required this.bookId,
    required this.bookName,
  });

  @override
  State<HadithReadScreen> createState() => _HadithReadScreenState();
}

class _HadithReadScreenState extends State<HadithReadScreen> {
  final HadithService _hadithService = HadithService();
  HadithBook? _book;
  List<Hadith> _visibleHadiths = [];
  bool _isLoading = true;
  String? _errorMessage;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      final book = await _hadithService.loadBook(widget.bookId);
      if (mounted) {
        setState(() {
          _book = book;
          // Filter out hadiths with empty text
          _visibleHadiths = book.hadiths.where((h) => h.text.trim().isNotEmpty).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _goToHadithNumber() async {
    if (_visibleHadiths.isEmpty) return;

    final controller = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.search),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.enterHadithNumber, 
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              final num = int.tryParse(controller.text);
              Navigator.pop(context, num);
            },
            child: Text(AppLocalizations.of(context)!.goButton),
          ),
        ],
      ),
    );

    if (result != null) {
      // Find index in VISIBLE hadiths
      final index = _visibleHadiths.indexWhere((h) => h.hadithnumber == result);
      if (index != -1) {
        _pageController.jumpToPage(index);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(AppLocalizations.of(context)!.hadithHiddenOrNotFound)),
          );
        }
      }
    }
  }

  void _showChapters() {
    if (_book == null || _book!.metadata.sections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('No chapters available')),
        );
        return;
    }

    final sections = _book!.metadata.sections.entries.toList();
    sections.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
               padding: const EdgeInsets.all(16),
               child: Text(
                 AppLocalizations.of(context)!.chapters,
                 style: Theme.of(context).textTheme.titleLarge,
               ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: sections.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
                itemBuilder: (context, index) {
                  final sectionId = sections[index].key;
                  if (sectionId == '0' && _shouldHideChapterZero()) {
                    return const SizedBox.shrink(); // Hide item
                  }

                  final originalName = sections[index].value;
                  String sectionName;
                  if (sectionId == '0' || originalName.trim().isEmpty) {
                    sectionName = AppLocalizations.of(context)!.generalHadiths;
                  } else {
                    sectionName = ChapterTranslationService.translate(originalName, _getContentLocale());
                  }
                  
                  return ListTile(
                    title: Text(sectionName),
                    leading: CircleAvatar(
                      radius: 12,
                      child: Text(sectionId, style: const TextStyle(fontSize: 10)),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _jumpToSection(sectionId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _jumpToSection(String sectionId) {
    final l10n = AppLocalizations.of(context)!;
    // Find the first VISIBLE hadith that belongs to this section
    final index = _visibleHadiths.indexWhere((h) => h.reference?.book.toString() == sectionId);
    if (index != -1) {
       _pageController.jumpToPage(index);
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.chapterStartNotFound)),
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.bookName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.bookName)),
        body: Center(child: Text('Error: $_errorMessage')),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
             Text(widget.bookName, style: const TextStyle(fontSize: 16)),
             if (_book != null)
               Text(
                 '${_currentPage + 1} / ${_visibleHadiths.length}', 
                 style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)
               ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.search,
            onPressed: () {
               if (_visibleHadiths.isNotEmpty) {
                 showSearch(
                   context: context, 
                   delegate: HadithSearchDelegate(
                     _visibleHadiths, 
                     _pageController, 
                     _book!.metadata, 
                     _getContentLocale(),
                     hideChapterZero: _shouldHideChapterZero(),
                   )
                 );
               }
            },
          ),
        ],
      ),
      body: _visibleHadiths.isEmpty
        ? Center(child: Text(l10n.noReadableContent))
        : PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _visibleHadiths.length,
            itemBuilder: (context, index) {
               return _buildHadithPage(_visibleHadiths[index], widget.bookId, _book!.metadata);
            },
          ),
    );
  }

  bool _shouldHideChapterZero() {
    final id = widget.bookId.toLowerCase();
    return id.contains('nawawi') || 
           id.contains('qudsi') || 
           id.contains('dehlawi') ||
           id.contains('malik') ||
           id.contains('nasai') ||
           id.contains('abudawud') ||
           id.contains('tirmidhi');
  }

  Locale _getContentLocale() {
    // If bookId starts with ara-, eng-, fra-, use that language
    if (widget.bookId.startsWith('ara-')) return const Locale('ar');
    if (widget.bookId.startsWith('eng-')) return const Locale('en');
    if (widget.bookId.startsWith('fra-')) return const Locale('fr'); // widget.bookId technically, but let's be consistent
    return Localizations.localeOf(context);
  }

  Widget _buildHadithPage(Hadith hadith, String bookId, HadithBookMetadata metadata) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    
    // Determine validity grade based on CONTENT language
    String? gradeStr;
    Color gradeColor = Colors.green;

    final contentLocale = _getContentLocale();

    if (bookId.contains('bukhari') || bookId.contains('muslim')) {
       gradeStr = HadithGradeTranslationService.translateGrade('Sahih', contentLocale);
    } else if (hadith.grades.isNotEmpty) {
       gradeStr = hadith.grades.map((g) {
         final scholar = HadithGradeTranslationService.translateScholar(g.name, contentLocale);
         final grade = HadithGradeTranslationService.translateGrade(g.grade, contentLocale);
         return '$scholar: $grade';
       }).join('\n');
       
       final firstGrade = hadith.grades.first.grade.toLowerCase();
       if (firstGrade.contains('sahih')) {
         gradeColor = Colors.green;
       } else if (firstGrade.contains('hasan')) {
         gradeColor = Colors.orange;
       } else if (firstGrade.contains('daif') || firstGrade.contains('weak')) {
         gradeColor = Colors.red;
       } else {
         gradeColor = Colors.grey;
       }
    }

    // Resolve Section Name
    String sectionName = '';
    if (hadith.reference != null) {
      final sectionId = hadith.reference!.book.toString();
      final englishTitle = metadata.sections[sectionId] ?? '';
      if (sectionId == '0' || englishTitle.trim().isEmpty) {
        sectionName = l10n.generalHadiths;
      } else {
        sectionName = ChapterTranslationService.translate(englishTitle, contentLocale);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Hadith Number & Chapter/Book Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Clickable Hadith Number
              InkWell(
                onTap: _goToHadithNumber,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${l10n.hadith} ${hadith.hadithnumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
              
              // Clickable Section/Book Name
              if (sectionName.isNotEmpty)
                Flexible(
                  child: InkWell(
                    onTap: _showChapters,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              sectionName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                                decorationStyle: TextDecorationStyle.dotted,
                              ),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (hadith.reference != null)
                Text(
                  '${l10n.book}: ${hadith.reference!.book}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          
          const Divider(height: 32),
          
          // Hadith Text
          SelectableText(
            hadith.text,
            style: theme.textTheme.headlineSmall?.copyWith(
              height: 1.6,
              fontFamily: 'Amiri Quran',
            ),
            textAlign: TextAlign.justify,
            textDirection: TextDirection.rtl, // Should probably verify based on language
          ),
          
          const SizedBox(height: 24),
          
          // Grading Footer
          if (gradeStr != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: gradeColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                     l10n.grade,
                     style: TextStyle(
                       fontWeight: FontWeight.bold,
                       color: gradeColor,
                       fontSize: 12,
                     ),
                   ),
                   const SizedBox(height: 4),
                   Text(
                     gradeStr,
                     style: TextStyle(color: gradeColor),
                   ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HadithSearchDelegate extends SearchDelegate {
  final List<Hadith> _visibleHadiths;
  final PageController pageController;
  final HadithBookMetadata metadata;
  final Locale contentLocale;
  final bool hideChapterZero;
  String? _selectedSectionId;

  HadithSearchDelegate(
    this._visibleHadiths, 
    this.pageController, 
    this.metadata, 
    this.contentLocale, {
    this.hideChapterZero = false,
  });

  // Regex to match Arabic diacritics
  static final RegExp _diacriticsRegExp = RegExp(r'[\u064B-\u065F\u0670]');

  String _normalize(String input) {
    return input.replaceAll(_diacriticsRegExp, '');
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.filter_list),
        tooltip: AppLocalizations.of(context)!.chapters,
        onPressed: () async {
          final sections = metadata.sections.entries.where((e) {
            if (hideChapterZero && e.key == '0') return false;
            return true;
          }).toList();
          sections.sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

          final selected = await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.chapters),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sections.length + 1, // +1 for "All Chapters"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        title: Text(AppLocalizations.of(context)!.allChapters), 
                        leading: _selectedSectionId == null 
                            ? const Icon(Icons.check, color: Colors.green)
                            : const Icon(Icons.list),
                        onTap: () {
                          Navigator.pop(context, 'CLEAR_FILTER');
                        },
                      );
                    }

                    final sectionEntry = sections[index - 1];
                    final sectionId = sectionEntry.key;
                    final originalName = sectionEntry.value;
                    String sectionName;
                    if (sectionId == '0' || originalName.trim().isEmpty) {
                      sectionName = AppLocalizations.of(context)!.generalHadiths;
                    } else {
                      sectionName = ChapterTranslationService.translate(originalName, contentLocale);
                    }
                    
                    return ListTile(
                      title: Text(sectionName),
                      leading: _selectedSectionId == sectionId 
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                      onTap: () {
                        Navigator.pop(context, sectionId);
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
              ],
            ),
          );

          if (selected != null && context.mounted) {
            _selectedSectionId = selected == 'CLEAR_FILTER' ? null : selected;
            showResults(context); // Force rebuild
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.trim().isEmpty && _selectedSectionId == null) {
      return const Center(child: Text('Enter text to search or select a chapter'));
    }

    final normalizedQuery = _normalize(query);
    final results = _visibleHadiths.where((h) {
      // Filter by section if set
      if (_selectedSectionId != null) {
        if (h.reference?.book.toString() != _selectedSectionId) {
          return false;
        }
      }

      // Filter by text if query is not empty
      if (query.trim().isNotEmpty) {
        if (h.text.isNotEmpty) {
          final normalizedText = _normalize(h.text);
          if (!normalizedText.contains(normalizedQuery)) return false;
        } else {
          return false;
        }
      }
      
      return true;
    }).toList();

    return Column(
      children: [
        if (_selectedSectionId != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(
                _selectedSectionId == '0' 
                    ? AppLocalizations.of(context)!.generalHadiths 
                    : ChapterTranslationService.translate(
                        metadata.sections[_selectedSectionId] ?? '', 
                        contentLocale // Use proper locale for chip too!
                      )
              ),
              onDeleted: () {
                _selectedSectionId = null;
                showResults(context); // Force rebuild
              },
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? const Center(child: Text('No matches found'))
              : ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final hadith = results[index];
                    final displayText = hadith.text.length > 100 
                        ? '${hadith.text.substring(0, 100)}...' 
                        : hadith.text;
                        
                    return ListTile(
                      title: Text('${AppLocalizations.of(context)!.hadith} ${hadith.hadithnumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        displayText,
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Amiri Quran'),
                      ),
                      onTap: () {
                        // Find index in VISIBLE list
                        final originalIndex = _visibleHadiths.indexOf(hadith);
                        if (originalIndex != -1) {
                          pageController.jumpToPage(originalIndex);
                          close(context, null);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
