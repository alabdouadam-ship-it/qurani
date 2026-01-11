import 'dart:ui';

class HadithGradeTranslationService {
  static final Map<String, Map<String, String>> _gradeDictionary = {
    // English -> { 'ar': Arabic, 'fr': French }
    'sahih': {'ar': 'صحيح', 'fr': 'Authentique'},
    'hasan': {'ar': 'حسن', 'fr': 'Bon'},
    'daif': {'ar': 'ضعيف', 'fr': 'Faible'},
    'da\'if': {'ar': 'ضعيف', 'fr': 'Faible'},
    'daif isnaad': {'ar': 'إسناده ضعيف', 'fr': 'Chaîne Faible'},
    'da\'if isnaad': {'ar': 'إسناده ضعيف', 'fr': 'Chaîne Faible'},
    'hasan sahih': {'ar': 'حسن صحيح', 'fr': 'Bon Authentique'},
    'sahih lighairihi': {'ar': 'صحيح لغيره', 'fr': 'Authentique par d\'autres'},
    'hasan lighairihi': {'ar': 'حسن لغيره', 'fr': 'Bon par d\'autres'},
    'shadh': {'ar': 'شاذ', 'fr': 'Anomalie'},
    'munkar': {'ar': 'منكر', 'fr': 'Rejeté'},
    'maudu': {'ar': 'موضوع', 'fr': 'Fabriqué'},
    'isnaad sahih': {'ar': 'إسناده صحيح', 'fr': 'Chaîne Authentique'},
    'isnaad hasan': {'ar': 'إسناده حسن', 'fr': 'Chaîne Bonne'},
    'sahih - agreed upon': {'ar': 'صحيح - متفق عليه', 'fr': 'Authentique - Unanimement reconnu'},
    'agreed upon': {'ar': 'متفق عليه', 'fr': 'Unanimement reconnu'},
    'sahih - bukhari and muslim': {'ar': 'صحيح - البخاري ومسلم', 'fr': 'Authentique - Bukhari et Muslim'}, 
    'sahih muslim': {'ar': 'صحيح مسلم', 'fr': 'Authentique (Muslim)'},
    'sahih bukhari': {'ar': 'صحيح البخاري', 'fr': 'Authentique (Bukhari)'}, 
    'mauquf daif': {'ar': 'موقوف ضعيف', 'fr': 'Mauquf Faible'},
    'mauquf sahih': {'ar': 'موقوف صحيح', 'fr': 'Mauquf Authentique'},
  };

  static final Map<String, Map<String, String>> _scholarDictionary = {
    'salim al-hilali': {'ar': 'سليم الهلالي', 'fr': 'Salim al-Hilali'},
    'al-albani': {'ar': 'الألباني', 'fr': 'Al-Albani'},
    'albani': {'ar': 'الألباني', 'fr': 'Al-Albani'},
    'zubair ali zai': {'ar': 'زبير علي زئي', 'fr': 'Zubair Ali Zai'},
    'ahmad muhammad shakir': {'ar': 'أحمد محمد شاكر', 'fr': 'Ahmad Muhammad Shakir'},
    'shuaib al arnaut': {'ar': 'شعيب الأرنؤوط', 'fr': 'Shuaib Al Arnaut'},
    'bashar awad maarouf': {'ar': 'بشار عواد معروف', 'fr': 'Bashar Awad Maarouf'},
    'muhammad muhyi al-din abdul hamid': {'ar': 'محمد محيي الدين عبد الحميد', 'fr': 'Muhammad Muhyi Al-Din Abdul Hamid'},
    'darussalam': {'ar': 'دار السلام', 'fr': 'Darussalam'},
    'abu ghuddah': {'ar': 'أبو غدة', 'fr': 'Abu Ghuddah'},
    'muhammad fouad abd al-baqi': {'ar': 'محمد فؤاد عبد الباقي', 'fr': 'Muhammad Fouad Abd al-Baqi'},
  };

  static String translateGrade(String grade, Locale locale) {
    if (locale.languageCode == 'en') return grade;
    
    // Normalize string: lowercase and trim
    final normalized = grade.toLowerCase().trim();
    
    // Direct lookup
    if (_gradeDictionary.containsKey(normalized)) {
      return _gradeDictionary[normalized]![locale.languageCode] ?? grade;
    }

    // Attempt partial matching if direct lookup fails (simplistic)
    // E.g., "Sahih (Al-Albani)" -> handled in UI usually, but sometimes grade is composite
    // For now, return original if not found to avoid incorrect translation
    return grade;
  }

  static String translateScholar(String scholarName, Locale locale) {
    if (locale.languageCode == 'en') return scholarName;

    final normalized = scholarName.toLowerCase().trim();
    
    if (_scholarDictionary.containsKey(normalized)) {
      return _scholarDictionary[normalized]![locale.languageCode] ?? scholarName;
    }
    
    return scholarName;
  }
}
