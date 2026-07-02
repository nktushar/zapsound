/// Which event a sound is being picked for.
enum SoundTarget { plugIn, plugOut, batteryFull }

class SoundModel {
  final String id;
  final String name;
  final String emoji;
  final String assetPath;
  final bool isPremium;
  final String category;

  const SoundModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.assetPath,
    required this.isPremium,
    required this.category,
  });

  /// Basename persisted for the native layer; matches the res/raw file name.
  String get fileName => id == 'custom'
      ? 'custom'
      : assetPath.split('/').last.replaceAll('.wav', '');
}

class ZapSoundLibrary {
  static const List<SoundModel> all = [
    // FREE
    SoundModel(id: 's1', name: 'Power Up',     emoji: '⚡', assetPath: 'assets/sounds/power_up.wav',     isPremium: false, category: 'Classic'),
    SoundModel(id: 's2', name: 'Coin Collect',  emoji: '🪙', assetPath: 'assets/sounds/coin.wav',         isPremium: false, category: 'Classic'),
    SoundModel(id: 's3', name: 'Simple Beep',   emoji: '📢', assetPath: 'assets/sounds/beep.wav',         isPremium: false, category: 'Classic'),
    SoundModel(id: 's4', name: 'Ding!',         emoji: '🔔', assetPath: 'assets/sounds/ding.wav',         isPremium: false, category: 'Classic'),
    SoundModel(id: 's5', name: 'Pop',           emoji: '🫧', assetPath: 'assets/sounds/pop.wav',          isPremium: false, category: 'Classic'),
    // PREMIUM
    SoundModel(id: 'p1', name: 'Cash Register', emoji: '💰', assetPath: 'assets/sounds/cash_register.wav',isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p2', name: 'Level Up!',     emoji: '🎮', assetPath: 'assets/sounds/level_up.wav',     isPremium: true,  category: 'Gaming'),
    SoundModel(id: 'p3', name: 'Lightsaber',    emoji: '⚔️', assetPath: 'assets/sounds/lightsaber.wav',   isPremium: true,  category: 'Sci-Fi'),
    SoundModel(id: 'p4', name: 'Fart',          emoji: '💨', assetPath: 'assets/sounds/fart.wav',         isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p5', name: 'Ta-Da!',        emoji: '🎺', assetPath: 'assets/sounds/tada.wav',         isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p6', name: 'Error Sound',   emoji: '❌', assetPath: 'assets/sounds/error.wav',        isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p7', name: 'Airhorn',       emoji: '📣', assetPath: 'assets/sounds/airhorn.wav',      isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p8', name: 'Sword Slash',   emoji: '🗡️', assetPath: 'assets/sounds/sword.wav',        isPremium: true,  category: 'Gaming'),
    SoundModel(id: 'p9', name: 'Laser Beam',    emoji: '🔴', assetPath: 'assets/sounds/laser.wav',        isPremium: true,  category: 'Sci-Fi'),
    SoundModel(id: 'p10',name: 'Notification',  emoji: '📱', assetPath: 'assets/sounds/notif.wav',        isPremium: true,  category: 'Classic'),
    // PREMIUM — Retro pack
    SoundModel(id: 'p11',name: 'Arcade Win',    emoji: '🕹️', assetPath: 'assets/sounds/arcade_win.wav',   isPremium: true,  category: 'Retro'),
    SoundModel(id: 'p12',name: 'Game Over',     emoji: '👾', assetPath: 'assets/sounds/game_over.wav',    isPremium: true,  category: 'Retro'),
    SoundModel(id: 'p13',name: '8-bit Rise',    emoji: '🎛️', assetPath: 'assets/sounds/retro_rise.wav',   isPremium: true,  category: 'Retro'),
    SoundModel(id: 'p14',name: 'Combo Hit',     emoji: '💥', assetPath: 'assets/sounds/combo.wav',        isPremium: true,  category: 'Retro'),
    // PREMIUM — Sci-Fi pack
    SoundModel(id: 'p15',name: 'Blaster',       emoji: '🔫', assetPath: 'assets/sounds/blaster.wav',      isPremium: true,  category: 'Sci-Fi'),
    SoundModel(id: 'p16',name: 'Warp Drive',    emoji: '🚀', assetPath: 'assets/sounds/warp.wav',         isPremium: true,  category: 'Sci-Fi'),
    SoundModel(id: 'p17',name: 'Robo Beep',     emoji: '🤖', assetPath: 'assets/sounds/robot_beep.wav',   isPremium: true,  category: 'Sci-Fi'),
    SoundModel(id: 'p18',name: 'Alien Signal',  emoji: '🛸', assetPath: 'assets/sounds/alien.wav',        isPremium: true,  category: 'Sci-Fi'),
    // PREMIUM — Chill pack
    SoundModel(id: 'p19',name: 'Crystal Chime', emoji: '✨', assetPath: 'assets/sounds/chime.wav',        isPremium: true,  category: 'Chill'),
    SoundModel(id: 'p20',name: 'Marimba',       emoji: '🎵', assetPath: 'assets/sounds/marimba.wav',      isPremium: true,  category: 'Chill'),
    SoundModel(id: 'p21',name: 'Droplet',       emoji: '💧', assetPath: 'assets/sounds/droplet.wav',      isPremium: true,  category: 'Chill'),
    SoundModel(id: 'p22',name: 'Doorbell',      emoji: '🚪', assetPath: 'assets/sounds/doorbell.wav',     isPremium: true,  category: 'Classic'),
    // PREMIUM — Funny additions
    SoundModel(id: 'p23',name: 'Boing!',        emoji: '🤸', assetPath: 'assets/sounds/boing.wav',        isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p24',name: 'Slide Whistle', emoji: '🎢', assetPath: 'assets/sounds/whistle_up.wav',   isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p25',name: 'Honk',          emoji: '🦆', assetPath: 'assets/sounds/honk.wav',         isPremium: true,  category: 'Funny'),
    // Custom recording (premium)
    SoundModel(id: 'custom', name: 'My Recording', emoji: '🎙️', assetPath: '', isPremium: true, category: 'Custom'),
  ];

  static List<String> get categories =>
      ['All', ...all.map((s) => s.category).toSet().toList()];
}
