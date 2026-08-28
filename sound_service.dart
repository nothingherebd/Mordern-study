import 'package:audioplayers/audioplayers.dart';
import 'storage.dart';

/// Tiny wrapper so every screen plays sounds the same way and respects
/// the Settings > Sound toggle.
class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> _play(String asset) async {
    final enabled = Storage.getConfig()['soundEnabled'] as bool? ?? true;
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$asset'));
    } catch (_) {
      // Never let a missing/blocked audio device crash the study session.
    }
  }

  static Future<void> playStart() => _play('start_chime.mp3');
  static Future<void> playStop() => _play('stop_chime.mp3');
  static Future<void> playComplete() => _play('complete_alert.mp3');
}
