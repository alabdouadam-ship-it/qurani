import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/preferences_service.dart';
import 'package:qurani/services/reciter_config_service.dart';

class SettingsSheetUtils {
  static Future<void> showReciterSelectionSheet(
    BuildContext context, {
    required Function(String) onReciterSelected,
    bool requireFullSurahs = false,
    bool requireVerseByVerse = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final currentReciter = PreferencesService.getReciter();
    final langCode = PreferencesService.getLanguage();
    
    // Load reciters based on requirements
    final List<ReciterConfig> allReciters;
    
    if (requireVerseByVerse) {
      // For Read Quran / Repetition Range: exclude translations and tafsir
      allReciters = await ReciterConfigService.getRecitersForVerseByVerse();
    } else if (requireFullSurahs) {
      // For Listen to Quran: only reciters with full surahs
      allReciters = await ReciterConfigService.getRecitersWithFullSurahs();
    } else {
      // Default: all reciters
      allReciters = await ReciterConfigService.getReciters();
    }
    
    // Map to UI format
    final reciters = allReciters.map((r) => {
      'id': r.code,
      'name': r.getDisplayName(langCode),
      'hasFullSurahs': r.hasFullSurahs(),
      'hasVerseByVerse': r.hasVerseByVerse(),
    }).toList();

    // Debug Print: Check exactly what is being passed to UI
    debugPrint('SettingsSheet: Passing ${reciters.length} reciters to UI');
    
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Important for custom borders
      builder: (context) {
        return _ReciterSelectionSheet(
          reciters: reciters,
          currentReciter: currentReciter,
          onReciterSelected: onReciterSelected,
          l10n: l10n,
          requireFullSurahs: requireFullSurahs,
          requireVerseByVerse: requireVerseByVerse,
        );
      },
    );
  }
}

class _ReciterSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> reciters;
  final String currentReciter;
  final Function(String) onReciterSelected;
  final AppLocalizations l10n;
  final bool requireFullSurahs;
  final bool requireVerseByVerse;

  const _ReciterSelectionSheet({
    required this.reciters,
    required this.currentReciter,
    required this.onReciterSelected,
    required this.l10n,
    this.requireFullSurahs = false,
    this.requireVerseByVerse = false,
  });

  @override
  State<_ReciterSelectionSheet> createState() => _ReciterSelectionSheetState();
}

class _ReciterSelectionSheetState extends State<_ReciterSelectionSheet> {
  String _searchQuery = '';
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final filteredReciters = _searchQuery.isEmpty
        ? widget.reciters
        : widget.reciters.where((r) {
            final name = (r['name'] ?? '').toString().toLowerCase();
            final id = (r['id'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || id.contains(query);
          }).toList();

    // Height calculation
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;
    // Bottom padding for iPhone Home Indicator
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 20;

    return Container(
      height: sheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // Use theme color
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.l10n.chooseReciter,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: widget.l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // List
          Expanded(
            child: filteredReciters.isEmpty
                ? Center(child: Text(widget.l10n.noResultsFound))
                : ListView.builder(
                    // [IMPORTANT] Add padding at the bottom so last item isn't hidden
                    padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPadding), 
                    itemCount: filteredReciters.length,
                    itemBuilder: (context, index) {
                      final reciter = filteredReciters[index];
                      final isSelected = reciter['id'] == widget.currentReciter;
                      return ListTile(
                        title: Text(reciter['name'] ?? ''),
                        // Visual check to verify ID matches
                        subtitle:  null, // Set to Text(reciter['id']) for debugging
                        leading: isSelected
                            ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                            : const SizedBox(width: 24),
                        onTap: () {
                          widget.onReciterSelected(reciter['id'] ?? '');
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          
          // Refresh Button (kept distinct from list)
          Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))
              ]
            ),
            child: Center(
              child: TextButton.icon(
                onPressed: _isRefreshing ? null : _handleRefresh,
                icon: _isRefreshing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: Text('تحديث القائمة', style: TextStyle(color: _isRefreshing ? Colors.grey : null)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    // Force clean reload
    await ReciterConfigService.clearAndReload(); // Ensure this method exists or use forceRefresh
    await ReciterConfigService.forceRefresh();
    
    // Reload logic...
    final allReciters = await ReciterConfigService.getRecitersWithFullSurahs();
    final langCode = PreferencesService.getLanguage();
    
    // Debug output
    debugPrint('Refresh: Loaded ${allReciters.length} reciters');

    final newReciters = allReciters.where((r) {
      if (widget.requireFullSurahs && !r.hasFullSurahs()) return false;
      if (widget.requireVerseByVerse && !r.hasVerseByVerse()) return false;
      return true;
    }).map((r) => {
      'id': r.code,
      'name': r.getDisplayName(langCode),
      'hasFullSurahs': r.hasFullSurahs(),
      'hasVerseByVerse': r.hasVerseByVerse(),
    }).toList();
    
    if (mounted) {
      setState(() {
        widget.reciters.clear();
        widget.reciters.addAll(newReciters);
        _isRefreshing = false;
      });
    }
  }
}