import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qurani/models/tasbeeh_model.dart';

class TasbeehService {
  static const String _keyPhrases = 'tasbeeh_phrases';
  static const String _keyTotalCounts = 'tasbeeh_total_counts';
  static const String _keyTasbeehData = 'tasbeeh_data_v2';

  // Fallback default phrases (legacy support)
  static const List<String> legacyDefaultPhrases = [
    'سبحان الله',
    'الحمد لله',
    'لا إله إلا الله',
    'الله أكبر',
    'أستغفر الله',
  ];

  static Future<List<TasbeehGroup>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_keyTasbeehData);

    if (dataString != null && dataString.isNotEmpty) {
      try {
        final List<dynamic> jsonList = jsonDecode(dataString);
        return jsonList.map((e) => TasbeehGroup.fromJson(e)).toList();
      } catch (e) {
        // Fallback or error handling
      }
    }

    // Migration or Initialization
    return await _initializeOrMigrate(prefs);
  }

  static Future<List<TasbeehGroup>> _initializeOrMigrate(SharedPreferences prefs) async {
    // Check for legacy data
    final legacyPhrases = prefs.getStringList(_keyPhrases);
    
    if (legacyPhrases != null && legacyPhrases.isNotEmpty) {
      // MIGRATE
      final legacyCounts = await _getLegacyCounts(prefs);
      
      final myAzkarGroup = TasbeehGroup.create('groupMyAzkar', isCustom: false);
      for (int i = 0; i < legacyPhrases.length; i++) {
        final item = TasbeehItem.create(legacyPhrases[i]);
        item.count = legacyCounts[i] ?? 0;
        myAzkarGroup.items.add(item);
      }
      
      final groups = [myAzkarGroup, ..._createDefaultGroups()];
      await saveGroups(groups);
      
      // Cleanup legacy
      await prefs.remove(_keyPhrases);
      await prefs.remove(_keyTotalCounts);
      
      return groups;
    } else {
      // INITIALIZE NEW
      final myAzkar = TasbeehGroup.create('groupMyAzkar', isCustom: false);
      // Add standard "My Azkar" items if empty
      for(var text in legacyDefaultPhrases) {
         myAzkar.items.add(TasbeehItem.create(text));
      }

      final groups = [myAzkar, ..._createDefaultGroups()];
      await saveGroups(groups);
      return groups;
    }
  }

  static List<TasbeehGroup> _createDefaultGroups() {
    // 1. General Post-Prayer (Dhuhr, Asr, Isha)
    final postPrayerGeneralItems = [
      'أستغفر الله (3 مرات)',
      'اللهم أنت السلام ومنك السلام، تباركت يا ذا الجلال والإكرام',
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير، اللهم لا مانع لما أعطيت، ولا معطي لما منعت، ولا ينفع ذا الجد منك الجد',
      'سبحان الله (33 مرة)',
      'الحمد لله (33 مرة)',
      'الله أكبر (33 مرة)',
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد وهو على كل شيء قدير (تمام المائة)',
      'آية الكرسي',
      'سورة الإخلاص، الفلق، الناس',
    ];

    // 2. Fajr & Maghrib Post-Prayer (General + Extras)
    final postPrayerFajrMaghribItems = [
      ...postPrayerGeneralItems, // Includes the general ones first
      'لا إله إلا الله وحده لا شريك له، له الملك وله الحمد، يحيي ويميت، وهو على كل شيء قدير (10 مرات)',
      'تكرار المعوذات (الإخلاص، الفلق، الناس) (3 مرات)',
      'اللهم إني أسألك علماً نافعاً، ورزقاً طيباً، وعملاً متقبلاً (بعد الفجر)',
    ];

    return [
      _createGroup('groupPostPrayerGeneral', postPrayerGeneralItems),
      _createGroup('groupPostPrayerFajrMaghrib', postPrayerFajrMaghribItems),
      _createGroup('groupMorning', [
        'آية الكرسي',
        'المعوذات (الإخلاص، الفلق، الناس) (3 مرات)',
        'اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك، وأنا على عهدك ووعدك ما استطعت، أعوذ بك من شر ما صنعت، أبوء لك بنعمتك علي، وأبوء بذنبي فاغفر لي فإنه لا يغفر الذنوب إلا أنت',
        'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم (3 مرات)',
        'رضيت بالله رباً، وبالإسلام ديناً، وبمحمد ﷺ نبياً (3 مرات)',
        'حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم (7 مرات)',
        'سبحان الله وبحمده (100 مرة)',
        'اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري، لا إله إلا أنت (3 مرات)',
      ]),
      _createGroup('groupEvening', [
        'آية الكرسي',
        'المعوذات (الإخلاص، الفلق، الناس) (3 مرات)',
        'اللهم أنت ربي لا إله إلا أنت، خلقتني وأنا عبدك، وأنا على عهدك ووعدك ما استطعت، أعوذ بك من شر ما صنعت، أبوء لك بنعمتك علي، وأبوء بذنبي فاغفر لي فإنه لا يغفر الذنوب إلا أنت',
        'بسم الله الذي لا يضر مع اسمه شيء في الأرض ولا في السماء وهو السميع العليم (3 مرات)',
        'رضيت بالله رباً، وبالإسلام ديناً، وبمحمد ﷺ نبياً (3 مرات)',
        'حسبي الله لا إله إلا هو عليه توكلت وهو رب العرش العظيم (7 مرات)',
        'سبحان الله وبحمده (100 مرة)',
        'اللهم عافني في بدني، اللهم عافني في سمعي، اللهم عافني في بصري، لا إله إلا أنت (3 مرات)',
      ]),
      _createGroup('groupSleep', [
         'الإخلاص، الفلق، الناس (3 مرات)',
         'آية الكرسي',
         'آخر آيتين من سورة البقرة',
         'باسمك ربي وضعت جنبي وبك أرفعه، إن أمسكت نفسي فارحمها، وإن أرسلتها فاحفظها بما تحفظ به عبادك الصالحين',
         'سبحان الله (33)، الحمد لله (33)، الله أكبر (34)',
         'باسمك اللهم أموت وأحيا',
      ]),
      _createGroup('groupFriday', [
        'الإكثار من الصلاة على النبي ﷺ: اللهم صلِّ وسلم على نبينا محمد',
        'قراءة سورة الكهف',
        'تحري ساعة الاستجابة (آخر ساعة بعد العصر)',
      ]),
    ];
  }

  static TasbeehGroup _createGroup(String key, List<String> itemsText) {
    final group = TasbeehGroup.create(key, isCustom: false);
    for (var text in itemsText) {
      group.items.add(TasbeehItem.create(text));
    }
    return group;
  }

  static Future<Map<int, int>> _getLegacyCounts(SharedPreferences prefs) async {
    final countsJson = prefs.getString(_keyTotalCounts);
    if (countsJson == null || countsJson.isEmpty) return {};
    try {
      final Map<int, int> result = {};
      final pairs = countsJson.split(',');
      for (final pair in pairs) {
        final parts = pair.split(':');
        if (parts.length == 2) {
          final key = int.tryParse(parts[0]);
          final value = int.tryParse(parts[1]);
          if (key != null && value != null) {
            result[key] = value;
          }
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveGroups(List<TasbeehGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(groups.map((e) => e.toJson()).toList());
    await prefs.setString(_keyTasbeehData, jsonString);
  }

  static Future<void> addGroup(String name) async {
    final groups = await getGroups();
    groups.add(TasbeehGroup.create(name, isCustom: true));
    await saveGroups(groups);
  }

  static Future<void> removeGroup(String groupId) async {
    final groups = await getGroups();
    groups.removeWhere((g) => g.id == groupId);
    await saveGroups(groups);
  }

  static Future<void> addItem(String groupId, String text) async {
    final groups = await getGroups();
    final groupIndex = groups.indexWhere((g) => g.id == groupId);
    if (groupIndex != -1) {
      groups[groupIndex].items.add(TasbeehItem.create(text));
      await saveGroups(groups);
    }
  }

  static Future<void> removeItem(String groupId, String itemId) async {
    final groups = await getGroups();
    final groupIndex = groups.indexWhere((g) => g.id == groupId);
    if (groupIndex != -1) {
      groups[groupIndex].items.removeWhere((item) => item.id == itemId);
      await saveGroups(groups);
    }
  }

  static Future<void> incrementCount(String groupId, String itemId) async {
    final groups = await getGroups();
    final groupIndex = groups.indexWhere((g) => g.id == groupId);
    if (groupIndex != -1) {
      final itemIndex = groups[groupIndex].items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        groups[groupIndex].items[itemIndex].count++;
        await saveGroups(groups);
      }
    }
  }
  
  static Future<void> resetAllCounts() async {
      final groups = await getGroups();
      for (var group in groups) {
          for (var item in group.items) {
              item.count = 0;
          }
      }
      await saveGroups(groups);
  }
  
    static Future<void> resetGroupCounts(String groupId) async {
      final groups = await getGroups();
       final groupIndex = groups.indexWhere((g) => g.id == groupId);
      if (groupIndex != -1) {
          for (var item in groups[groupIndex].items) {
              item.count = 0;
          }
          await saveGroups(groups);
      }
  }
}
