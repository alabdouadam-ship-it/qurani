import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/hadith_model.dart';
import 'package:qurani/services/hadith_service.dart';
import 'package:qurani/hadith_read_screen.dart';

class HadithBooksScreen extends StatefulWidget {
  const HadithBooksScreen({super.key});

  @override
  State<HadithBooksScreen> createState() => _HadithBooksScreenState();
}

class _HadithBooksScreenState extends State<HadithBooksScreen> {
  // Default language matches app language or fallback to English
  String _selectedLanguage = 'Arabic'; 
  late Future<List<HadithEditionEntry>> _editionsFuture;
  final HadithService _hadithService = HadithService();
  
  // Track download progress
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _editionsFuture = _hadithService.loadEditions();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial language based on locale if not already set by user interaction?
    // Actually, user might want to switch languages independently of app locale.
    // But initially, let's try to match app locale.
    final locale = Localizations.localeOf(context).languageCode;
    if (_selectedLanguage == 'Arabic' && locale == 'en') _selectedLanguage = 'English';
    if (_selectedLanguage == 'Arabic' && locale == 'fr') _selectedLanguage = 'French';
  }

  void _onLanguageSelected(String language) {
    setState(() {
      _selectedLanguage = language;
    });
  }

  Future<void> _handleBookTap(HadithCollection collection, String bookName) async {
    final l10n = AppLocalizations.of(context)!;
    
    // 1. Check availability
    // final isAvailable = await _hadithService.isBookAvailable(collection.id);
    final isAvailable = await _hadithService.verifyBookIntegrity(collection.id);
    
    if (isAvailable) {
      // Open Reader
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HadithReadScreen(
            bookId: collection.id,
            bookName: bookName,
          ),
        ),
      );
    } else {
      // Prompt Download
      if (!mounted) return;
      
      // Fetch size
      String sizeInfo = '';
      try {
        final size = await _hadithService.getBookSize(collection.link);
        if (size != null) {
          sizeInfo = '\n\n${l10n.fileSize}: $size';
        }
      } catch (_) {}
      
      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.downloadBook),
          content: Text('${l10n.bookNotAvailable}$sizeInfo'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.downloadBook),
            ),
          ],
        ),
      );
      
      if (confirm == true) {
        _downloadBook(collection);
      }
    }
  }

  Future<void> _downloadBook(HadithCollection collection) async {
    setState(() {
      _downloadProgress[collection.id] = 0.0;
    });
    
    try {
      await _hadithService.downloadBook(
        collection.id, 
        collection.link,
        onProgress: (received, total) {
           if (total != -1) {
             setState(() {
               _downloadProgress[collection.id] = received / total;
             });
           }
        },
      );
      
      if (mounted) {
        setState(() {
          _downloadProgress.remove(collection.id);
        });
        // Auto open after download? Or let user tap again.
        // Let's let user tap again to be safe, or show success snackbar.
        // Or just open it? The user explicitly asked to "download then browse".
        // Let's just finish download and let UI reflect availability (we need to trigger a rebuild which setState does).
      }
    } catch (e) {
      if (mounted) {
        setState(() {
           _downloadProgress.remove(collection.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.bookUnavailableMessage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hadithLibrary),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Language Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LanguageChip(
                  label: l10n.booksInArabic,
                  isSelected: _selectedLanguage == 'Arabic',
                  onTap: () => _onLanguageSelected('Arabic'),
                ),
                const SizedBox(width: 12),
                _LanguageChip(
                  label: l10n.booksInEnglish,
                  isSelected: _selectedLanguage == 'English',
                  onTap: () => _onLanguageSelected('English'),
                ),
                const SizedBox(width: 12),
                _LanguageChip(
                  label: l10n.booksInFrench,
                  isSelected: _selectedLanguage == 'French',
                  onTap: () => _onLanguageSelected('French'),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<HadithEditionEntry>>(
              future: _editionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                final editions = snapshot.data ?? [];
                final categorized = _hadithService.categorizeBooks(editions);
                
                // We need to filter editions that HAVE the selected language
                // categorized map values are List<HadithEditionEntry>.
                // We need to display them if they have a collection with language == _selectedLanguage
                
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCategorySection(l10n.sahihain, categorized['Sahihain']!),
                      _buildCategorySection(l10n.sunan, categorized['Sunan']!),
                      _buildCategorySection(l10n.others, categorized['Others']!),
                      const SizedBox(height: 32),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(String title, List<HadithEditionEntry> books) {
    // Filter books that match selected language
    final filteredBooks = books.where((book) {
      return book.collection.any((c) => c.language.toLowerCase() == _selectedLanguage.toLowerCase());
    }).toList();

    if (filteredBooks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // Adaptive Grid:
            // Calculate crossAxisCount based on available width
            // Assume ideal item width is around 160-180
            const double itemWidth = 170;
            final int crossAxisCount = (constraints.maxWidth / itemWidth).floor().clamp(2, 6); // Min 2 columns

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85, // Adjust based on card content
              ),
              itemCount: filteredBooks.length,
              itemBuilder: (context, index) {
                final book = filteredBooks[index];
                final collection = book.collection.firstWhere(
                  (c) => c.language.toLowerCase() == _selectedLanguage.toLowerCase()
                );
                
                final isDownloading = _downloadProgress.containsKey(collection.id);
                final progress = isDownloading ? _downloadProgress[collection.id]! : 0.0;
                
                final displayName = (_selectedLanguage.toLowerCase() == 'arabic' && book.namear != null && book.namear!.isNotEmpty)
                    ? book.namear!
                    : book.name;

                  final style = _getBookStyle(collection.id);

                return _BookCard(
                  title: displayName,
                  collection: collection,
                  isDownloading: isDownloading,
                  progress: progress,
                  onTap: () => _handleBookTap(collection, displayName),
                  color: style.color,
                  icon: style.icon,
                );
              },
            );
          }
        ),
      ],
    );
  }

  ({Color color, IconData icon}) _getBookStyle(String bookId) {
    final id = bookId.toLowerCase();
    if (id.contains('bukhari')) {
      return (color: const Color(0xFF2E7D32), icon: Icons.menu_book_rounded); // Green 800
    } else if (id.contains('muslim')) {
      return (color: const Color(0xFF00695C), icon: Icons.menu_book_rounded); // Teal 800
    } else if (id.contains('dawud')) {
      return (color: const Color(0xFF1565C0), icon: Icons.library_books_rounded); // Blue 800
    } else if (id.contains('tirmidhi')) {
      return (color: const Color(0xFF6A1B9A), icon: Icons.library_books_rounded); // Purple 800
    } else if (id.contains('nasai')) {
      return (color: const Color(0xFF283593), icon: Icons.library_books_rounded); // Indigo 800
    } else if (id.contains('majah')) {
      return (color: const Color(0xFFC62828), icon: Icons.library_books_rounded); // Red 800
    } else if (id.contains('malik')) {
      return (color: const Color(0xFF8D6E63), icon: Icons.history_edu_rounded); // Brown 400
    } else if (id.contains('nawawi')) {
      return (color: const Color(0xFF00838F), icon: Icons.format_quote_rounded); // Cyan 800
    } else if (id.contains('qudsi')) {
      return (color: const Color(0xFF4527A0), icon: Icons.auto_awesome_rounded); // Deep Purple
    }
    return (color: const Color(0xFF424242), icon: Icons.book_rounded); // Grey as default
  }
}

class _BookCard extends StatelessWidget {
  final String title;
  final HadithCollection collection;
  final bool isDownloading;
  final double progress;
  final VoidCallback onTap;
  final Color color;
  final IconData icon;

  const _BookCard({
    required this.title,
    required this.collection,
    required this.isDownloading,
    required this.progress,
    required this.onTap,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Premium styling
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2), // Use book color for shadow
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        gradient: LinearGradient(
          colors: isDark 
              ? [theme.colorScheme.surfaceContainerHighest, theme.colorScheme.surface]  
              : [color.withValues(alpha: 0.05), Colors.white], // Tint background with book color
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDownloading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon / Graphic
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.1), // Tint circle
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: color, // Use book color for icon
                  ),
                ),
                const Spacer(),
                
                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Amiri Quran',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                
                const Spacer(),
                
                // Action / Status
                if (isDownloading)
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress, 
                        borderRadius: BorderRadius.circular(4),
                        color: color, // Progress color matches book
                        backgroundColor: color.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 4),
                      Text('${(progress * 100).toInt()}%', style: theme.textTheme.labelSmall),
                    ],
                  )
                else
                  Text(
                    '',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8), // Action text matches book
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      checkmarkColor: theme.colorScheme.onPrimary,
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
