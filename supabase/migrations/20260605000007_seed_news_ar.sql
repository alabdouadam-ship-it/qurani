-- ============================================================================
-- Migration 0007 — Seed Arabic news announcements
-- ============================================================================
-- Inserts the first batch of Arabic-language announcements into news_items so
-- the news feed isn't empty after dropping the bundled news_initial.json.
--
-- Announcements (all in Arabic, targeted to Arabic UI users):
--   1. New tafsir books (one post listing all six).
--   2. New Turkish & German translations.
--   3. Search → Read navigation (jump from a search result to the ayah).
--
-- Notes:
--   * Idempotent & non-destructive: ON CONFLICT (id) DO NOTHING, so re-running
--     or pushing to a DB that already has these rows changes nothing, and any
--     later dashboard edits are preserved.
--   * language='ar' + category_ar only + target_languages='{ar}' → these are
--     shown ONLY to Arabic-locale users (the client hides items whose
--     per-language category is missing, and honours target_languages).
--   * send_notification=true → the client pushes these to users who installed
--     BEFORE the publish_date (existing users get informed; brand-new installs
--     see them in the list but aren't push-spammed). Flip to false from the
--     dashboard if you don't want a push for any of them.
--   * valid_until is one year out; adjust per item as needed.
-- ============================================================================

insert into public.news_items
  (id, title, description, type, media_url, source_url,
   publish_date, valid_until, language,
   category_ar, category_en, category_fr,
   target_languages, target_countries, excluded_countries,
   is_featured, send_notification, is_published)
values
  (
    'news_tafsir_books_2026',
    '📚 إضافة كتب التفسير',
    E'أضفنا مجموعة من كتب التفسير المعتمدة لإثراء فهمك لكتاب الله:\n' ||
    E'• تفسير الميسر (مجمع الملك فهد)\n' ||
    E'• تفسير الجلالين\n' ||
    E'• تفسير القرطبي\n' ||
    E'• تنوير المقباس من تفسير ابن عباس\n' ||
    E'• التفسير الوسيط\n' ||
    E'• تفسير البغوي\n\n' ||
    E'يمكنك اختيار التفسير من شاشة قراءة القرآن عبر قائمة الإصدارات.',
    'text', '', '',
    now() - interval '2 hours', now() + interval '365 days', 'ar',
    'تحديثات', null, null,
    '{ar}', '{}', '{}',
    true, true, true
  ),
  (
    'news_translations_tr_de_2026',
    '🌍 ترجمتان جديدتان: التركية والألمانية',
    E'أضفنا ترجمتين جديدتين لمعاني القرآن الكريم:\n' ||
    E'• التركية — Diyanet Vakfı\n' ||
    E'• الألمانية — Bubenheim & Elyas\n\n' ||
    E'اخترها من قائمة الإصدارات في شاشة القراءة.',
    'text', '', '',
    now() - interval '1 hour', now() + interval '365 days', 'ar',
    'تحديثات', null, null,
    '{ar}', '{}', '{}',
    false, true, true
  ),
  (
    'news_search_to_read_2026',
    '🔎 الانتقال من البحث إلى القراءة',
    E'أصبح بإمكانك الآن الانتقال مباشرةً من نتيجة البحث في القرآن إلى الآية ' ||
    E'في شاشة القراءة، حيث يتم تحديد الآية والانتقال إليها تلقائيًا، ' ||
    E'ثم تتابع القراءة والتنقل بكل حرية.',
    'text', '', '',
    now(), now() + interval '365 days', 'ar',
    'مزايا جديدة', null, null,
    '{ar}', '{}', '{}',
    false, true, true
  )
on conflict (id) do nothing;
