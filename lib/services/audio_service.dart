import 'package:just_audio/just_audio.dart';
import '../models/sound_model.dart';
import 'preferences_service.dart';

class AudioService {
  static final _player = AudioPlayer();

  static Future<void> playAsset(String path) async {
    try {
      await _player.stop();
      await _player.setAsset(path);
      await _player.play();
    } catch (_) {}
  }

  static Future<void> playFile(String path) async {
    try {
      await _player.stop();
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {}
  }

  static Future<void> onPlugIn() async {
    final id = await PrefsService.getPlugIn();
    if (id == 'custom') {
      final path = await PrefsService.getCustomIn();
      if (path != null) { await playFile(path); return; }
    }
    final sound = ZapSoundLibrary.all.firstWhere((s) => s.id == id, orElse: () => ZapSoundLibrary.all.first);
    await playAsset(sound.assetPath);
  }

  static Future<void> onPlugOut() async {
    final id = await PrefsService.getPlugOut();
    if (id == 'custom') {
      final path = await PrefsService.getCustomOut();
      if (path != null) { await playFile(path); return; }
    }
    final sound = ZapSoundLibrary.all.firstWhere((s) => s.id == id, orElse: () => ZapSoundLibrary.all[1]);
    await playAsset(sound.assetPath);
  }

  static void dispose() => _player.dispose();
}
