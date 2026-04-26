import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// 1. Model
enum NewsType { text, image, youtube }
class NewsItem {
  String id;
  String title;
  String description;
  NewsType type;
  String mediaUrl;
  String sourceUrl;
  DateTime publishDate;
  DateTime validUntil;
  String language;
  String? categoryAr;
  String? categoryEn;
  String? categoryFr;
  List<String> targetLanguages;
  bool isFeatured;
  bool sendNotification;

  NewsItem({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.mediaUrl,
    required this.sourceUrl,
    required this.publishDate,
    required this.validUntil,
    this.language = 'ar',
    this.categoryAr,
    this.categoryEn,
    this.categoryFr,
    this.targetLanguages = const [],
    this.isFeatured = false,
    this.sendNotification = false,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic dateStr) {
      if (dateStr == null) return DateTime.now();
      try {
        return DateTime.parse(dateStr as String);
      } catch (e) {
        return DateTime.now();
      }
    }
    return NewsItem(
      id: json['id'] as String? ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'No Title',
      description: json['description'] as String? ?? '',
      type: json['type']?.toString().toLowerCase() == 'image' ? NewsType.image :
            json['type']?.toString().toLowerCase() == 'youtube' ? NewsType.youtube : NewsType.text,
      mediaUrl: json['mediaUrl'] as String? ?? '',
      sourceUrl: json['sourceUrl'] as String? ?? '',
      publishDate: parseDate(json['publishDate']),
      validUntil: parseDate(json['validUntil']),
      language: json['language'] as String? ?? 'ar',
      categoryAr: json['category_ar'] as String?,
      categoryEn: json['category_en'] as String?,
      categoryFr: json['category_fr'] as String?,
      targetLanguages: (json['target_languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      isFeatured: json['is_featured'] == true || json['featured'] == true,
      sendNotification: json['push'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'sourceUrl': sourceUrl,
      'publishDate': publishDate.toIso8601String(),
      'validUntil': validUntil.toIso8601String(),
      'language': language,
      if (categoryAr?.isNotEmpty == true) 'category_ar': categoryAr,
      if (categoryEn?.isNotEmpty == true) 'category_en': categoryEn,
      if (categoryFr?.isNotEmpty == true) 'category_fr': categoryFr,
      if (targetLanguages.isNotEmpty) 'target_languages': targetLanguages,
      'featured': isFeatured,
      'push': sendNotification,
    };
  }
}

// 2. State Management
class NewsNotifier extends AsyncNotifier<List<NewsItem>> {
  @override
  Future<List<NewsItem>> build() async {
    return _fetchRemoteNews();
  }

  Future<List<NewsItem>> _fetchRemoteNews() async {
    try {
      final response = await http.get(Uri.parse('https://qurani.info/data/news-v1.json'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> newsList = data['news'] ?? [];
        return newsList.map((j) => NewsItem.fromJson(j)).toList();
      } else {
        debugPrint('Server returned ${response.statusCode}, starting with empty slate.');
        return [];
      }
    } catch (e) {
      debugPrint('Failed to fetch (File missing or CORS blocked): $e');
      return [];
    }
  }

  Future<void> fetchRemoteNews() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchRemoteNews());
  }

  void addItem(NewsItem item) {
    if (state.value != null) {
      state = AsyncData([...state.value!, item]);
    }
  }

  void updateItem(NewsItem item) {
    if (state.value != null) {
      final updated = state.value!.map((e) => e.id == item.id ? item : e).toList();
      state = AsyncData(updated);
    }
  }

  void deleteItem(String id) {
    if (state.value != null) {
      final updated = state.value!.where((e) => e.id != id).toList();
      state = AsyncData(updated);
    }
  }
}

final newsProvider = AsyncNotifierProvider<NewsNotifier, List<NewsItem>>(() {
  return NewsNotifier();
});

// 3. UI
void main() {
  runApp(const ProviderScope(child: NewsEditorApp()));
}

class NewsEditorApp extends StatelessWidget {
  const NewsEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qurani News CMS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.light),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(newsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Qurani News CMS'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(newsProvider.notifier).fetchRemoteNews(),
            tooltip: 'Reload Remote JSON',
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Export JSON to Clipboard'),
            onPressed: state.value == null ? null : () async {
              final payload = {
                "version": 1,
                "last_updated": DateTime.now().toIso8601String(),
                "news": state.value!.map((e) => e.toJson()).toList(),
              };
              final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);
              await Clipboard.setData(ClipboardData(text: jsonStr));
              if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON Copied to Clipboard!')));
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error downloading remote file: $err')),
        data: (items) {
          if (items.isEmpty) {
             return const Center(child: Text('No news items found. Add one!'));
          }
          return ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 100),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.article),
                  title: Text(item.title),
                  subtitle: Text('ID: ${item.id} | Valid Until: ${DateFormat('yyyy-MM-dd').format(item.validUntil)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.isFeatured) const Chip(label: Text('⭐ Featured')),
                      if (item.sendNotification) const Chip(label: Text('🔔 Push')),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openEditor(context, ref, item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, item),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add News'),
        onPressed: () {
          final newItem = NewsItem(
            id: 'news_${DateTime.now().millisecondsSinceEpoch}',
            title: '',
            description: '',
            type: NewsType.text,
            mediaUrl: '',
            sourceUrl: '',
            publishDate: DateTime.now(),
            validUntil: DateTime.now().add(const Duration(days: 30)),
          );
          _openEditor(context, ref, newItem, isNew: true);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NewsItem item) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete News'),
      content: Text('Are you sure you want to delete ${item.id}?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(onPressed: () {
          ref.read(newsProvider.notifier).deleteItem(item.id);
          Navigator.pop(ctx);
        }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ]
    ));
  }

  void _openEditor(BuildContext context, WidgetRef ref, NewsItem item, {bool isNew = false}) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EditorScreen(item: item, isNew: isNew)));
  }
}

class EditorScreen extends ConsumerStatefulWidget {
  final NewsItem item;
  final bool isNew;
  const EditorScreen({super.key, required this.item, required this.isNew});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late TextEditingController _idCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _catArCtrl;
  late TextEditingController _catEnCtrl;
  late TextEditingController _catFrCtrl;
  late Set<String> _targetLanguages;
  late TextEditingController _mediaUrlCtrl;
  late TextEditingController _sourceUrlCtrl;
  
  late bool _isFeatured;
  late bool _push;
  late DateTime _pubDate;
  late DateTime _valDate;
  late NewsType _type;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.item.id);
    _titleCtrl = TextEditingController(text: widget.item.title);
    _descCtrl = TextEditingController(text: widget.item.description);
    _catArCtrl = TextEditingController(text: widget.item.categoryAr ?? '');
    _catEnCtrl = TextEditingController(text: widget.item.categoryEn ?? '');
    _catFrCtrl = TextEditingController(text: widget.item.categoryFr ?? '');
    _targetLanguages = widget.item.targetLanguages.toSet();
    _mediaUrlCtrl = TextEditingController(text: widget.item.mediaUrl);
    _sourceUrlCtrl = TextEditingController(text: widget.item.sourceUrl);
    _isFeatured = widget.item.isFeatured;
    _push = widget.item.sendNotification;
    _pubDate = widget.item.publishDate;
    _valDate = widget.item.validUntil;
    _type = widget.item.type;
  }

  Widget _buildResponsiveRow(BuildContext context, List<Widget> children) {
    bool isWide = MediaQuery.of(context).size.width > 600;
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((e) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16.0), child: e))).toList(),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: e)).toList(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Create News Entity' : 'Edit News Entity'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Changes'),
            onPressed: _save,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                _buildResponsiveRow(context, [
                  TextField(controller: _idCtrl, decoration: const InputDecoration(labelText: 'Unique ID (e.g. ramadan_update_26)', border: OutlineInputBorder())),
                  DropdownButtonFormField<NewsType>(
                    decoration: const InputDecoration(labelText: 'Media Type', border: OutlineInputBorder()),
                    initialValue: _type,
                    items: NewsType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                    onChanged: (v) { 
                      if (v != null) {
                        setState(() { 
                          _type = v; 
                          if (_type == NewsType.text) _mediaUrlCtrl.clear();
                        }); 
                      } 
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'App Title', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                TextField(controller: _descCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Description Content', border: OutlineInputBorder())),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category Filters (Leave all blank for GLOBAL category)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildResponsiveRow(context, [
                         TextField(controller: _catArCtrl, decoration: const InputDecoration(labelText: 'Arabic Category', border: OutlineInputBorder())),
                         TextField(controller: _catEnCtrl, decoration: const InputDecoration(labelText: 'English Category', border: OutlineInputBorder())),
                         TextField(controller: _catFrCtrl, decoration: const InputDecoration(labelText: 'French Category', border: OutlineInputBorder())),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Target Languages (Leave empty to show to ALL users)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilterChip(
                            label: const Text('Arabic (ar)'),
                            selected: _targetLanguages.contains('ar'),
                            onSelected: (val) => setState(() { val ? _targetLanguages.add('ar') : _targetLanguages.remove('ar'); }),
                          ),
                          FilterChip(
                            label: const Text('English (en)'),
                            selected: _targetLanguages.contains('en'),
                            onSelected: (val) => setState(() { val ? _targetLanguages.add('en') : _targetLanguages.remove('en'); }),
                          ),
                          FilterChip(
                            label: const Text('French (fr)'),
                            selected: _targetLanguages.contains('fr'),
                            onSelected: (val) => setState(() { val ? _targetLanguages.add('fr') : _targetLanguages.remove('fr'); }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_type != NewsType.text) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _mediaUrlCtrl, 
                    decoration: InputDecoration(
                      labelText: _type == NewsType.image ? 'Image Network URL (.jpg, .png)' : 'YouTube Video URL or ID', 
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(_type == NewsType.image ? Icons.image : Icons.ondemand_video),
                    )
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _sourceUrlCtrl, 
                  decoration: const InputDecoration(
                    labelText: 'External Source Action URL (Read More button - Optional)', 
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.link),
                  )
                ),
                const SizedBox(height: 24),
                _buildResponsiveRow(context, [
                  CheckboxListTile(title: const Text('Is Featured (VIP UI)'), value: _isFeatured, onChanged: (v) => setState(() => _isFeatured = v ?? false)),
                  CheckboxListTile(title: const Text('Send Push Notification'), value: _push, onChanged: (v) => setState(() => _push = v ?? false)),
                ]),
                const SizedBox(height: 16),
                 _buildResponsiveRow(context, [
                  ListTile(
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    title: const Text('Publish Date (Visible Time)'), 
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_pubDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _pubDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(() => _pubDate = d);
                    },
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                    title: const Text('Valid Until (Automatic GC Deletion)'), 
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_valDate)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _valDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(()=> _valDate = d);
                    },
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final updated = NewsItem(
      id: _idCtrl.text.trim(),
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      type: _type,
      mediaUrl: _mediaUrlCtrl.text.trim(),
      sourceUrl: _sourceUrlCtrl.text.trim(),
      publishDate: _pubDate,
      validUntil: _valDate,
      categoryAr: _catArCtrl.text.trim().isEmpty ? null : _catArCtrl.text.trim(),
      categoryEn: _catEnCtrl.text.trim().isEmpty ? null : _catEnCtrl.text.trim(),
      categoryFr: _catFrCtrl.text.trim().isEmpty ? null : _catFrCtrl.text.trim(),
      targetLanguages: _targetLanguages.toList(),
      isFeatured: _isFeatured,
      sendNotification: _push,
    );

    if (widget.isNew) {
      ref.read(newsProvider.notifier).addItem(updated);
    } else {
      ref.read(newsProvider.notifier).updateItem(updated);
    }
    Navigator.pop(context);
  }
}
