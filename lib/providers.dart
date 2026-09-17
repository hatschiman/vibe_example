import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/memo_repository.dart';
import 'models/memo.dart';
import 'services/audio_store.dart';
import 'services/model_manager.dart';
import 'services/recorder_service.dart';
import 'services/transcription_service.dart';

// The services below are created in main() and injected via overrides.
final memoRepositoryProvider =
    Provider<MemoRepository>((_) => throw UnimplementedError());
final audioStoreProvider =
    Provider<AudioStore>((_) => throw UnimplementedError());
final modelManagerProvider =
    Provider<ModelManager>((_) => throw UnimplementedError());
final transcriptionServiceProvider =
    Provider<TranscriptionService>((_) => throw UnimplementedError());

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final service = RecorderService();
  ref.onDispose(service.dispose);
  return service;
});

class MemosNotifier extends AsyncNotifier<List<Memo>> {
  MemoRepository get _repo => ref.read(memoRepositoryProvider);

  @override
  Future<List<Memo>> build() => _repo.all();

  Future<void> refresh() async {
    state = AsyncData(await _repo.all());
  }

  Future<void> add(Memo memo) async {
    await _repo.insert(memo);
    await refresh();
    ref.read(transcriptionServiceProvider).enqueue(memo.id);
  }

  Future<void> updateTranscript(String id, String transcript) async {
    await _repo.setTranscript(id, transcript, TranscriptionStatus.done);
    await refresh();
  }

  Future<void> retry(Memo memo) async {
    await _repo.setStatus(memo.id, TranscriptionStatus.pending);
    await refresh();
    ref.read(transcriptionServiceProvider).enqueue(memo.id);
  }

  Future<void> delete(Memo memo) async {
    await ref.read(audioStoreProvider).delete(memo.fileName);
    await _repo.delete(memo.id);
    await refresh();
  }
}

final memosProvider =
    AsyncNotifierProvider<MemosNotifier, List<Memo>>(MemosNotifier.new);

class ModelState {
  const ModelState({
    required this.selected,
    required this.downloaded,
    this.downloading,
    this.progress = 0,
    this.error,
  });

  final WhisperModelChoice selected;
  final Set<WhisperModelChoice> downloaded;
  final WhisperModelChoice? downloading;
  final double progress;
  final String? error;

  bool get selectedReady => downloaded.contains(selected);

  ModelState copyWith({
    WhisperModelChoice? selected,
    Set<WhisperModelChoice>? downloaded,
    WhisperModelChoice? downloading,
    bool clearDownloading = false,
    double? progress,
    String? error,
    bool clearError = false,
  }) {
    return ModelState(
      selected: selected ?? this.selected,
      downloaded: downloaded ?? this.downloaded,
      downloading: clearDownloading ? null : (downloading ?? this.downloading),
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ModelNotifier extends AsyncNotifier<ModelState> {
  ModelManager get _manager => ref.read(modelManagerProvider);

  @override
  Future<ModelState> build() async {
    final downloaded = <WhisperModelChoice>{};
    for (final choice in WhisperModelChoice.values) {
      if (await _manager.isDownloaded(choice)) downloaded.add(choice);
    }
    return ModelState(selected: _manager.selected, downloaded: downloaded);
  }

  Future<void> select(WhisperModelChoice choice) async {
    await _manager.select(choice);
    state = AsyncData(state.requireValue.copyWith(selected: choice));
    await ref.read(transcriptionServiceProvider).resumePending();
  }

  Future<void> download(WhisperModelChoice choice) async {
    final current = state.value;
    if (current == null || current.downloading != null) return;
    state = AsyncData(
      current.copyWith(downloading: choice, progress: 0, clearError: true),
    );
    try {
      await for (final progress in _manager.download(choice)) {
        state = AsyncData(state.requireValue.copyWith(progress: progress));
      }
      state = AsyncData(state.requireValue.copyWith(
        clearDownloading: true,
        downloaded: {...state.requireValue.downloaded, choice},
      ));
      await ref.read(transcriptionServiceProvider).resumePending();
    } catch (e) {
      state = AsyncData(state.requireValue.copyWith(
        clearDownloading: true,
        error: 'Download fehlgeschlagen: $e',
      ));
    }
  }

  Future<void> delete(WhisperModelChoice choice) async {
    await _manager.delete(choice);
    final current = state.requireValue;
    state = AsyncData(current.copyWith(
      downloaded: {...current.downloaded}..remove(choice),
    ));
  }
}

final modelProvider =
    AsyncNotifierProvider<ModelNotifier, ModelState>(ModelNotifier.new);
