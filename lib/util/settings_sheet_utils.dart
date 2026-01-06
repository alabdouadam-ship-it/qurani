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
    
    // Load reciters dynamically from JSON
    final allReciters = await ReciterConfigService.getRecitersWithFullSurahs();
    
    // Filter based on requirements
    final reciters = allReciters.where((r) {
      if (requireFullSurahs && !r.hasFullSurahs()) return false;
      if (requireVerseByVerse && !r.hasVerseByVerse()) return false;
      return true;
    }).map((r) => {
      'id': r.code,
      'name': r.getDisplayName(langCode),
      'hasFullSurahs': r.hasFullSurahs(),
      'hasVerseByVerse': r.hasVerseByVerse(),
    }).toList();

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Required for custom height to work
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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

// Separate StatefulWidget for the reciter selection sheet
// [FIXED] Replaced DraggableScrollableSheet with Container+Column to fix iOS clipping issue
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
    // Filter reciters based on search query
    final filteredReciters = _searchQuery.isEmpty
        ? widget.reciters
        : widget.reciters.where((r) {
            final name = (r['name'] ?? '').toString().toLowerCase();
            final id = (r['id'] ?? '').toString().toLowerCase();
            final query = _searchQuery.toLowerCase();
            return name.contains(query) || id.contains(query);
          }).toList();

    // Calculate fixed height: 85% of screen height
    // This bypasses the DraggableScrollableSheet layout bugs on iOS
    final double sheetHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Colors.white, // Or Theme.of(context).scaffoldBackgroundColor
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
           // Drag Handle (Visual indicator)
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              widget.l10n.chooseReciter,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Search TextField
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: widget.l10n.search,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filteredReciters.isEmpty
                ? Center(
                    child: Text(
                      widget.l10n.noResultsFound,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                : ListView.builder(
                    // ListView now manages its own scrolling independently
                    padding: EdgeInsets.zero,
                    itemCount: filteredReciters.length,
                    itemBuilder: (context, index) {
                      final reciter = filteredReciters[index];
                      final isSelected = reciter['id'] == widget.currentReciter;
                      return ListTile(
                        title: Text(reciter['name'] ?? ''),
                        leading: isSelected
                            ? Icon(Icons.check,
                                color: Theme.of(context).colorScheme.primary)
                            : const SizedBox(width: 24),
                        onTap: () {
                          widget.onReciterSelected(reciter['id'] ?? '');
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          // Refresh button - always visible at bottom
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 24.0),
            child: Center(
              child: TextButton.icon(
                onPressed: _isRefreshing ? null : _handleRefresh,
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 18),
                label: Text(
                  'تحديث القائمة',
                  style: TextStyle(fontSize: 12, color: _isRefreshing ? Colors.grey : null),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await ReciterConfigService.forceRefresh();
    final allReciters = await ReciterConfigService.getRecitersWithFullSurahs();
    final langCode = PreferencesService.getLanguage();
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