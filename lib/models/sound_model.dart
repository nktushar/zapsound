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
      : assetPath.split('/').last.replaceFirst(RegExp(r'\.[^.]+$'), '');
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
    SoundModel(id: 'p4', name: 'Fart',          emoji: '💨', assetPath: 'assets/sounds/fart.wav',         isPremium: true,  category: 'Farts'),
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
    SoundModel(id: 'p23',name: 'Boing!',        emoji: '🤸', assetPath: 'assets/sounds/boing.wav',        isPremium: true,  category: 'Cartoon'),
    SoundModel(id: 'p24',name: 'Slide Whistle', emoji: '🎢', assetPath: 'assets/sounds/whistle_up.wav',   isPremium: true,  category: 'Cartoon'),
    SoundModel(id: 'p25',name: 'Honk',          emoji: '🦆', assetPath: 'assets/sounds/honk.wav',         isPremium: true,  category: 'Funny'),
    // PREMIUM — Fun pack (imported library, loudness-matched mp3)
    SoundModel(id: 'p26', name: 'Fahhh', emoji: '😩', assetPath: 'assets/sounds/meme_fah.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p27', name: 'Boom', emoji: '💥', assetPath: 'assets/sounds/meme_boom.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p28', name: 'Sus', emoji: '🤨', assetPath: 'assets/sounds/meme_sus.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p29', name: 'Hankie Pankie', emoji: '🕺', assetPath: 'assets/sounds/meme_hankie_pankie.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p30', name: 'Yes Daddy', emoji: '😏', assetPath: 'assets/sounds/meme_yes_daddy.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p31', name: 'Yes Daddy 2', emoji: '😏', assetPath: 'assets/sounds/meme_yes_daddy_2.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p32', name: 'Oh My~', emoji: '😳', assetPath: 'assets/sounds/meme_oh_my.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p33', name: 'Yamete Kudasai', emoji: '🙅', assetPath: 'assets/sounds/meme_yamete.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p34', name: 'Yamete!', emoji: '🙅', assetPath: 'assets/sounds/meme_yamete_short.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p36', name: 'F-Bomb', emoji: '🤬', assetPath: 'assets/sounds/meme_f_bomb.mp3', isPremium: true, category: 'Memes'),
    SoundModel(id: 'p37', name: 'Mouth Toot', emoji: '👄', assetPath: 'assets/sounds/fart_mouth.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p38', name: 'Squeaker', emoji: '💨', assetPath: 'assets/sounds/fart_squeaker.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p39', name: 'Quick Toot', emoji: '💨', assetPath: 'assets/sounds/fart_quick.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p40', name: 'Pip', emoji: '💨', assetPath: 'assets/sounds/fart_pip.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p41', name: 'Rumbler', emoji: '🌋', assetPath: 'assets/sounds/fart_rumbler.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p42', name: 'Bass Blaster', emoji: '🔊', assetPath: 'assets/sounds/fart_bass.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p43', name: 'Sneaky One', emoji: '🤫', assetPath: 'assets/sounds/fart_sneaky.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p44', name: 'Proud Fart', emoji: '😤', assetPath: 'assets/sounds/fart_proud.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p45', name: 'Wet One', emoji: '💦', assetPath: 'assets/sounds/fart_wet.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p46', name: 'Tiny Toot', emoji: '🐭', assetPath: 'assets/sounds/fart_tiny.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p47', name: 'Long Haul', emoji: '🚂', assetPath: 'assets/sounds/fart_long.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p48', name: 'Splat Fart', emoji: '🫠', assetPath: 'assets/sounds/fart_splat.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p49', name: 'Cartoon Toot', emoji: '💨', assetPath: 'assets/sounds/fart_cartoon.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p50', name: 'Power Fart', emoji: '💪', assetPath: 'assets/sounds/fart_power.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p51', name: 'Raspberry', emoji: '😛', assetPath: 'assets/sounds/fart_raspberry.mp3', isPremium: true, category: 'Farts'),
    SoundModel(id: 'p52', name: 'Little Burp', emoji: '🫧', assetPath: 'assets/sounds/burp_little.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p53', name: 'Big Burp', emoji: '🍺', assetPath: 'assets/sounds/burp_big.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p54', name: 'Echo Burp', emoji: '🗣️', assetPath: 'assets/sounds/burp_echo.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p55', name: 'Belch', emoji: '🍔', assetPath: 'assets/sounds/burp_belch.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p56', name: 'Soft Burp', emoji: '🫢', assetPath: 'assets/sounds/burp_soft.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p57', name: 'Achoo!', emoji: '🤧', assetPath: 'assets/sounds/sneeze_achoo.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p58', name: 'Big Sneeze', emoji: '🤧', assetPath: 'assets/sounds/sneeze_big.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p59', name: 'Sneeze Attack', emoji: '🤧', assetPath: 'assets/sounds/sneeze_attack.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p60', name: 'Quick Sneeze', emoji: '🤧', assetPath: 'assets/sounds/sneeze_quick.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p61', name: 'Blegh', emoji: '🤮', assetPath: 'assets/sounds/gross_blegh.mp3', isPremium: true, category: 'Gross'),
    SoundModel(id: 'p62', name: 'Silly Laugh', emoji: '😆', assetPath: 'assets/sounds/laugh_silly.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p63', name: 'Soft Chuckle', emoji: '🤭', assetPath: 'assets/sounds/laugh_soft.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p64', name: 'Sooo Funny', emoji: '🤣', assetPath: 'assets/sounds/laugh_sooo_funny.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p65', name: 'Girl Laugh', emoji: '😄', assetPath: 'assets/sounds/laugh_girl.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p66', name: 'Toon Laugh', emoji: '😹', assetPath: 'assets/sounds/laugh_toon.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p67', name: 'Crowd Laugh', emoji: '👏', assetPath: 'assets/sounds/laugh_crowd.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p68', name: 'Giggles', emoji: '😊', assetPath: 'assets/sounds/laugh_giggles.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p69', name: 'Critter Cackle', emoji: '👺', assetPath: 'assets/sounds/laugh_critter.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p70', name: 'Chuckle', emoji: '😏', assetPath: 'assets/sounds/laugh_chuckle.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p71', name: 'Kid Laugh', emoji: '🧒', assetPath: 'assets/sounds/laugh_kid.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p72', name: 'Guys Laughing', emoji: '😂', assetPath: 'assets/sounds/laugh_guys.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p73', name: 'Mischief', emoji: '😈', assetPath: 'assets/sounds/laugh_mischief.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p74', name: 'Jack-in-the-Box', emoji: '🎁', assetPath: 'assets/sounds/laugh_jack_box.mp3', isPremium: true, category: 'Laughs'),
    SoundModel(id: 'p75', name: 'Oh No (Whisper)', emoji: '🤫', assetPath: 'assets/sounds/voice_oh_no_whisper.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p76', name: 'Oh No!', emoji: '😱', assetPath: 'assets/sounds/voice_oh_no.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p77', name: 'I Love You', emoji: '❤️', assetPath: 'assets/sounds/voice_love_you.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p78', name: 'Eww', emoji: '🙄', assetPath: 'assets/sounds/voice_eww.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p79', name: 'Ewww!', emoji: '🤢', assetPath: 'assets/sounds/voice_ewww.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p80', name: 'Ayy Hey', emoji: '🙌', assetPath: 'assets/sounds/voice_ayy_hey.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p81', name: 'Ah, What?', emoji: '❓', assetPath: 'assets/sounds/voice_ah_what.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p82', name: 'Uuugh', emoji: '😤', assetPath: 'assets/sounds/voice_ugh.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p83', name: 'Ehh?', emoji: '🤔', assetPath: 'assets/sounds/voice_ehh.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p84', name: 'Yay!', emoji: '🥳', assetPath: 'assets/sounds/voice_yay.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p85', name: 'I Feel Good', emoji: '😎', assetPath: 'assets/sounds/voice_feel_good.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p86', name: 'Oh My God', emoji: '😲', assetPath: 'assets/sounds/voice_omg.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p87', name: 'That\'s Amazing!', emoji: '🤩', assetPath: 'assets/sounds/voice_amazing.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p88', name: 'That\'s Crazy', emoji: '🤯', assetPath: 'assets/sounds/voice_crazy.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p89', name: 'You Did It!', emoji: '🏆', assetPath: 'assets/sounds/voice_you_did_it.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p90', name: 'Really?', emoji: '🧐', assetPath: 'assets/sounds/voice_really.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p91', name: 'Whoopsie', emoji: '🙈', assetPath: 'assets/sounds/voice_whoopsie.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p92', name: 'Yeah Boy', emoji: '🤘', assetPath: 'assets/sounds/voice_yeah_boy.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p93', name: 'Excuse Me!', emoji: '🙋', assetPath: 'assets/sounds/voice_excuse_me.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p94', name: 'Wow', emoji: '😮', assetPath: 'assets/sounds/voice_wow.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p95', name: 'Lip Flutter', emoji: '👅', assetPath: 'assets/sounds/voice_lip_flutter.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p96', name: 'Cute Squeal', emoji: '🥰', assetPath: 'assets/sounds/voice_cute.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p97', name: 'Pop Wow', emoji: '🎉', assetPath: 'assets/sounds/voice_pop_wow.mp3', isPremium: true, category: 'Voices'),
    SoundModel(id: 'p98', name: 'Eaaaah!', emoji: '😫', assetPath: 'assets/sounds/scream_eaaah.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p99', name: 'Aaaah!', emoji: '😱', assetPath: 'assets/sounds/scream_aaah.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p100', name: 'Shriek', emoji: '😱', assetPath: 'assets/sounds/scream_shriek.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p101', name: 'High Scream', emoji: '🎤', assetPath: 'assets/sounds/scream_high.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p102', name: 'Tantrum', emoji: '😭', assetPath: 'assets/sounds/scream_tantrum.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p103', name: 'Eek!', emoji: '🙀', assetPath: 'assets/sounds/scream_eek.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p104', name: 'Gasp', emoji: '😨', assetPath: 'assets/sounds/scream_gasp.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p105', name: 'Attacked!', emoji: '🆘', assetPath: 'assets/sounds/scream_attacked.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p106', name: 'Yaaah!', emoji: '🥷', assetPath: 'assets/sounds/scream_yaaah.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p107', name: 'Man Scream', emoji: '🧔', assetPath: 'assets/sounds/scream_man.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p108', name: 'Ow!', emoji: '🤕', assetPath: 'assets/sounds/scream_ow.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p109', name: 'Baby Cry', emoji: '👶', assetPath: 'assets/sounds/scream_baby.mp3', isPremium: true, category: 'Screams'),
    SoundModel(id: 'p110', name: 'Baa', emoji: '🐑', assetPath: 'assets/sounds/animal_sheep.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p111', name: 'Cluck', emoji: '🐔', assetPath: 'assets/sounds/animal_chicken.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p112', name: 'Woof', emoji: '🐕', assetPath: 'assets/sounds/animal_dog.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p113', name: 'Yip', emoji: '🐶', assetPath: 'assets/sounds/animal_dog_yip.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p114', name: 'Neigh', emoji: '🐴', assetPath: 'assets/sounds/animal_horse.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p115', name: 'Cricket', emoji: '🦗', assetPath: 'assets/sounds/animal_cricket.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p116', name: 'Quack', emoji: '🦆', assetPath: 'assets/sounds/animal_duck.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p117', name: 'Meow', emoji: '🐱', assetPath: 'assets/sounds/animal_cat.mp3', isPremium: true, category: 'Animals'),
    SoundModel(id: 'p118', name: 'Boing Boing', emoji: '🦘', assetPath: 'assets/sounds/toon_boing_boing.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p119', name: 'Spring', emoji: '🌀', assetPath: 'assets/sounds/toon_spring.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p120', name: 'Mini Boing', emoji: '🏀', assetPath: 'assets/sounds/toon_boing_mini.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p122', name: 'Splash', emoji: '🌊', assetPath: 'assets/sounds/toon_splash.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p123', name: 'Smooch', emoji: '💋', assetPath: 'assets/sounds/toon_kiss.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p124', name: 'Slap', emoji: '👋', assetPath: 'assets/sounds/toon_slap.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p125', name: 'Big Slap', emoji: '🖐️', assetPath: 'assets/sounds/toon_slap_big.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p126', name: 'Squeaky Toy', emoji: '🧸', assetPath: 'assets/sounds/toon_squeak.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p127', name: 'Ting Ting Ting', emoji: '🔔', assetPath: 'assets/sounds/toon_ting.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p128', name: 'Silly Alarm', emoji: '⏰', assetPath: 'assets/sounds/toon_alarm.mp3', isPremium: true, category: 'Cartoon'),
    SoundModel(id: 'p129', name: 'Wrong Direction', emoji: '🚷', assetPath: 'assets/sounds/spooky_wrong_way.mp3', isPremium: true, category: 'Spooky'),
    SoundModel(id: 'p130', name: 'What Are You Doing?', emoji: '👧', assetPath: 'assets/sounds/spooky_what.mp3', isPremium: true, category: 'Spooky'),
    SoundModel(id: 'p131', name: 'I See You', emoji: '👻', assetPath: 'assets/sounds/spooky_see_you.mp3', isPremium: true, category: 'Spooky'),
    SoundModel(id: 'p132', name: 'Creepy Critter', emoji: '🕷️', assetPath: 'assets/sounds/spooky_critter.mp3', isPremium: true, category: 'Spooky'),
    SoundModel(id: 'p133', name: 'Evil Laugh', emoji: '😈', assetPath: 'assets/sounds/spooky_evil_laugh.mp3', isPremium: true, category: 'Spooky'),
    SoundModel(id: 'p134', name: 'Jump Scare', emoji: '🎃', assetPath: 'assets/sounds/spooky_jump_scare.mp3', isPremium: true, category: 'Spooky'),
    SoundModel(id: 'p135', name: 'Machine Gun', emoji: '🔫', assetPath: 'assets/sounds/action_machine_gun.mp3', isPremium: true, category: 'Action'),
    SoundModel(id: 'p136', name: 'Gunshots', emoji: '💥', assetPath: 'assets/sounds/action_gunshots.mp3', isPremium: true, category: 'Action'),
    SoundModel(id: 'p137', name: 'Glass Smash', emoji: '🪟', assetPath: 'assets/sounds/action_glass.mp3', isPremium: true, category: 'Action'),
    SoundModel(id: 'p138', name: 'Alert!', emoji: '🚨', assetPath: 'assets/sounds/game_alert.mp3', isPremium: true, category: 'Gaming'),
    SoundModel(id: 'p139', name: 'Arcade Jingle', emoji: '🕹️', assetPath: 'assets/sounds/game_arcade.mp3', isPremium: true, category: 'Gaming'),
    SoundModel(id: 'p140', name: 'Piano Intro', emoji: '🎹', assetPath: 'assets/sounds/music_piano.mp3', isPremium: true, category: 'Music'),
    SoundModel(id: 'p141', name: 'Bass Riff', emoji: '🎸', assetPath: 'assets/sounds/music_bass.mp3', isPremium: true, category: 'Music'),
    SoundModel(id: 'p142', name: 'Ba Dum Tss', emoji: '🥁', assetPath: 'assets/sounds/music_ba_dum_tss.mp3', isPremium: true, category: 'Music'),
    SoundModel(id: 'p143', name: 'Rimshot', emoji: '🥁', assetPath: 'assets/sounds/music_rimshot.mp3', isPremium: true, category: 'Music'),
    SoundModel(id: 'p144', name: 'Bicycle Bell', emoji: '🚲', assetPath: 'assets/sounds/bell_bicycle.mp3', isPremium: true, category: 'Classic'),
    // Custom recording (premium)
    SoundModel(id: 'custom', name: 'My Recording', emoji: '🎙️', assetPath: '', isPremium: true, category: 'Custom'),
  ];

  /// Display order for filter chips and grouped sections.
  static const List<String> categoryOrder = [
    'Classic', 'Funny', 'Memes', 'Voices', 'Laughs', 'Farts', 'Gross', 'Screams',
    'Animals', 'Cartoon', 'Spooky', 'Gaming', 'Action', 'Retro', 'Sci-Fi', 'Music', 'Chill', 'Custom',
  ];

  static List<String> get categories {
    final used = all.map((s) => s.category).toSet();
    return ['All', ...categoryOrder.where(used.contains), ...used.where((c) => !categoryOrder.contains(c))];
  }
}
