/// Single shared source of truth for Quran editions, used by BOTH the io
/// (SQLite) and web (JSON) repositories.
///
/// Previously `QuranEdition` was an enum duplicated in `quran_repository_io.dart`
/// and `quran_repository_web.dart`, with per-edition behavior scattered across
/// exhaustive `switch`es in ~6 files. Adding a tafsir/translation meant editing
/// the enum + every switch in both files. This registry replaces that: an
/// edition is a `const` value object, and the io/web repos read the field they
/// need (`dbColumn` vs `webJsonPath`). Adding a new edition is now: one DB
/// column (via tool/build_quran_db.dart) + one entry in [QuranEditions.values]
/// + one JSON under `web/data/editions/`. No switch edits.
library;

/// Top-level grouping for the edition picker's submenus.
enum EditionCategory { arabicScript, translation, tafsir }

/// How an edition's text is rendered in the reader.
enum EditionRendering { plain, tajweed, irab }

/// Immutable description of one Quran edition.
///
/// Instances are `const` and canonical (see [QuranEditions]), so identity
/// equality works exactly like the old enum (`a == QuranEditions.simple`), and
/// [QuranEditions.byId] returns the same canonical instance for a stored id.
class QuranEdition {
  const QuranEdition({
    required this.id,
    required this.category,
    this.dbColumn,
    this.webJsonPath,
    this.isRtl = true,
    this.rendering = EditionRendering.plain,
    this.languageCode,
    this.audioReciterKey,
    this.l10nKey,
    this.nativeName,
    this.englishName,
  });

  /// Stable identifier: used for persistence, the io page-cache key, and
  /// [byId] lookup. Mirrors the source JSON `edition.identifier` for the new
  /// editions; legacy values (`simple`, `english`, …) are kept verbatim so
  /// existing data and prefs round-trip unchanged.
  final String id;

  final EditionCategory category;

  /// io source: the `ayah` table column holding this edition's text.
  /// `irab` reuses `text_simple` (its grammar data comes from MASAQ.csv).
  final String? dbColumn;

  /// web source: path to this edition's JSON, **relative to the deployed web
  /// app root** (resolved against the document base by
  /// `web_edition_json.dart`). These files live in `web/data/editions/`, not in
  /// `assets/`, so they are served only by the web build and never bundled
  /// into the Android/iOS apps — io reads every edition from [dbColumn]
  /// instead. Null would mean "not available on web".
  final String? webJsonPath;

  final bool isRtl;
  final EditionRendering rendering;

  /// ISO language code for translations (`en`, `fr`, `tr`, `de`); null for
  /// Arabic scripts and tafsir.
  final String? languageCode;

  /// Reciter code whose recitation matches this edition's audio. `null` means
  /// "no associated audio" — callers fall back to the user's selected Arabic
  /// reciter so the user reads the translation/tafsir while hearing the Arabic
  /// ayah.
  final String? audioReciterKey;

  /// Localization key for the display label (fixed editions only). When null,
  /// the label comes from [nativeName]/[englishName].
  final String? l10nKey;

  /// Native-language display name (shown when app UI is Arabic). From the
  /// source JSON `edition.name`. Used for tafsir + non-en/fr translations.
  final String? nativeName;

  /// English display name (shown when app UI is en/fr). From the source JSON
  /// `edition.englishName`.
  final String? englishName;

  bool get isTranslation => category == EditionCategory.translation;
  bool get isTafsir => category == EditionCategory.tafsir;
  bool get isArabicScript => category == EditionCategory.arabicScript;
  bool get isIrab => rendering == EditionRendering.irab;
  bool get isTajweed => rendering == EditionRendering.tajweed;

  // ── Back-compat accessors ───────────────────────────────────────────────
  // These preserve the call sites that used the old enum's members, so the
  // registry can drop in without touching persistence keys or cache keys.

  /// Old enum used `edition.name` as the persisted key and the io/web page
  /// cache key. [id] serves the same role (legacy ids are unchanged).
  String get name => id;

  /// Old io repo used `edition.identifier` as its page-cache key.
  String get identifier => id;

  /// Non-null DB column for io queries. Every edition in the registry defines
  /// one (irab reuses `text_simple`); throwing here surfaces a registry
  /// mistake immediately rather than producing malformed SQL.
  String get column {
    final c = dbColumn;
    if (c == null) {
      throw StateError('Edition "$id" has no dbColumn');
    }
    return c;
  }

  /// Best-effort plain display name for non-localized call sites (dialog
  /// titles, debug payloads). Prefers the English name, then native, then id.
  String get displayName => englishName ?? nativeName ?? id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is QuranEdition && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'QuranEdition($id)';
}

/// The canonical edition registry.
class QuranEditions {
  const QuranEditions._();

  // ── Arabic scripts ────────────────────────────────────────────────────
  static const QuranEdition simple = QuranEdition(
    id: 'simple',
    category: EditionCategory.arabicScript,
    dbColumn: 'text_simple',
    webJsonPath: 'data/editions/quran-simple.json',
    isRtl: true,
    l10nKey: 'simple',
  );

  static const QuranEdition uthmani = QuranEdition(
    id: 'uthmani',
    category: EditionCategory.arabicScript,
    dbColumn: 'text_uthmani',
    webJsonPath: 'data/editions/quran-uthmani.json',
    isRtl: true,
    l10nKey: 'uthmani',
  );

  static const QuranEdition tajweed = QuranEdition(
    id: 'tajweed',
    category: EditionCategory.arabicScript,
    dbColumn: 'text_tajweed',
    webJsonPath: 'data/editions/quran-tajweed.json',
    isRtl: true,
    rendering: EditionRendering.tajweed,
    l10nKey: 'tajweed',
  );

  static const QuranEdition irab = QuranEdition(
    id: 'irab',
    category: EditionCategory.arabicScript,
    dbColumn: 'text_simple', // text from simple; grammar from MASAQ.csv
    webJsonPath: 'data/editions/quran-simple.json',
    isRtl: true,
    rendering: EditionRendering.irab,
    l10nKey: 'irab',
  );

  // ── Translations ──────────────────────────────────────────────────────
  static const QuranEdition english = QuranEdition(
    id: 'english',
    category: EditionCategory.translation,
    dbColumn: 'text_english',
    webJsonPath: 'data/editions/quran-english.json',
    isRtl: false,
    languageCode: 'en',
    audioReciterKey: 'arabic_english',
    l10nKey: 'english',
  );

  static const QuranEdition french = QuranEdition(
    id: 'french',
    category: EditionCategory.translation,
    dbColumn: 'text_french',
    webJsonPath: 'data/editions/quran-french.json',
    isRtl: false,
    languageCode: 'fr',
    audioReciterKey: 'arabic_french',
    l10nKey: 'french',
  );

  static const QuranEdition turkish = QuranEdition(
    id: 'tr.vakfi',
    category: EditionCategory.translation,
    dbColumn: 'text_tr_vakfi',
    webJsonPath: 'data/editions/tr.vakfi.json',
    isRtl: false,
    languageCode: 'tr',
    audioReciterKey: null, // no audio → user's Arabic reciter
    l10nKey: 'turkish',
    nativeName: 'Diyanet Vakfı',
    englishName: 'Diyanet Vakfi',
  );

  static const QuranEdition german = QuranEdition(
    id: 'de.bubenheim',
    category: EditionCategory.translation,
    dbColumn: 'text_de_bubenheim',
    webJsonPath: 'data/editions/de.bubenheim.json',
    isRtl: false,
    languageCode: 'de',
    audioReciterKey: null,
    l10nKey: 'german',
    nativeName: 'Bubenheim & Elyas',
    englishName: 'A. S. F. Bubenheim and N. Elyas',
  );

  // ── Tafsir books ──────────────────────────────────────────────────────
  static const QuranEdition tafsirMuyassar = QuranEdition(
    id: 'ar.muyassar',
    category: EditionCategory.tafsir,
    dbColumn: 'text_tafsir_muyassar',
    webJsonPath: 'data/editions/ar.muyassar.json',
    isRtl: true,
    audioReciterKey: 'muyassar',
    nativeName: 'تفسير الميسر',
    englishName: 'King Fahad Quran Complex',
  );

  static const QuranEdition tafsirJalalayn = QuranEdition(
    id: 'ar.jalalayn',
    category: EditionCategory.tafsir,
    dbColumn: 'text_tafsir_jalalayn',
    webJsonPath: 'data/editions/ar.jalalayn.json',
    isRtl: true,
    audioReciterKey: null,
    nativeName: 'تفسير الجلالين',
    englishName: 'Tafsir al-Jalalayn',
  );

  static const QuranEdition tafsirQurtubi = QuranEdition(
    id: 'ar.qurtubi',
    category: EditionCategory.tafsir,
    dbColumn: 'text_tafsir_qurtubi',
    webJsonPath: 'data/editions/ar.qurtubi.json',
    isRtl: true,
    audioReciterKey: null,
    nativeName: 'تفسير القرطبي',
    englishName: 'Tafseer Al-Qurtubi',
  );

  static const QuranEdition tafsirMiqbas = QuranEdition(
    id: 'ar.miqbas',
    category: EditionCategory.tafsir,
    dbColumn: 'text_tafsir_miqbas',
    webJsonPath: 'data/editions/ar.miqbas.json',
    isRtl: true,
    audioReciterKey: null,
    nativeName: 'تنوير المقباس من تفسير ابن عباس',
    englishName: 'Tafseer Tanwir al-Miqbas',
  );

  static const QuranEdition tafsirWaseet = QuranEdition(
    id: 'ar.waseet',
    category: EditionCategory.tafsir,
    dbColumn: 'text_tafsir_waseet',
    webJsonPath: 'data/editions/ar.waseet.json',
    isRtl: true,
    audioReciterKey: null,
    nativeName: 'التفسير الوسيط',
    englishName: 'Tafseer Al-Waseet',
  );

  static const QuranEdition tafsirBaghawi = QuranEdition(
    id: 'ar.baghawi',
    category: EditionCategory.tafsir,
    dbColumn: 'text_tafsir_baghawi',
    webJsonPath: 'data/editions/ar.baghawi.json',
    isRtl: true,
    audioReciterKey: null,
    nativeName: 'تفسير البغوي',
    englishName: 'Tafseer Al-Baghawi',
  );

  /// All editions, in picker order. Adding an edition = add it here (+ its DB
  /// column via the generator, + its server JSON for web).
  static const List<QuranEdition> values = [
    simple,
    uthmani,
    tajweed,
    irab,
    english,
    french,
    turkish,
    german,
    tafsirMuyassar,
    tafsirJalalayn,
    tafsirQurtubi,
    tafsirMiqbas,
    tafsirWaseet,
    tafsirBaghawi,
  ];

  static List<QuranEdition> get arabicScripts =>
      values.where((e) => e.category == EditionCategory.arabicScript).toList();

  static List<QuranEdition> get translations =>
      values.where((e) => e.category == EditionCategory.translation).toList();

  static List<QuranEdition> get tafsirs =>
      values.where((e) => e.category == EditionCategory.tafsir).toList();

  /// Resolves a stored id to its canonical instance. Applies [_aliases] so
  /// ids persisted before this refactor (e.g. the old `tafsir`) still resolve.
  /// Falls back to [simple] for unknown ids.
  static QuranEdition byId(String? id) {
    if (id == null || id.isEmpty) return simple;
    final resolved = _aliases[id] ?? id;
    for (final e in values) {
      if (e.id == resolved) return e;
    }
    return simple;
  }

  /// Legacy persisted-id aliases. The old flat enum had a single `tafsir`
  /// value backed by the `text_tafsir` column; it is now `ar.muyassar`.
  static const Map<String, String> _aliases = {
    'tafsir': 'ar.muyassar',
  };
}
