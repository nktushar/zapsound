import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordingService {
  static final _recorder = AudioRecorder();

  static Future<bool> hasPermission() => _recorder.hasPermission();

  static Future<bool> isRecording() => _recorder.isRecording();

  /// Amplitude (dB) updates while recording, for driving a waveform visualizer.
  static Stream<Amplitude> amplitudeStream() =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 120));

  static Future<void> start() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/zap_recording_tmp.m4a';
    final tmp = File(path);
    if (await tmp.exists()) await tmp.delete();
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
  }

  static Future<String?> stop() => _recorder.stop();

  /// Copies the temp recording to a stable filename (e.g. "custom_in" / "custom_out")
  /// and returns the final path to persist in preferences.
  static Future<String> saveAs(String tempPath, String finalName) async {
    final dir = await getApplicationDocumentsDirectory();
    final finalPath = '${dir.path}/$finalName.m4a';
    final existing = File(finalPath);
    if (await existing.exists()) await existing.delete();
    final saved = await File(tempPath).copy(finalPath);
    return saved.path;
  }

  static void dispose() => _recorder.dispose();
}
