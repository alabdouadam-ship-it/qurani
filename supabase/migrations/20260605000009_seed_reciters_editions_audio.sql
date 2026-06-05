-- ============================================================================
-- Migration 0009 — Add edition-audio reciter rows (Turkish, German, tafsirs)
-- ============================================================================
-- Mirrors the bundled assets/data/reciters.json after adding placeholder audio
-- entries for the editions that previously had no recitation:
--   * turkish  (Diyanet Vakfı translation)
--   * german   (Bubenheim & Elyas translation)
--   * jalalayn, qurtubi, miqbas, waseet, baghawi (tafsir books)
--
-- `muyassar` already exists (seeded in 0006) so it is NOT re-added here.
--
-- Audio paths are intentionally EMPTY for now (ayahs_path='', surahs_path=null)
-- — the URLs will be filled in later from the dashboard. Empty paths mean these
-- reciters won't appear in any picker (the client filters by non-empty paths),
-- so this is safe to ship before the audio exists.
--
-- Idempotent & non-destructive: ON CONFLICT (code) DO NOTHING.
-- sort_order continues from dussary (17) in 0006.
-- ============================================================================

insert into public.reciters
  (code, name_ar, name_latin, ayahs_path, surahs_path, sort_order, is_enabled)
values
  ('turkish',   'تركي - الديانة',                 'Turkish (Diyanet Vakfı)',      '', null, 18, true),
  ('german',    'ألماني - بوبنهايم',              'German (Bubenheim & Elyas)',   '', null, 19, true),
  ('jalalayn',  'تفسير الجلالين',                 'Tafsir Al-Jalalayn',           '', null, 20, true),
  ('qurtubi',   'تفسير القرطبي',                  'Tafsir Al-Qurtubi',            '', null, 21, true),
  ('miqbas',    'تنوير المقباس من تفسير ابن عباس', 'Tafsir Tanwir al-Miqbas',      '', null, 22, true),
  ('waseet',    'التفسير الوسيط',                 'Tafsir Al-Waseet',             '', null, 23, true),
  ('baghawi',   'تفسير البغوي',                   'Tafsir Al-Baghawi',            '', null, 24, true)
on conflict (code) do nothing;
