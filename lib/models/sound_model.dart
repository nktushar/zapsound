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
    SoundModel(id: 'p4', name: 'Fart 💨',       emoji: '💨', assetPath: 'assets/sounds/fart.wav',         isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p5', name: 'Ta-Da!',        emoji: '🎺', assetPath: 'assets/sounds/tada.wav',         isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p6', name: 'Error Sound',   emoji: '❌', assetPath: 'assets/sounds/error.wav',        isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p7', name: 'Airhorn',       emoji: '📣', assetPath: 'assets/sounds/airhorn.wav',      isPremium: true,  category: 'Funny'),
    SoundModel(id: 'p8', name: 'Sword Slash',   emoji: '🗡️', assetPath: 'assets/sounds/sword.wav',        isPremium: true,  category: 'Gaming'),
    SoundModel(id: 'p9', name: 'Laser Beam',    emoji: '🔴', assetPath: 'assets/sounds/laser.wav',        isPremium: true,  category: 'Sci-Fi'),
    SoundModel(id: 'p10',name: 'Notification',  emoji: '📱', assetPath: 'assets/sounds/notif.wav',        isPremium: true,  category: 'Classic'),
    // Custom recording (premium)
    SoundModel(id: 'custom', name: 'My Recording', emoji: '🎙️', assetPath: '', isPremium: true, category: 'Custom'),
  ];

  static List<String> get categories =>
      ['All', ...all.map((s) => s.category).toSet().toList()];
}
