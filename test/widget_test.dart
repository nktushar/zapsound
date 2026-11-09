import 'dart:io';

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
          expect(s.assetPath, matches(RegExp(r'\.(wav|mp3)$')));
        }
      }
    });

    test('every asset exists and has a native res/raw twin', () {
      final names = <String>{};
      for (final s in ZapSoundLibrary.all.where((s) => s.id != 'custom')) {
        expect(File(s.assetPath).existsSync(), isTrue, reason: s.assetPath);
        // Android raw resource names: lowercase letters, digits, underscore.
        expect(s.fileName, matches(RegExp(r'^[a-z][a-z0-9_]*$')), reason: s.fileName);
        expect(names.add(s.fileName), isTrue, reason: 'duplicate ${s.fileName}');
        final ext = s.assetPath.split('.').last;
        expect(File('android/app/src/main/res/raw/${s.fileName}.$ext').existsSync(), isTrue,
            reason: 'missing res/raw/${s.fileName}.$ext');
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
