import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'logger.dart';

/// Single shared SQLite database for user-mutable data.
///
/// Why a single DB (not one per feature):
/// * sqflite serializes all writes to a database at the connection level,
///   so sharing one connection between multiple features gives us strong
///   cross-feature atomicity guarantees for free (e.g. a future "export
///   everything" transaction that spans Tasbeeh + bookmarks + memorization
///   can run in one SQL transaction).
/// * Opening multiple sqflite databases on Android keeps multiple file
///   descriptors open for the lifetime of the app; one DB keeps this lean.
/// * Centralised schema migration: the [migrations] list runs once,
///   top-to-bottom, inside a single `ATTACH`-free upgrade transaction.
///
/// This is distinct from the bundled read-only `assets/data/quran.db` used
/// by `QuranRepository` — that one is an immutable shipped artefact and
/// must not be co-mingled with user data, because schema migrations /
/// pragma tuning / WAL mode / corruption recovery all apply differently
/// to a read-only asset vs. a user-writable store.
class UserDatabaseService {
  UserDatabaseService._();

  static Database? _db;
  static Future<Database>? _opening;

  /// Current expected schema version. Bump this and append a migration
  /// block to [_migrations] whenever the schema changes. Never edit an
  /// existing migration — add a new one instead.
  static const int _schemaVersion = 2;

  /// Returns the shared database, opening and migrating it lazily on the
  /// first call. All callers share the same [Database] instance, which is
  /// also sqflite's recommended pattern.
  static Future<Database> database() async {
    final existing = _db;
    if (existing != null) return existing;
    final inflight = _opening;
    if (inflight != null) return inflight;
    final future = _openAndMigrate();
    _opening = future;
    try {
      final db = await future;
      _db = db;
      return db;
    } finally {
      _opening = null;
    }
  }

  /// Visible for tests — resets the shared handle without deleting the
  /// underlying file. Production code should not call this.
  static Future<void> resetForTests() async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
    _opening = null;
  }

  static Future<Database> _openAndMigrate() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = p.join(docsDir.path, 'qurani_user.db');
    Log.d('UserDatabase', 'Opening user DB at $path');
    return openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async {
        // Enforce FK constraints so `ON DELETE CASCADE` in our schemas
        // actually fires; sqflite disables them by default.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        Log.i('UserDatabase', 'Creating fresh schema at version $version');
        for (final migration in _migrations) {
          await migration(db);
        }
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        Log.i('UserDatabase',
            'Upgrading schema $oldVersion -> $newVersion');
        for (int v = oldVersion; v < newVersion; v++) {
          await _migrations[v](db);
        }
      },
    );
  }

  /// Ordered list of schema-creation / schema-upgrade steps. Index `i`
  /// upgrades the DB from version `i` (or fresh) to version `i+1`.
  /// NEVER edit a migration in place — append a new one instead.
  static final List<Future<void> Function(Database db)> _migrations = [
    // v0 -> v1: initial schema (Tasbeeh groups + items).
    (db) async {
      await db.execute('''
        CREATE TABLE tasbeeh_groups (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          is_custom INTEGER NOT NULL DEFAULT 0,
          position INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE tasbeeh_items (
          id TEXT PRIMARY KEY,
          group_id TEXT NOT NULL REFERENCES tasbeeh_groups(id) ON DELETE CASCADE,
          text TEXT NOT NULL,
          count INTEGER NOT NULL DEFAULT 0,
          position INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE INDEX idx_tasbeeh_items_group
          ON tasbeeh_items(group_id, position)
      ''');
    },

    // v1 -> v2: Wird table — migrates wirds from SharedPreferences JSON
    // into crash-safe, journaled SQLite. The actual data migration
    // (reading `wirds_v1` from prefs and INSERT-ing rows) runs in
    // `WirdService._migrateFromPrefsIfNeeded()` on first access, not
    // here, because `onUpgrade` doesn't have access to SharedPreferences.
    (db) async {
      await db.execute('''
        CREATE TABLE wirds (
          id                    TEXT PRIMARY KEY,
          title                 TEXT NOT NULL,
          dhikr_text            TEXT NOT NULL DEFAULT '',
          target_count          INTEGER NOT NULL DEFAULT 33,
          current_count         INTEGER NOT NULL DEFAULT 0,
          days_of_week          TEXT NOT NULL DEFAULT '1,2,3,4,5,6,7',
          notifications_enabled INTEGER NOT NULL DEFAULT 0,
          notification_time     TEXT NOT NULL DEFAULT '14:00',
          last_updated_date     TEXT,
          is_deleted            INTEGER NOT NULL DEFAULT 0,
          created_at            TEXT NOT NULL,
          position              INTEGER NOT NULL DEFAULT 0
        )
      ''');
    },
  ];
}
