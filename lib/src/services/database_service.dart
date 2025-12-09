import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;
  static const String _tableName = 'location_history';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'cycle_tracking.db');

      return await openDatabase(
        path,
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_id TEXT NOT NULL,
              user_id TEXT NOT NULL,
              vehicle_no TEXT,
              latitude REAL NOT NULL,
              longitude REAL NOT NULL,
              speed INTEGER DEFAULT 0,
              accuracy INTEGER DEFAULT 0,
              battery INTEGER DEFAULT 0,
              timestamp INTEGER NOT NULL,
              synced INTEGER DEFAULT 0,
              created_at INTEGER DEFAULT (strftime('%s', 'now'))
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // Migrate from version 1 to 2
            await db.execute('''
              ALTER TABLE $_tableName ADD COLUMN device_id TEXT DEFAULT '';
            ''');
            await db.execute('''
              ALTER TABLE $_tableName ADD COLUMN user_id TEXT DEFAULT '';
            ''');
            await db.execute('''
              ALTER TABLE $_tableName ADD COLUMN speed REAL DEFAULT 0;
            ''');
            await db.execute('''
              ALTER TABLE $_tableName ADD COLUMN accuracy REAL DEFAULT 0;
            ''');
            await db.execute('''
              ALTER TABLE $_tableName ADD COLUMN battery INTEGER DEFAULT 0;
            ''');
          }
          if (oldVersion < 3) {
            // Migrate from version 2 to 3 - add vehicle_no column
            await db.execute('''
              ALTER TABLE $_tableName ADD COLUMN vehicle_no TEXT;
            ''');
          }
          if (oldVersion < 4) {
            // Migrate from version 3 to 4 - convert speed and accuracy to INTEGER
            // SQLite stores values dynamically, so we just need to ensure integer values
            // Update existing records to have integer values
            await db.execute('''
              UPDATE $_tableName SET speed = CAST(ROUND(speed) AS INTEGER), accuracy = CAST(ROUND(accuracy) AS INTEGER);
            ''');
            // Note: SQLite doesn't enforce column types strictly, so the schema change
            // is mainly for documentation. The values will be stored as integers going forward.
          }
        },
      );
    } catch (e) {
      // If database initialization fails, try to get databases path again
      try {
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'cycle_tracking.db');
        return await openDatabase(path, version: 1);
      } catch (e2) {
        rethrow;
      }
    }
  }

  Future<int> insertLocation({
    required String deviceId,
    required String userId,
    required double latitude,
    required double longitude,
    String? vehicleNo,
    int speed = 0,
    int accuracy = 0,
    int battery = 0,
    int? timestamp,
  }) async {
    final db = await database;
    return await db.insert(_tableName, {
      'device_id': deviceId,
      'user_id': userId,
      'vehicle_no': vehicleNo,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'accuracy': accuracy,
      'battery': battery,
      'timestamp': timestamp ?? DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedLocations({
    int limit = 10,
  }) async {
    final db = await database;
    return await db.query(
      _tableName,
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'timestamp ASC',
      limit: limit,
    );
  }

  Future<void> markAsSynced(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.update(
      _tableName,
      {'synced': 1},
      where: 'id IN (${ids.map((_) => '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<List<Map<String, dynamic>>> getAllLocations() async {
    final db = await database;
    return await db.query(_tableName, orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> getLocationsByDateRange({
    required int fromTimestamp,
    required int toTimestamp,
  }) async {
    final db = await database;
    return await db.query(
      _tableName,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [fromTimestamp, toTimestamp],
      orderBy: 'timestamp DESC',
    );
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete(_tableName);
  }

  // Get polling statistics by day
  Future<List<Map<String, dynamic>>> getPollingStatsByDay() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        date(timestamp/1000, 'unixepoch') as date,
        COUNT(*) as count
      FROM $_tableName
      GROUP BY date
      ORDER BY date DESC
    ''');
    return result;
  }

  // Get polling statistics by month
  Future<List<Map<String, dynamic>>> getPollingStatsByMonth() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y-%m', datetime(timestamp/1000, 'unixepoch')) as month,
        COUNT(*) as count
      FROM $_tableName
      GROUP BY month
      ORDER BY month DESC
    ''');
    return result;
  }

  // Get polling statistics by year
  Future<List<Map<String, dynamic>>> getPollingStatsByYear() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        strftime('%Y', datetime(timestamp/1000, 'unixepoch')) as year,
        COUNT(*) as count
      FROM $_tableName
      GROUP BY year
      ORDER BY year DESC
    ''');
    return result;
  }

  // Get total polling count
  Future<int> getTotalPollingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName',
    );
    return result.first['count'] as int;
  }

  // Get polling count for a specific date
  Future<int> getPollingCountForDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(
      date.year,
      date.month,
      date.day,
    ).millisecondsSinceEpoch;
    final endOfDay = DateTime(
      date.year,
      date.month,
      date.day,
      23,
      59,
      59,
    ).millisecondsSinceEpoch;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as count 
      FROM $_tableName 
      WHERE timestamp >= ? AND timestamp <= ?
    ''',
      [startOfDay, endOfDay],
    );

    return result.first['count'] as int;
  }
}
