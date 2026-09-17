import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/memo.dart';
import '../providers.dart';
import 'format.dart';
import 'memo_list_screen.dart' show confirmDelete;

class MemoDetailScreen extends ConsumerStatefulWidget {
  const MemoDetailScreen({super.key, required this.memoId});

  final String memoId;

  @override
  ConsumerState<MemoDetailScreen> createState() => _MemoDetailScreenState();
}

class _MemoDetailScreenState extends ConsumerState<MemoDetailScreen> {
  final _player = AudioPlayer();
  final _text = TextEditingController();
  Timer? _saveDebounce;

  /// The transcript as last loaded from (or saved to) the store, so an
  /// incoming update from the transcription queue can be told apart from
  /// the user's own edits.
  String? _loadedTranscript;

  Memo? _memoFrom(AsyncValue<List<Memo>> memos) {
    final list = memos.value;
    if (list == null) return null;
    for (final m in list) {
      if (m.id == widget.memoId) return m;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final memo = _memoFrom(ref.read(memosProvider));
    if (memo != null) {
      _loadedTranscript = memo.transcript;
      _text.text = memo.transcript ?? '';
      unawaited(
        _player.setFilePath(ref.read(audioStoreProvider).pathFor(memo.fileName)),
      );
    }
  }

  void _onTranscriptEdited(String text) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), _saveNow);
  }

  void _saveNow() {
    _saveDebounce?.cancel();
    final text = _text.text;
    if (text == _loadedTranscript) return;
    _loadedTranscript = text;
    unawaited(
      ref.read(memosProvider.notifier).updateTranscript(widget.memoId, text),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Transkript kopiert')));
    }
  }

  Future<void> _delete(Memo memo) async {
    if (!await confirmDelete(context)) return;
    await _player.stop();
    if (!mounted) return;
    Navigator.of(context).pop();
    await ref.read(memosProvider.notifier).delete(memo);
  }

  @override
  void dispose() {
    if (_saveDebounce?.isActive ?? false) _saveNow();
    _saveDebounce?.cancel();
    _player.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(memosProvider, (_, next) {
      final memo = _memoFrom(next);
      if (memo != null && memo.transcript != _loadedTranscript) {
        _loadedTranscript = memo.transcript;
        _text.text = memo.transcript ?? '';
      }
    });

    final memo = _memoFrom(ref.watch(memosProvider));
    if (memo == null) return const Scaffold();

    final theme = Theme.of(context);
    final editable = memo.status == TranscriptionStatus.done;

    return Scaffold(
      appBar: AppBar(
        title: Text(formatDateTime(memo.createdAt)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Transkript kopieren',
            onPressed: memo.hasTranscript ? _copy : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Löschen',
            onPressed: () => _delete(memo),
          ),
        ],
      ),
      body: Column(
        children: [
          _PlayerBar(player: _player),
          const Divider(height: 1),
          _StatusRow(memo: memo),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TextField(
                controller: _text,
                enabled: editable,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                onChanged: _onTranscriptEdited,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: editable
                      ? 'Keine Sprache erkannt. Du kannst den Text hier '
                          'selbst eintippen.'
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends ConsumerWidget {
  const _StatusRow({required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (label, icon, color) = switch (memo.status) {
      TranscriptionStatus.pending => (
          'Wartet auf Transkription',
          Icons.hourglass_empty,
          scheme.onSurfaceVariant,
        ),
      TranscriptionStatus.transcribing => (
          'Wird transkribiert …',
          Icons.autorenew,
          scheme.primary,
        ),
      TranscriptionStatus.failed => (
          'Transkription fehlgeschlagen',
          Icons.error_outline,
          scheme.error,
        ),
      TranscriptionStatus.done => (
          'Transkript · ${formatDuration(memo.duration)}',
          Icons.notes,
          scheme.onSurfaceVariant,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(color: color)),
          ),
          if (memo.status == TranscriptionStatus.failed)
            TextButton(
              onPressed: () => ref.read(memosProvider.notifier).retry(memo),
              child: const Text('Erneut versuchen'),
            ),
        ],
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.player});

  final AudioPlayer player;

  Future<void> _togglePlay() async {
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (_, snapshot) {
              final state = snapshot.data;
              final playing = state?.playing == true &&
                  state?.processingState != ProcessingState.completed;
              return IconButton.filled(
                iconSize: 32,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlay,
              );
            },
          ),
          Expanded(
            child: StreamBuilder<Duration?>(
              stream: player.durationStream,
              builder: (_, durationSnap) {
                final duration = durationSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (_, positionSnap) {
                    final position = positionSnap.data ?? Duration.zero;
                    final max = duration.inMilliseconds.toDouble();
                    final value =
                        position.inMilliseconds.clamp(0, max.toInt()).toDouble();
                    return Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: max > 0 ? value : 0,
                            max: max > 0 ? max : 1,
                            onChanged: max > 0
                                ? (v) => player.seek(
                                      Duration(milliseconds: v.round()),
                                    )
                                : null,
                          ),
                        ),
                        Text(
                          '${formatDuration(position)} / ${formatDuration(duration)}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
