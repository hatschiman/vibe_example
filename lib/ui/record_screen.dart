import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/memo.dart';
import '../providers.dart';
import 'format.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  static const _barCount = 48;

  final _stopwatch = Stopwatch();
  final _levels = List<double>.filled(_barCount, 0);
  Timer? _ticker;
  StreamSubscription? _amplitude;
  String? _fileName;
  String? _error;
  bool _recording = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final recorder = ref.read(recorderServiceProvider);
    if (!await recorder.hasPermission()) {
      if (mounted) {
        setState(() => _error = 'Kein Zugriff auf das Mikrofon. Bitte in den '
            'Systemeinstellungen erlauben.');
      }
      return;
    }
    final id = const Uuid().v4();
    _fileName = '$id.wav';
    await recorder.start(ref.read(audioStoreProvider).pathFor(_fileName!));
    if (!mounted) {
      await recorder.cancel();
      return;
    }
    _stopwatch.start();
    _recording = true;
    _ticker = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {}),
    );
    _amplitude = recorder.amplitude().listen((amp) {
      // dBFS: ~-60 is quiet, 0 is clipping.
      final level = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      setState(() {
        _levels.removeAt(0);
        _levels.add(level);
      });
    });
    setState(() {});
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _stopTimers();
    final recorder = ref.read(recorderServiceProvider);
    final duration = _stopwatch.elapsed;

    if (!_recording || duration < const Duration(milliseconds: 500)) {
      await recorder.cancel();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final path = await recorder.stop();
    _recording = false;
    if (path == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final memo = Memo(
      id: _fileName!.replaceAll('.wav', ''),
      createdAt: DateTime.now().subtract(duration),
      duration: duration,
      fileName: _fileName!,
    );
    await ref.read(memosProvider.notifier).add(memo);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _discard() async {
    if (_finishing) return;
    _finishing = true;
    _stopTimers();
    if (_recording) {
      _recording = false;
      await ref.read(recorderServiceProvider).cancel();
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _stopTimers() {
    _stopwatch.stop();
    _ticker?.cancel();
    _amplitude?.cancel();
  }

  @override
  void dispose() {
    _stopTimers();
    if (_recording) {
      unawaited(ref.read(recorderServiceProvider).cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _discard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Verwerfen',
            onPressed: _discard,
          ),
          title: const Text('Aufnahme'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Text(
                formatDuration(_stopwatch.elapsed),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _LevelMeter(
                  levels: _levels,
                  color: _recording
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                child: SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _recording ? _finish : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Fertig', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelMeter extends StatelessWidget {
  const _LevelMeter({required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      width: double.infinity,
      child: CustomPaint(painter: _BarsPainter(levels: levels, color: color)),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({required this.levels, required this.color});

  final List<double> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final slot = size.width / levels.length;
    final barWidth = slot * 0.6;
    for (var i = 0; i < levels.length; i++) {
      final height = math.max(4.0, levels[i] * size.height);
      final rect = Rect.fromCenter(
        center: Offset(i * slot + slot / 2, size.height / 2),
        width: barWidth,
        height: height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
