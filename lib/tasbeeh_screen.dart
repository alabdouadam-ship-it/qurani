import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/models/tasbeeh_model.dart';
import 'package:qurani/services/tasbeeh_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'responsive_config.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  List<TasbeehGroup> _groups = [];
  bool _isLoading = true;
  final Map<String, int> _sessionCounts = {}; // Key: "${groupId}_${itemId}"

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // TEMP: Force reload for dev
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('dev_force_reload_v3') != true) {
      await prefs.remove('tasbeeh_data_v2'); 
      await prefs.setBool('dev_force_reload_v3', true);
    }

    final groups = await TasbeehService.getGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoading = false;
      });
    }
  }

  String _getLocalizedGroupName(TasbeehGroup group, AppLocalizations l10n) {
    if (group.isCustom) return group.name;

    switch (group.name) {
      case 'groupMyAzkar':
        return l10n.groupMyAzkar;
      case 'groupMorning':
        return l10n.groupMorning;
      case 'groupEvening':
        return l10n.groupEvening;
      case 'groupPostPrayerGeneral':
        return l10n.groupPostPrayerGeneral;
      case 'groupPostPrayerFajrMaghrib':
        return l10n.groupPostPrayerFajrMaghrib;
      case 'groupFriday':
        return l10n.groupFriday;
      case 'groupSleep':
        return l10n.groupSleep;
      case 'groupWaking':
        return l10n.groupWaking;
      default:
        return group.name;
    }
  }

  Future<void> _showAddGroupDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.createNewGroup),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.enterGroupName,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l10n.addGroup),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await TasbeehService.addGroup(controller.text.trim());
      await _loadData();
    }
  }

  Future<void> _deleteGroup(TasbeehGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGroup),
        content: Text(l10n.deleteGroupConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
             style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteGroup),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TasbeehService.removeGroup(group.id);
      await _loadData();
    }
  }

    Future<void> _resetGroup(TasbeehGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetGroup),
        content: Text(l10n.resetGroupConfirmation), 
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.resetGroup),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TasbeehService.resetGroupCounts(group.id);
      setState(() {
          for(var item in group.items) {
               _sessionCounts['${group.id}_${item.id}'] = 0;
          }
      });
      await _loadData();
    }
  }

  Future<void> _addItem(TasbeehGroup group) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addAzkar),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: l10n.enterAzkar,
            border: const OutlineInputBorder(),
          ),
           maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: Text(l10n.addAzkar),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await TasbeehService.addItem(group.id, controller.text.trim());
      await _loadData();
    }
  }

  Future<void> _deleteItem(TasbeehGroup group, TasbeehItem item) async {
    // Only confirm? Or just swipe to delete? Swipe is better but button is safer.
     // Let's us confirm dialog for safety.
     final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            title: Text(l10n.delete), // Generic delete
            content: Text('هل تريد حذف هذا الذكر؟\n${item.text}'),
            actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)), 
            ]
        )
    );

     if (confirmed == true) {
        await TasbeehService.removeItem(group.id, item.id);
        await _loadData();
     }
  }
  
  Future<void> _incrementCount(TasbeehGroup group, TasbeehItem item) async {
      // Optimistic update
      final sessionKey = '${group.id}_${item.id}';
      setState(() {
          _sessionCounts[sessionKey] = (_sessionCounts[sessionKey] ?? 0) + 1;
          item.count++; 
      });
      
      await TasbeehService.incrementCount(group.id, item.id);
      // We don't reload full data here to avoid UI flicker/jumps, we trust our local modification matches DB
  }

    Future<void> _resetSession(TasbeehGroup group, TasbeehItem item) async {
        final sessionKey = '${group.id}_${item.id}';
        setState(() {
             _sessionCounts[sessionKey] = 0;
        });
    }

    Future<void> _resetAll() async {
        final l10n = AppLocalizations.of(context)!;
        final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.resetAll),
        content: const Text("سيتم تصفير جميع العدادات لجميع المجموعات."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
             style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.resetAll),
          ),
        ],
      ),
    );
     if (confirmed == true) {
         await TasbeehService.resetAllCounts();
         setState(() {
             _sessionCounts.clear();
         });
         await _loadData();
     }

    }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.tasbeeh,
           style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: l10n.resetAll,
                onPressed: _resetAll,
            ),
             IconButton(
                icon: const Icon(Icons.add),
                tooltip: l10n.createNewGroup,
                onPressed: _showAddGroupDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _groups.length,
              itemBuilder: (context, index) {
                final group = _groups[index];
                return _buildGroupTile(group, l10n, theme);
              },
            ),
    );
  }

  Widget _buildGroupTile(TasbeehGroup group, AppLocalizations l10n, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: Key(group.id),
          initiallyExpanded: group.name == 'groupMyAzkar', // Default expanded
          title: Text(
            _getLocalizedGroupName(group, l10n),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          leading: Icon(
              group.isCustom ? Icons.folder_shared_outlined : Icons.folder_special_outlined,
              color: theme.colorScheme.primary,
          ),
          trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                  if (value == 'add') _addItem(group);
                  if (value == 'reset') _resetGroup(group);
                  if (value == 'delete') _deleteGroup(group);
              },
              itemBuilder: (context) => [
                   PopupMenuItem(
                      value: 'add',
                      child: Row(
                          children: [
                              Icon(Icons.add, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(l10n.addAzkar),
                          ],
                      ),
                  ),
                   PopupMenuItem(
                      value: 'reset',
                      child: Row(
                          children: [
                              const Icon(Icons.refresh, color: Colors.orange),
                              const SizedBox(width: 8),
                              Text(l10n.resetGroup),
                          ],
                      ),
                  ),
                  if (group.isCustom)
                      PopupMenuItem(
                          value: 'delete',
                          child: Row(
                              children: [
                                  const Icon(Icons.delete, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(l10n.deleteGroup),
                              ],
                          ),
                      ),
              ],
          ),
          children: [
              if (group.items.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          "لا توجد أذكار في هذه المجموعة. اضغط على القائمة لإضافة ذكر.",
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                      ),
                  ),
            ...group.items.map((item) => _buildAzkarItem(group, item, theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildAzkarItem(TasbeehGroup group, TasbeehItem item, ThemeData theme) {
      final sessionCount = _sessionCounts['${group.id}_${item.id}'] ?? 0;
      
      return Container(
          decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: theme.dividerColor.withAlpha(25)),
              ),
              color: theme.colorScheme.surface.withAlpha(128),
          ),
          child: InkWell(
              onTap: () => _incrementCount(group, item),
              child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                      children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Text(
                                          item.text,
                                           style: const TextStyle(fontSize: 16, height: 1.5),
                                           textDirection: TextDirection.rtl,
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                          children: [
                                              _buildBadge(theme, "الجلسة: $sessionCount", theme.colorScheme.primaryContainer, theme.colorScheme.onPrimaryContainer),
                                              const SizedBox(width: 8),
                                              _buildBadge(theme, "الكل: ${item.count}", theme.colorScheme.secondaryContainer, theme.colorScheme.onSecondaryContainer),
                                          ],
                                      )
                                  ],
                              ),
                          ),
                          Column(
                              children: [
                                  IconButton(
                                      icon: const Icon(Icons.refresh, size: 20),
                                      onPressed: () => _resetSession(group, item),
                                      tooltip: "تصفير الجلسة",
                                  ),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                      onPressed: () => _deleteItem(group, item),
                                      tooltip: "حذف",
                                  ),
                              ],
                          )
                      ],
                  ),
              ),
          ),
      );
  }
  
  Widget _buildBadge(ThemeData theme, String text, Color bg, Color fg) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
              text,
              style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.bold),
          ),
      );
  }
}