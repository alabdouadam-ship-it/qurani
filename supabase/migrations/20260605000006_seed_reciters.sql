-- ============================================================================
-- Migration 0006 — Seed reciters from the bundled assets/data/reciters.json
-- ============================================================================
-- Pre-populates public.reciters with the same catalogue that ships inside the
-- app, so the admin-web Reciters section is populated from day one and the
-- Flutter client's Supabase fetch returns the full list immediately.
--
-- Idempotent & non-destructive:
--   * ON CONFLICT (code) DO NOTHING — re-running this migration (or pushing it
--     to a DB that already has rows) never overwrites edits made later from the
--     dashboard. It only inserts codes that don't exist yet.
--   * sort_order mirrors the JSON array order so the admin list reads the same
--     as the bundled asset.
--   * is_enabled defaults to true (all bundled reciters are shipped enabled).
--
-- Source of truth: assets/data/reciters.json (kept in sync by hand — when you
-- add a reciter to the bundled JSON, add a matching row here or insert it from
-- the dashboard).
-- ============================================================================

insert into public.reciters
  (code, name_ar, name_latin, ayahs_path, surahs_path, sort_order, is_enabled)
values
  ('ayyoub',         'محمد أيوب',          'Mohamed Ayyoub',              'https://everyayah.com/data/Muhammad_Ayyoub_64kbps',        'https://server16.mp3quran.net/ayyoub2/Rewayat-Hafs-A-n-Assem', 1,  true),
  ('basit',          'عبدالباسط عبدالصمد', 'Abdulbasit Abdulsamad',        'https://www.qurani.info/data/ayahs/basit',                 'https://www.qurani.info/data/full/basit',                      2,  true),
  ('afs',            'العفاسي',            'Mishary Alafasy',              'https://www.qurani.info/data/ayahs/afs',                   'https://www.qurani.info/data/full/afs',                        3,  true),
  ('sds',            'عبدالرحمن السديس',   'Abdulrahman Al Sudais',        'https://www.qurani.info/data/ayahs/sds',                   'https://www.qurani.info/data/full/sds',                        4,  true),
  ('frs_a',          'فارس عباد',          'Fares Abbad',                  'https://www.qurani.info/data/ayahs/frs_a',                 'https://www.qurani.info/data/full/frs_a',                      5,  true),
  ('husr',           'الحصري',             'Mahmoud Al Husary',            'https://www.qurani.info/data/ayahs/husr',                  'https://www.qurani.info/data/full/husr',                       6,  true),
  ('minsh',          'المنشاوي',           'Mohamed Al Manshawi',          'https://www.qurani.info/data/ayahs/minsh',                 'https://www.qurani.info/data/full/minsh',                      7,  true),
  ('minsh_teacher',  'المنشاوي المعلم',    'Mohamed Al Manshawi Teacher',  'https://everyayah.com/data/Minshawy_Teacher_128kbps',      'https://www.qurani.info/data/full/minsh',                      8,  true),
  ('suwaid',         'أيمن سويد',          'Ayman Suwaid',                 'https://www.qurani.info/data/ayahs/suwaid',                'https://www.qurani.info/data/full/suwaid',                     9,  true),
  ('shuraym',        'سعود الشريم',        'Saood ash-Shuraym',            'https://everyayah.com/data/Saood_ash-Shuraym_64kbps',      'https://server7.mp3quran.net/shur',                            10, true),
  ('maher',          'ماهر المعيقلي',      'Maher AlMuaiqly',              'https://everyayah.com/data/Maher_AlMuaiqly_64kbps',        'https://server12.mp3quran.net/maher',                          11, true),
  ('ghamadi',        'سعد الغامدي',        'Saad Al-Ghamdi',               'https://everyayah.com/data/Ghamadi_40kbps',                'https://server7.mp3quran.net/s_gmd',                           12, true),
  ('muyassar',       'تفسير الميسر',       'Tafsir Al Muyassar',           'https://www.qurani.info/data/muyassar_audio',              null,                                                           13, true),
  ('arabic_english', 'إنجليزي - عربي',     'English - Arabic',             'https://www.qurani.info/data/ayahs/arabic-english',        null,                                                           14, true),
  ('arabic_french',  'فرنسي - عربي',       'French - Arabic',              'https://www.qurani.info/data/ayahs/arabic-french',         null,                                                           15, true),
  ('nufais',         'أحمد النفيس',        'Ahmed Nufais',                 '',                                                         'https://server16.mp3quran.net/nufais/Rewayat-Hafs-A-n-Assem',  16, true),
  ('dussary',        'ياسر الدوسري',       'Yasser Ad-Dussary',            'https://everyayah.com/data/Yasser_Ad-Dussary_128kbps',     'https://server11.mp3quran.net/yasser',                         17, true)
on conflict (code) do nothing;
