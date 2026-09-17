import 'package:record/record.dart';

/// Records 16 kHz mono WAV — exactly what whisper.cpp expects, so no
/// conversion step is needed before transcription.
class RecorderService {
  final AudioRecorder _recorder = AudioRecorder();

  static const _config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
  );

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start(String path) => _recorder.start(_config, path: path);

  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  /// Emits the current input level in dBFS (roughly -160 … 0).
  Stream<Amplitude> amplitude() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 80));

  Future<void> dispose() => _recorder.dispose();
}
