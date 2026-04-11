import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class SyncAction {
  const SyncAction({
    required this.table,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.createdAt,
  });

  final String table;
  final String entityId;
  final String operation;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
}

class SyncLocalStore {
  Database? _database;

  Future<Database> _open() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ganapp_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE pending_actions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_name TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  Future<void> enqueue(SyncAction action) async {
    final db = await _open();
    await db.insert('pending_actions', {
      'table_name': action.table,
      'entity_id': action.entityId,
      'operation': action.operation,
      'payload': jsonEncode(action.payload),
      'created_at': action.createdAt.toIso8601String(),
    });
  }

  Future<List<SyncAction>> getPendingActions() async {
    final db = await _open();
    final rows = await db.query('pending_actions', orderBy: 'id ASC');

    return rows.map((row) {
      return SyncAction(
        table: row['table_name'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        payload: jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        createdAt: DateTime.parse(row['created_at'] as String),
      );
    }).toList();
  }

  Future<void> clearPendingActions() async {
    final db = await _open();
    await db.delete('pending_actions');
  }

  Future<int> pendingCount() async {
    final db = await _open();
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM pending_actions'),
    );
    return count ?? 0;
  }
}
