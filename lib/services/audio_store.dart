import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves memo audio files inside the app's documents directory.
class AudioStore {
  AudioStore._(this._dir);

  final Directory _dir;

  static Future<AudioStore> init() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'memos'));
    await dir.create(recursive: true);
    return AudioStore._(dir);
  }

  String pathFor(String fileName) => p.join(_dir.path, fileName);

  Future<void> delete(String fileName) async {
    final file = File(pathFor(fileName));
    if (await file.exists()) await file.delete();
  }
}
