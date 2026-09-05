import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles every generated Flutter runtime asset', () async {
    const manifestPath = 'assets/flutter_asset_manifest.json';
    final manifest = jsonDecode(
      await rootBundle.loadString(manifestPath),
    ) as Map<String, Object?>;
    final files = manifest['files'] as List<Object?>;
    final assetPaths = files.map(_assetPath).toList();

    expect(assetPaths, isNotEmpty);
    expect(
      assetPaths,
      containsAll(<String>[
        'audio/background-music.wav',
        'audio/engine/engine_mid_loop.wav',
        'attribution/SOURCES.md',
        'sprites/cars/red-stripe.png',
        'tracks/track_01.png',
        'tracks/track_01.tmx',
        'tracks/track_02.png',
        'tracks/track_02.tmx',
      ]),
    );
    for (final path in assetPaths) {
      expect(
        (await rootBundle.load('assets/$path')).lengthInBytes,
        greaterThan(0),
      );
    }
  });
}

String _assetPath(Object? value) =>
    (value as Map<String, Object?>)['path']! as String;
