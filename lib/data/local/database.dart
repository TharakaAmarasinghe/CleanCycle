import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Single source of truth for the local schema. Every screen reads from
/// these tables, never directly from Firestore. Firestore is a
/// replication target, reached only through the sync service.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'cleancycle.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE bags (
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            categories TEXT NOT NULL,
            weight_kg REAL NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE custody_events (
            id TEXT PRIMARY KEY,
            bag_id TEXT NOT NULL,
            actor_id TEXT NOT NULL,
            type TEXT NOT NULL,
            latitude REAL,
            longitude REAL,
            accuracy_m REAL,
            occurred_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            place_name TEXT,
            FOREIGN KEY (bag_id) REFERENCES bags(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE waste_reports (
            id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL,
            category TEXT NOT NULL,
            photo_path TEXT,
            latitude REAL,
            longitude REAL,
            description TEXT,
            status TEXT NOT NULL,
            created_at TEXT NOT NULL,
            synced INTEGER NOT NULL DEFAULT 0,
            place_name TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE outbox (
            id TEXT PRIMARY KEY,
            op_type TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL,
            attempts INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            next_attempt_at TEXT
          )
        ''');

        await db.execute('CREATE INDEX idx_custody_bag ON custody_events(bag_id)');
        await db.execute('CREATE INDEX idx_outbox_next ON outbox(next_attempt_at)');
      },
      // v1 -> v2: place-name cache for custody events.
      // v2 -> v3: place-name cache for waste reports.
      // Existing rows keep their data; new columns start NULL and fill in
      // lazily the first time each row is shown while online.
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE custody_events ADD COLUMN place_name TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE waste_reports ADD COLUMN place_name TEXT');
        }
      },
    );
  }

  /// Wipes and recreates the database. Development only.
  Future<void> resetForDevelopment() async {
    final path = join(await getDatabasesPath(), 'cleancycle.db');
    await deleteDatabase(path);
    _db = null;
  }
}