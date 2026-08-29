/// Web-only loader for the Quran edition data (per-juz shards + shared index).
///
/// **Only import this from `*_web.dart` implementations.** On io (Android/iOS)
/// every edition is read from the bundled `assets/data/quran.db` via
/// `QuranEdition.dbColumn`, so none of this data ships to mobile at all.
///
/// ## Why the data is not a Flutter asset, and not on Firebase Hosting
///
/// It used to live in `assets/data/editions/` and be declared in
/// `pubspec.yaml`, which bundled ~105 MB of web-only JSON into every Android
/// and iOS build even though nothing on those platforms reads it. There is no
/// per-platform asset list in `pubspec.yaml`, so it had to leave `assets/`.
///
/// Serving them from Firebase Hosting was the next problem. Measured against
/// the live site: a cold visit already costs ~3.4 MB (main.dart.js 1.06 MB +
/// canvaskit.wasm 2.14 MB + fonts), Hosting never returns 304 (it answers 200
/// with a full body for both `If-None-Match` and `If-Modified-Since`, retested
/// three ways), and the Spark plan allows 10 GB/month before the site is
/// DISABLED until the next month. That is roughly 3,000 visits — before anyone
/// opens a tafsir. `ar.miqbas.json` alone was 5.21 MB on the wire.
///
/// So the edition data is served from the public GitHub repo via jsDelivr,
/// the same CDN `hadith_service.dart` already uses. It costs us no Hosting
/// bandwidth, and jsDelivr imposes no bandwidth limit of its own.
///
/// ## Why jsDelivr and not the GitHub release
///
/// GitHub *release assets* cannot be fetched from a browser. Verified: the
/// `github.com/.../releases/download/...` URL 302-redirects to
/// `release-assets.githubusercontent.com`, and that final 200 response carries
/// no `Access-Control-Allow-Origin` header at all, so CORS blocks it. Release
/// assets remain correct for the mobile-only mushaf PDFs and MASAQ.csv, where
/// there is no CORS and no size limit.
///
/// ## Why the data is sharded per juz
///
/// jsDelivr enforces a HARD 20 MB per-file limit. Measured against this very
/// repo: `ar.waseet.json` (18.44 MB) → 200, while `ar.qurtubi.json` (20.48 MB)
/// and `ar.miqbas.json` (28.35 MB) → 403 with the body
/// "File size exceeded the configured limit of 20 MB." Two of the fourteen
/// editions were simply unservable whole.
///
/// Sharding also fixes a worse problem. Dart web has no isolates —
/// `compute()` degrades to a same-thread call, see
/// `packages/flutter/lib/src/foundation/_isolates_web.dart` — so a 28 MB
/// `json.decode` froze the UI thread with no way to offload it. The largest
/// shard is now 1,570 KB. See `tool/shard_editions.dart` for the generator.
///
/// ## Caching
///
/// Pinning the URL to a tag (rather than a branch) makes jsDelivr serve
/// `Cache-Control: public, max-age=31536000, immutable` instead of a 7-day
/// `max-age`, which is effectively download-once-per-browser. This matters
/// because web has no filesystem: unlike mobile, we cannot persist a
/// downloaded file ourselves, so the browser HTTP cache is the only cache we
/// get. Bump [kEditionsDataRef] whenever the shards are regenerated, otherwise
/// clients will keep serving the old immutable copy for a year.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Git tag in the data repo that the published shards live under.
///
/// **Bump this every time `tool/shard_editions.dart` output changes**, and push
/// a matching tag. Because the pinned URLs are served `immutable` with a
/// one-year max-age, reusing a ref after changing its content would leave
/// browsers on stale data.
const String kEditionsDataRef = String.fromEnvironment(
  'QURANI_EDITIONS_REF',
  defaultValue: 'editions-v1',
);

/// Optional full override of the base, for local development or self-hosting.
///
/// An absolute `http(s)://` value is used verbatim — the usual case, e.g.
/// pointing at a jsDelivr branch ref while iterating on the data:
/// `--dart-define=QURANI_EDITIONS_BASE=https://cdn.jsdelivr.net/gh/OWNER/REPO@main/data/editions`.
///
/// A relative value is resolved against the document base, for serving the data
/// same-origin. Note that `data/editions` is NOT inside `web/`, so it is not
/// copied into `build/web` — a relative override only works if you place or
/// symlink a copy under `web/` yourself.
const String kEditionsBaseOverride = String.fromEnvironment(
  'QURANI_EDITIONS_BASE',
  defaultValue: '',
);

const String _ownerRepo = 'alabdouadam-ship-it/qurani';

/// Path inside the repo. Deliberately NOT under `web/`: `flutter build web`
/// copies the whole `web/` directory into `build/web`, so leaving 193 MB of
/// edition data there would ship it to Firebase Hosting on every deploy — the
/// exact cost this move exists to avoid. Living at the repo root keeps it out
/// of every build output while staying reachable by the CDN.
const String _repoSubPath = 'data/editions';

/// Primary origin: a real CDN, `Access-Control-Allow-Origin: *`, and
/// `immutable` caching when pinned to a tag.
String get _jsDelivrBase =>
    'https://cdn.jsdelivr.net/gh/$_ownerRepo@$kEditionsDataRef/$_repoSubPath';

/// Fallback origin. `raw.githubusercontent.com` also sends `ACAO: *`, but only
/// `max-age=300` and it is not a CDN, so it is a last resort — chiefly for
/// regions where jsDelivr is blocked.
String get _rawGitHubBase =>
    'https://raw.githubusercontent.com/$_ownerRepo/$kEditionsDataRef/$_repoSubPath';

/// Bases to try in order.
List<Uri> _candidates(String path) {
  if (kEditionsBaseOverride.isNotEmpty) {
    final base = kEditionsBaseOverride.endsWith('/')
        ? kEditionsBaseOverride
        : '$kEditionsBaseOverride/';
    // Relative overrides resolve against the document base so the app keeps
    // working when hosted under a sub-path as well as at the root.
    return [
      base.startsWith('http') ? Uri.parse('$base$path') : Uri.base.resolve('$base$path'),
    ];
  }
  return [
    Uri.parse('$_jsDelivrBase/$path'),
    Uri.parse('$_rawGitHubBase/$path'),
  ];
}

/// The shared index: juz boundaries, full surah metadata, edition metadata.
/// ~24 KB, so the surah list no longer costs a multi-MB edition fetch.
Future<Map<String, dynamic>> loadEditionIndex() => _fetchJson('index.json');

/// One per-juz shard of one edition. [editionDir] is the edition's directory
/// name (the monolith's filename stem, e.g. `ar.miqbas`), [juz] is 1..30.
Future<Map<String, dynamic>> loadEditionShard(String editionDir, int juz) {
  final padded = juz.toString().padLeft(2, '0');
  return _fetchJson('$editionDir/juz-$padded.json');
}

/// A whole un-sharded edition file.
///
/// Still used by `quran_search_service_web`, which genuinely needs the full
/// corpus to build a search index. Its four corpora (`quran-clean`,
/// `quran-simple`, `quran-english`, `quran-french`) are all under 3 MB, so
/// they stay well inside jsDelivr's 20 MB ceiling. Do NOT use this for the
/// tafsirs — `ar.qurtubi` and `ar.miqbas` exceed the limit and will 403.
Future<Map<String, dynamic>> loadWholeEdition(String fileName) =>
    _fetchJson(fileName);

Future<Map<String, dynamic>> _fetchJson(String path) async {
  final candidates = _candidates(path);
  Object? lastError;

  for (var i = 0; i < candidates.length; i++) {
    final uri = candidates[i];
    try {
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        // jsDelivr returns 403 with an explanatory body when a file is over
        // its size limit; surface that rather than a bare status code.
        final hint = resp.body.length <= 200 ? ' — ${resp.body.trim()}' : '';
        throw Exception('HTTP ${resp.statusCode}$hint');
      }

      // Decode as UTF-8 explicitly: `resp.body` guesses latin-1 when the
      // server omits a charset, which mangles Arabic text.
      final body = utf8.decode(resp.bodyBytes);

      // A same-origin override served by Firebase Hosting rewrites every
      // unmatched path to `/index.html` with a 200, so a missing file arrives
      // as HTML rather than a 404. Fail with something readable instead of an
      // opaque JSON parse error.
      if (body.trimLeft().startsWith('<')) {
        throw Exception('expected JSON but got HTML (missing file?)');
      }

      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e;
      if (kDebugMode) {
        debugPrint('[EditionData] $uri failed: $e');
      }
      // Fall through to the next candidate base.
    }
  }

  throw Exception('Failed to load edition data "$path" from '
      '${candidates.length} source(s). Last error: $lastError');
}
