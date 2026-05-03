import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/module_records/domain/module_record.dart';

class ModuleCacheStore {
  Database? _database;

  Future<Database> _open() async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ganapp_module_cache.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE module_records (
            resource_path TEXT NOT NULL,
            id TEXT NOT NULL,
            title TEXT NOT NULL,
            subtitle TEXT NOT NULL,
            footnote TEXT NOT NULL,
            raw_data TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            PRIMARY KEY(resource_path, id)
          )
        ''');
      },
    );

    return _database!;
  }

  Future<void> replaceAll(
    String resourcePath,
    List<ModuleRecord> records,
  ) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete(
        'module_records',
        where: 'resource_path = ?',
        whereArgs: [resourcePath],
      );
      for (final item in records) {
        await txn.insert('module_records', {
          'resource_path': resourcePath,
          'id': item.id,
          'title': item.title,
          'subtitle': item.subtitle,
          'footnote': item.footnote,
          'raw_data': jsonEncode(item.rawData),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<List<ModuleRecord>> list(String resourcePath) async {
    final db = await _open();
    final rows = await db.query(
      'module_records',
      where: 'resource_path = ?',
      whereArgs: [resourcePath],
      orderBy: 'updated_at DESC',
    );

    return rows.map((row) {
      return ModuleRecord(
        id: row['id'] as String,
        title: row['title'] as String,
        subtitle: row['subtitle'] as String,
        footnote: row['footnote'] as String,
        rawData: jsonDecode(row['raw_data'] as String) as Map<String, dynamic>,
      );
    }).toList();
  }

  Future<void> upsert(String resourcePath, ModuleRecord record) async {
    final db = await _open();
    await db.insert('module_records', {
      'resource_path': resourcePath,
      'id': record.id,
      'title': record.title,
      'subtitle': record.subtitle,
      'footnote': record.footnote,
      'raw_data': jsonEncode(record.rawData),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(String resourcePath, String id) async {
    final db = await _open();
    await db.delete(
      'module_records',
      where: 'resource_path = ? AND id = ?',
      whereArgs: [resourcePath, id],
    );
  }

  Future<void> close() async {
  await _database?.close();
  _database = null;
  }

  
}
