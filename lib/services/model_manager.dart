import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// The models the app offers. Each maps to a whisper_ggml enum value (which
/// determines the on-disk path the plugin loads from) and to the quantized
/// q5_1 file on Hugging Face — roughly a third of the size of the f16 file
/// the plugin would download by itself, and faster on phones.
enum WhisperModelChoice {
  base(
    model: WhisperModel.base,
    fileName: 'base-q5_1',
    sizeMb: 60,
    label: 'Base',
    description: 'Schnell, aber ungenauer bei Namen und Fachbegriffen',
  ),
  small(
    model: WhisperModel.small,
    fileName: 'small-q5_1',
    sizeMb: 190,
    label: 'Small',
    description: 'Deutlich genauer für Deutsch (empfohlen)',
  );

  const WhisperModelChoice({
    required this.model,
    required this.fileName,
    required this.sizeMb,
    required this.label,
    required this.description,
  });

  final WhisperModel model;
  final String fileName;
  final int sizeMb;
  final String label;
  final String description;

  Uri get url => Uri.parse(
        'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$fileName.bin',
      );
}

class ModelManager {
  ModelManager(this._prefs);

  static const _selectedKey = 'whisper_model';

  final SharedPreferences _prefs;
  final WhisperController _controller = WhisperController();

  WhisperModelChoice get selected {
    final name = _prefs.getString(_selectedKey);
    return name == null
        ? WhisperModelChoice.small
        : WhisperModelChoice.values.byName(name);
  }

  Future<void> select(WhisperModelChoice choice) =>
      _prefs.setString(_selectedKey, choice.name);

  Future<String> pathFor(WhisperModelChoice choice) =>
      _controller.getPath(choice.model);

  Future<bool> isDownloaded(WhisperModelChoice choice) async =>
      File(await pathFor(choice)).exists();

  /// The selected model, or null if it still has to be downloaded.
  Future<WhisperModelChoice?> readyModel() async =>
      await isDownloaded(selected) ? selected : null;

  /// Streams download progress (0…1). Writes to a `.part` file first so a
  /// half-finished download is never mistaken for a usable model.
  Stream<double> download(WhisperModelChoice choice) async* {
    final target = File(await pathFor(choice));
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    final client = HttpClient();
    try {
      final request = await client.getUrl(choice.url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: choice.url);
      }
      final total = response.contentLength;
      final sink = part.openWrite();
      var received = 0;
      var lastReported = 0.0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final progress = received / total;
            if (progress - lastReported >= 0.005) {
              lastReported = progress;
              yield progress;
            }
          }
        }
      } finally {
        await sink.close();
      }
      await part.rename(target.path);
      yield 1.0;
    } catch (_) {
      if (await part.exists()) await part.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> delete(WhisperModelChoice choice) async {
    final file = File(await pathFor(choice));
    if (await file.exists()) await file.delete();
  }
}
