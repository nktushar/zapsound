import 'package:flutter_test/flutter_test.dart';

import 'package:zapsound/models/sound_model.dart';

void main() {
  group('ZapSoundLibrary', () {
    test('has free and premium sounds with unique ids', () {
      final ids = ZapSoundLibrary.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length);
      expect(ZapSoundLibrary.all.where((s) => !s.isPremium), isNotEmpty);
      expect(ZapSoundLibrary.all.where((s) => s.isPremium), isNotEmpty);
    });

    test('every sound except custom has an asset path', () {
      for (final s in ZapSoundLibrary.all) {
        if (s.id == 'custom') {
          expect(s.assetPath, isEmpty);
        } else {
          expect(s.assetPath, startsWith('assets/sounds/'));
          expect(s.assetPath, endsWith('.wav'));
        }
      }
    });

    test('categories start with All and cover every sound', () {
      final cats = ZapSoundLibrary.categories;
      expect(cats.first, 'All');
      for (final s in ZapSoundLibrary.all) {
        expect(cats, contains(s.category));
      }
    });
  });
}
