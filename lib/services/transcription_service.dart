import 'dart:async';

import 'package:whisper_ggml/whisper_ggml.dart';

import '../data/memo_repository.dart';
import '../models/memo.dart';
import 'audio_store.dart';
import 'model_manager.dart';

/// Sequential background transcription queue.
///
/// Memos are transcribed one at a time; the model stays loaded while the
/// queue drains and is released afterwards to free memory. If no model is
/// downloaded yet, memos simply stay queued until [resumePending] is called
/// again (the model download does that).
class TranscriptionService {
  TranscriptionService({
    required this._repo,
    required this._store,
    required this._readyModel,
    required this._onChanged,
  });

  final MemoRepository _repo;
  final AudioStore _store;
  final Future<WhisperModelChoice?> Function() _readyModel;
  final void Function() _onChanged;

  final WhisperController _controller = WhisperController();
  final List<String> _queue = [];
  bool _draining = false;

  /// Nudges whisper toward punctuated German and away from the usual
  /// hallucinations on short clips.
  static const _initialPrompt =
      'Dies ist eine kurze Sprachnotiz auf Deutsch, mit Satzzeichen.';

  void enqueue(String memoId) {
    if (!_queue.contains(memoId)) _queue.add(memoId);
    unawaited(_drain());
  }

  /// Re-queues everything that was never finished, e.g. after the app was
  /// killed mid-transcription or before the model was downloaded.
  Future<void> resumePending() async {
    final memos = await _repo.all();
    for (final memo in memos.reversed) {
      if (memo.status == TranscriptionStatus.pending ||
          memo.status == TranscriptionStatus.transcribing) {
        enqueue(memo.id);
      }
    }
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    var modelLoaded = false;
    try {
      while (_queue.isNotEmpty) {
        final choice = await _readyModel();
        if (choice == null) break;
        final id = _queue.removeAt(0);
        modelLoaded = true;
        await _transcribe(id, choice);
      }
    } finally {
      if (modelLoaded) await _controller.releaseModel();
      _draining = false;
    }
  }

  Future<void> _transcribe(String id, WhisperModelChoice choice) async {
    final memo = await _repo.byId(id);
    if (memo == null) return;

    await _repo.setStatus(id, TranscriptionStatus.transcribing);
    _onChanged();

    try {
      final result = await _controller.transcribe(
        model: choice.model,
        audioPath: _store.pathFor(memo.fileName),
        lang: 'de',
        initialPrompt: _initialPrompt,
        noContext: true,
        keepModelLoaded: true,
      );
      final text = result?.transcription.text.trim() ?? '';
      await _repo.setTranscript(id, text, TranscriptionStatus.done);
    } catch (_) {
      await _repo.setStatus(id, TranscriptionStatus.failed);
    }
    _onChanged();
  }
}
