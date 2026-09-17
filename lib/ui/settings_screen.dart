import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/model_manager.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final model = ref.watch(modelProvider).value;
    final notifier = ref.read(modelProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: model == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(
                    'Sprachmodell',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                RadioGroup<WhisperModelChoice>(
                  groupValue: model.selected,
                  onChanged: (choice) {
                    if (choice != null) notifier.select(choice);
                  },
                  child: Column(
                    children: [
                      for (final choice in WhisperModelChoice.values)
                        RadioListTile<WhisperModelChoice>(
                          value: choice,
                          title: Text('${choice.label} · ${choice.sizeMb} MB'),
                          subtitle: Text(choice.description),
                          secondary: _ModelAction(choice: choice, model: model),
                        ),
                    ],
                  ),
                ),
                if (model.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Text(
                      model.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Text(
                    'Die Transkription läuft vollständig auf dem Gerät. '
                    'Ein Modellwechsel gilt für neue Aufnahmen; bestehende '
                    'Notizen kannst du in der Detailansicht neu transkribieren '
                    'lassen, falls sie fehlgeschlagen sind.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.language),
                  title: Text('Transkriptionssprache'),
                  subtitle: Text('Deutsch'),
                ),
              ],
            ),
    );
  }
}

class _ModelAction extends ConsumerWidget {
  const _ModelAction({required this.choice, required this.model});

  final WhisperModelChoice choice;
  final ModelState model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(modelProvider.notifier);

    if (model.downloading == choice) {
      return SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: CircularProgressIndicator(value: model.progress),
        ),
      );
    }
    if (model.downloaded.contains(choice)) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Modell löschen',
        onPressed: () => notifier.delete(choice),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download),
      tooltip: 'Herunterladen',
      onPressed: model.downloading == null ? () => notifier.download(choice) : null,
    );
  }
}
