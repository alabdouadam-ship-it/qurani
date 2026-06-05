-- ============================================================================
-- Migration 0008 — Seed English & French news announcements
-- ============================================================================
-- English + French copies of the three announcements seeded in Arabic by
-- migration 0007. News content (title/description) is NOT translated within a
-- single row — one row per language is the model — so each announcement gets
-- its own en and fr row, language-targeted so each user sees only their copy.
--
-- Pairing (same logical announcement, one row per language):
--   tafsir books      → news_tafsir_books_2026   (ar) / _en / _fr
--   TR & DE i18n      → news_translations_tr_de_2026 (ar) / _en / _fr
--   search → read     → news_search_to_read_2026  (ar) / _en / _fr
--
-- Notes (identical conventions to 0007):
--   * Idempotent & non-destructive: ON CONFLICT (id) DO NOTHING.
--   * language + target_languages scope visibility to that UI language only.
--   * category set ONLY for the row's own language (others null) — matches the
--     client's isVisibleForLanguage completeness rule.
--   * publish_date in the past + 1yr valid_until so the RLS read policy passes.
--   * send_notification=true; flip to false from the dashboard to suppress push.
-- ============================================================================

insert into public.news_items
  (id, title, description, type, media_url, source_url,
   publish_date, valid_until, language,
   category_ar, category_en, category_fr,
   target_languages, target_countries, excluded_countries,
   is_featured, send_notification, is_published)
values
  -- ── Tafsir books ────────────────────────────────────────────────────────
  (
    'news_tafsir_books_2026_en',
    '📚 New Tafsir Books Added',
    E'We added a set of trusted tafsir (exegesis) books to enrich your ' ||
    E'understanding of the Qur''an:\n' ||
    E'• Tafsir Al-Muyassar (King Fahd Complex)\n' ||
    E'• Tafsir Al-Jalalayn\n' ||
    E'• Tafsir Al-Qurtubi\n' ||
    E'• Tanwir al-Miqbas (Ibn Abbas)\n' ||
    E'• Tafsir Al-Waseet\n' ||
    E'• Tafsir Al-Baghawi\n\n' ||
    E'Pick a tafsir from the editions menu on the Read Qur''an screen.',
    'text', '', '',
    now() - interval '2 hours', now() + interval '365 days', 'en',
    null, 'Updates', null,
    '{en}', '{}', '{}',
    true, true, true
  ),
  (
    'news_tafsir_books_2026_fr',
    '📚 Nouveaux livres de Tafsir',
    E'Nous avons ajouté plusieurs livres de tafsir (exégèse) reconnus pour ' ||
    E'enrichir votre compréhension du Coran :\n' ||
    E'• Tafsir Al-Muyassar (Complexe du Roi Fahd)\n' ||
    E'• Tafsir Al-Jalalayn\n' ||
    E'• Tafsir Al-Qurtubi\n' ||
    E'• Tanwir al-Miqbas (Ibn Abbas)\n' ||
    E'• Tafsir Al-Waseet\n' ||
    E'• Tafsir Al-Baghawi\n\n' ||
    E'Choisissez un tafsir depuis le menu des éditions sur l''écran de lecture.',
    'text', '', '',
    now() - interval '2 hours', now() + interval '365 days', 'fr',
    null, null, 'Mises à jour',
    '{fr}', '{}', '{}',
    true, true, true
  ),
  -- ── Turkish & German translations ────────────────────────────────────────
  (
    'news_translations_tr_de_2026_en',
    '🌍 Two New Translations: Turkish & German',
    E'We added two new translations of the meanings of the Qur''an:\n' ||
    E'• Turkish — Diyanet Vakfı\n' ||
    E'• German — Bubenheim & Elyas\n\n' ||
    E'Select them from the editions menu on the Read screen.',
    'text', '', '',
    now() - interval '1 hour', now() + interval '365 days', 'en',
    null, 'Updates', null,
    '{en}', '{}', '{}',
    false, true, true
  ),
  (
    'news_translations_tr_de_2026_fr',
    '🌍 Deux nouvelles traductions : turc et allemand',
    E'Nous avons ajouté deux nouvelles traductions des sens du Coran :\n' ||
    E'• Turc — Diyanet Vakfı\n' ||
    E'• Allemand — Bubenheim & Elyas\n\n' ||
    E'Sélectionnez-les depuis le menu des éditions sur l''écran de lecture.',
    'text', '', '',
    now() - interval '1 hour', now() + interval '365 days', 'fr',
    null, null, 'Mises à jour',
    '{fr}', '{}', '{}',
    false, true, true
  ),
  -- ── Search → Read navigation ─────────────────────────────────────────────
  (
    'news_search_to_read_2026_en',
    '🔎 Jump from Search to Reading',
    E'You can now go directly from a Qur''an search result to the verse on ' ||
    E'the Read screen: the verse is highlighted and scrolled into view ' ||
    E'automatically, then you''re free to keep reading and navigating.',
    'text', '', '',
    now(), now() + interval '365 days', 'en',
    null, 'New features', null,
    '{en}', '{}', '{}',
    false, true, true
  ),
  (
    'news_search_to_read_2026_fr',
    '🔎 Aller de la recherche à la lecture',
    E'Vous pouvez désormais passer directement d''un résultat de recherche ' ||
    E'dans le Coran au verset sur l''écran de lecture : le verset est ' ||
    E'surligné et affiché automatiquement, puis vous continuez à lire et à ' ||
    E'naviguer librement.',
    'text', '', '',
    now(), now() + interval '365 days', 'fr',
    null, null, 'Nouveautés',
    '{fr}', '{}', '{}',
    false, true, true
  )
on conflict (id) do nothing;
