import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/memo_repository.dart';
import 'providers.dart';
import 'services/audio_store.dart';
import 'services/model_manager.dart';
import 'services/transcription_service.dart';
import 'ui/memo_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = await MemoRepository.open();
  final store = await AudioStore.init();
  final modelManager = ModelManager(await SharedPreferences.getInstance());

  late final ProviderContainer container;
  final transcription = TranscriptionService(
    repo: repo,
    store: store,
    readyModel: modelManager.readyModel,
    onChanged: () => container.read(memosProvider.notifier).refresh(),
  );
  container = ProviderContainer(overrides: [
    memoRepositoryProvider.overrideWithValue(repo),
    audioStoreProvider.overrideWithValue(store),
    modelManagerProvider.overrideWithValue(modelManager),
    transcriptionServiceProvider.overrideWithValue(transcription),
  ]);

  runApp(UncontrolledProviderScope(container: container, child: const App()));

  // Pick up anything left unfinished by a previous run.
  await transcription.resumePending();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprachnotizen',
      theme: ThemeData(colorSchemeSeed: Colors.deepOrange),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
      ),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const MemoListScreen(),
    );
  }
}
