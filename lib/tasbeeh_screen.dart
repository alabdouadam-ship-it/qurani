import 'package:flutter/material.dart';
import 'package:qurani/l10n/app_localizations.dart';
import 'package:qurani/services/tasbeeh_service.dart';
import 'responsive_config.dart';

class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  List<String> _phrases = [];
  Map<int, int> _sessionCounts = {};
  Map<int, int> _totalCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final phrases = await TasbeehService.getPhrases();
    final totalCounts = await TasbeehService.getTotalCounts();
    if (mounted) {
      setState(() {
        _phrases = phrases;
        _totalCounts = totalCounts;
        _isLoading = false;
      });
    }
  }

  Future<void> _incrementCount(int index) async {
    setState(() {
      _sessionCounts[index] = (_sessionCounts[index] ?? 0) + 1;
    });
    await TasbeehService.incrementCount(index);
    final updatedCounts = await TasbeehService.getTotalCounts();
    if (mounted) {
      setState(() {
        _totalCounts = updatedCounts;
      });
    }
  }

  void _resetSessionCount(int index) {
    setState(() {
      _sessionCounts[index] = 0;
    });
  }

  Future<void> _resetAllCounts() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفير جميع العدادات'),
        content: const Text(
          'سيتم تصفير جميع العدادات (الجلسة الحالية والإجمالي) لجميع الأذكار.\n\n'
          'هل أنت متأكد أنك تريد المتابعة؟'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('تصفير الكل'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TasbeehService.resetAllCounts();
      if (mounted) {
        setState(() {
          _sessionCounts.clear();
          _totalCounts.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصفير جميع العدادات بنجاح'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _addPhrase() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة ذكر'),
        content: TextField(
          controller: controller,
          textDirection: TextDirection.rtl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'أدخل الذكر',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await TasbeehService.addPhrase(controller.text.trim());
      await _loadData();
    }
  }

  Future<void> _deletePhrase(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ذكر'),
        content: Text('هل أنت متأكد أنك تريد حذف هذا الذكر؟\n\n${_phrases[index]}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await TasbeehService.removePhrase(index);
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSmallScreen = ResponsiveConfig.isSmallScreen(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l10n.tasbeeh,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: ResponsiveConfig.getFontSize(context, 18),
          ),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'إضافة ذكر',
            onPressed: _addPhrase,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تصفير الكل',
            onPressed: _resetAllCounts,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _phrases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.list_alt,
                        size: 64,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد أذكار',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على زر الإضافة لإضافة ذكر',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          left: isSmallScreen ? 12 : 16,
                          right: isSmallScreen ? 12 : 16,
                          top: isSmallScreen ? 12 : 16,
                          bottom: 80,
                        ),
                        itemCount: _phrases.length,
                  itemBuilder: (context, index) {
                    final phrase = _phrases[index];
                    final sessionCount = _sessionCounts[index] ?? 0;
                    final totalCount = _totalCounts[index] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: () => _incrementCount(index),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      phrase,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    iconSize: 20,
                                    tooltip: 'حذف',
                                    onPressed: () => _deletePhrase(index),
                                    color: Colors.red,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh),
                                    iconSize: 20,
                                    tooltip: 'تصفير الجلسة',
                                    onPressed: () => _resetSessionCount(index),
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        'الجلسة الحالية',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$sessionCount',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: colorScheme.outlineVariant,
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        'الإجمالي',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$totalCount',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                      ),
                    ),
                  ],
                ),
    );
  }
}