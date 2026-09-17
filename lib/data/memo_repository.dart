import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/memo.dart';

class MemoRepository {
  MemoRepository._(this._db);

  final Database _db;

  static Future<MemoRepository> open() async {
    final db = await openDatabase(
      p.join(await getDatabasesPath(), 'memos.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE memos (
          id TEXT PRIMARY KEY,
          created_at INTEGER NOT NULL,
          duration_ms INTEGER NOT NULL,
          file_name TEXT NOT NULL,
          transcript TEXT,
          status TEXT NOT NULL
        )
      '''),
    );
    return MemoRepository._(db);
  }

  Future<List<Memo>> all() async {
    final rows = await _db.query('memos', orderBy: 'created_at DESC');
    return rows.map(Memo.fromMap).toList();
  }

  Future<Memo?> byId(String id) async {
    final rows = await _db.query('memos', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Memo.fromMap(rows.first);
  }

  Future<void> insert(Memo memo) => _db.insert('memos', memo.toMap());

  Future<void> setStatus(String id, TranscriptionStatus status) => _db.update(
        'memos',
        {'status': status.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> setTranscript(
    String id,
    String transcript,
    TranscriptionStatus status,
  ) =>
      _db.update(
        'memos',
        {'transcript': transcript, 'status': status.name},
        where: 'id = ?',
        whereArgs: [id],
      );

  Future<void> delete(String id) =>
      _db.delete('memos', where: 'id = ?', whereArgs: [id]);
}
