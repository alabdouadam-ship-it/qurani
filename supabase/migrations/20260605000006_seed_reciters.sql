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
  ('basit',          'عبدالباسط عبدالصمد', 'Abdulbasit Abdulsamad',        'https://everyayah.com/data/Abdul_Basit_Mujawwad_128kbps',  'https://server7.mp3quran.net/basit',                           2,  true),
  ('afs',            'العفاسي',            'Mishary Alafasy',              'https://everyayah.com/data/Alafasy_128kbps',               'https://server8.mp3quran.net/afs',                             3,  true),
  ('sds',            'عبدالرحمن السديس',   'Abdulrahman Al Sudais',        'https://everyayah.com/data/Abdurrahmaan_As-Sudais_192kbps','https://server11.mp3quran.net/sds',                            4,  true),
  ('frs_a',          'فارس عباد',          'Fares Abbad',                  'https://everyayah.com/data/Fares_Abbad_64kbps',            'https://server8.mp3quran.net/frs_a',                           5,  true),
  ('husr',           'الحصري',             'Mahmoud Al Husary',            'https://everyayah.com/data/Husary_128kbps',                'https://server13.mp3quran.net/husr',                           6,  true),
  ('minsh',          'المنشاوي',           'Mohamed Al Manshawi',          'https://everyayah.com/data/Minshawy_Mujawwad_192kbps',     'https://server10.mp3quran.net/minsh',                          7,  true),
  ('minsh_teacher',  'المنشاوي المعلم',    'Mohamed Al Manshawi Teacher',  'https://everyayah.com/data/Minshawy_Teacher_128kbps',      'https://server10.mp3quran.net/minsh',                          8,  true),
  ('suwaid',         'أيمن سويد',          'Ayman Suwaid',                 'https://everyayah.com/data/Ayman_Sowaid_64kbps',           '',                                                             9,  true),
  ('shuraym',        'سعود الشريم',        'Saood ash-Shuraym',            'https://everyayah.com/data/Saood_ash-Shuraym_64kbps',      'https://server7.mp3quran.net/shur',                            10, true),
  ('maher',          'ماهر المعيقلي',      'Maher AlMuaiqly',              'https://everyayah.com/data/Maher_AlMuaiqly_64kbps',        'https://server12.mp3quran.net/maher',                          11, true),
  ('ghamadi',        'سعد الغامدي',        'Saad Al-Ghamdi',               'https://everyayah.com/data/Ghamadi_40kbps',                'https://server7.mp3quran.net/s_gmd',                           12, true),
  ('muyassar',       'تفسير الميسر',       'Tafsir Al Muyassar',           'https://everyayah.com/data/Alafasy_128kbps',               null,                                                           13, true),
  ('arabic_english', 'إنجليزي - عربي',     'English - Arabic',             'https://everyayah.com/data/Alafasy_128kbps',               null,                                                           14, true),
  ('arabic_french',  'فرنسي - عربي',       'French - Arabic',              'https://everyayah.com/data/Alafasy_128kbps',               null,                                                           15, true),
  ('nufais',         'أحمد النفيس',        'Ahmed Nufais',                 '',                                                         'https://server16.mp3quran.net/nufais/Rewayat-Hafs-A-n-Assem',  16, true),
  ('dussary',        'ياسر الدوسري',       'Yasser Ad-Dussary',            'https://everyayah.com/data/Yasser_Ad-Dussary_128kbps',     'https://server11.mp3quran.net/yasser',                         17, true)
on conflict (code) do nothing;
