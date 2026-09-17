import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/memo.dart';
import '../providers.dart';
import 'format.dart';
import 'memo_detail_screen.dart';
import 'record_screen.dart';
import 'settings_screen.dart';

class MemoListScreen extends ConsumerStatefulWidget {
  const MemoListScreen({super.key});

  @override
  ConsumerState<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends ConsumerState<MemoListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memos = ref.watch(memosProvider);
    final model = ref.watch(modelProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprachnotizen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Einstellungen',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (model != null && !model.selectedReady) _ModelBanner(model: model),
          Expanded(
            child: memos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (all) => all.isEmpty
                  ? const _EmptyState()
                  : _MemoList(all: all, search: _search),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.large(
        tooltip: 'Aufnehmen',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const RecordScreen(),
          ),
        ),
        child: const Icon(Icons.mic),
      ),
    );
  }
}

class _MemoList extends ConsumerStatefulWidget {
  const _MemoList({required this.all, required this.search});

  final List<Memo> all;
  final TextEditingController search;

  @override
  ConsumerState<_MemoList> createState() => _MemoListState();
}

class _MemoListState extends ConsumerState<_MemoList> {
  @override
  Widget build(BuildContext context) {
    final query = widget.search.text.trim().toLowerCase();
    final memos = query.isEmpty
        ? widget.all
        : widget.all
            .where((m) => (m.transcript ?? '').toLowerCase().contains(query))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: widget.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'In Transkripten suchen',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        widget.search.clear();
                        setState(() {});
                      },
                    ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(28)),
              ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: memos.isEmpty
              ? const Center(child: Text('Keine Treffer'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 112),
                  itemCount: memos.length,
                  itemBuilder: (_, i) => _MemoTile(memo: memos[i]),
                ),
        ),
      ],
    );
  }
}

class _MemoTile extends ConsumerWidget {
  const _MemoTile({required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final placeholder = switch (memo.status) {
      TranscriptionStatus.pending => 'Wartet auf Transkription',
      TranscriptionStatus.transcribing => 'Wird transkribiert …',
      TranscriptionStatus.failed => 'Transkription fehlgeschlagen',
      TranscriptionStatus.done => 'Keine Sprache erkannt',
    };

    return Dismissible(
      key: ValueKey(memo.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) => confirmDelete(context),
      onDismissed: (_) => ref.read(memosProvider.notifier).delete(memo),
      child: ListTile(
        leading: _StatusIcon(status: memo.status),
        title: Text(
          memo.hasTranscript ? memo.transcript! : placeholder,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: memo.hasTranscript
              ? null
              : TextStyle(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        subtitle: Text(
          '${formatDateTime(memo.createdAt)} · ${formatDuration(memo.duration)}',
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MemoDetailScreen(memoId: memo.id)),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final TranscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 24,
      height: 24,
      child: switch (status) {
        TranscriptionStatus.pending =>
          Icon(Icons.hourglass_empty, color: scheme.onSurfaceVariant),
        TranscriptionStatus.transcribing => const Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        TranscriptionStatus.failed =>
          Icon(Icons.error_outline, color: scheme.error),
        TranscriptionStatus.done => Icon(Icons.notes, color: scheme.primary),
      },
    );
  }
}

class _ModelBanner extends ConsumerWidget {
  const _ModelBanner({required this.model});

  final ModelState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final choice = model.selected;
    final downloading = model.downloading == choice;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              downloading
                  ? 'Sprachmodell wird geladen … ${(model.progress * 100).round()} %'
                  : 'Zum Transkribieren wird das Sprachmodell „${choice.label}“ '
                      '(${choice.sizeMb} MB) benötigt. Der Download passiert einmalig.',
            ),
            const SizedBox(height: 12),
            if (downloading)
              LinearProgressIndicator(value: model.progress)
            else
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Herunterladen'),
                onPressed: () =>
                    ref.read(modelProvider.notifier).download(choice),
              ),
            if (model.error != null) ...[
              const SizedBox(height: 8),
              Text(
                model.error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'Noch keine Notizen.\nTippe auf das Mikrofon, um loszulegen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Notiz löschen?'),
      content: const Text('Aufnahme und Transkript werden endgültig gelöscht.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Löschen'),
        ),
      ],
    ),
  );
  return result ?? false;
}
