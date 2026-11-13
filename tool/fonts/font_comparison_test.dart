// Renders the same content in each candidate font family, so the choice is
// made on real Flutter renders rather than on a font sample.
//
// The output is a set of PNGs, one per family, each showing the same
// English and Bengali text at the sizes and weights the app uses. That is
// what the brief asks for: "compare real Flutter renders with identical
// content, not just font samples".
//
// Run it with
//
//   flutter test tool/fonts/font_comparison_test.dart
//
// which writes PNGs into tool/fonts/comparison/. It lives outside test/ so
// that a normal `flutter test` run never regenerates them.
//
// This is a comparison harness, not a test suite. It asserts nothing about
// the fonts; it produces evidence for a human decision.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The content every family is asked to render.
///
/// Identical for each family - that is the whole point. It includes the
/// characters that actually break: Bengali conjuncts, Latin punctuation,
/// numerals, and long words that have to wrap.
const String _headline = 'Your cycle, understood';
const String _body =
    'Elara estimates the next period from the dates you record. '
    'It is a calendar estimate, not a diagnosis, and it cannot confirm '
    'ovulation.';
const String _bangla = 'আপনার মাসিক চক্রের হিসাব। গর্ভাবস্থা নিশ্চিত করা যায় না।';
const String _numbers = 'Today 12 March  ·  28 days  ·  4 phases';

/// The sizes the app actually uses, with the weight it uses them at.
const List<(String, double, FontWeight)> _sizes = [
  ('display', 32, FontWeight.w700),
  ('title', 22, FontWeight.w700),
  ('body', 15, FontWeight.w400),
  ('label', 12, FontWeight.w500),
];

final GlobalKey _frameKey = GlobalKey();

/// Locates the SDK's icon font, which a headless render must be given because
/// there is no system font to fall back on.
String? _findMaterialIcons() {
  final fromEnvironment = Platform.environment['FLUTTER_ROOT'];
  final fromExecutable = Platform.resolvedExecutable.split('/bin/').first;
  for (final root in [fromEnvironment, fromExecutable]) {
    if (root == null) continue;
    final candidate =
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    loader.addFont(File(path).readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await loader.load();
}

/// A candidate family: its identifier, the family name, and the assets that
/// back it.
typedef Candidate = ({
  String id,
  String family,
  List<String> fallbacks,
  Map<String, List<String>> assets,
});

const List<Candidate> _candidates = [
  (
    id: 'hind-siliguri',
    family: 'Hind Siliguri',
    fallbacks: <String>[],
    assets: {
      'Hind Siliguri': [
        'assets/fonts/HindSiliguri-Regular.ttf',
        'assets/fonts/HindSiliguri-Medium.ttf',
        'assets/fonts/HindSiliguri-SemiBold.ttf',
        'assets/fonts/HindSiliguri-Bold.ttf',
      ],
    },
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final candidate in _candidates) {
      for (final entry in candidate.assets.entries) {
        if (!File(entry.key).existsSync() &&
            entry.value.every((p) => !File(p).existsSync())) {
          continue;
        }
        await _loadFont(entry.key, entry.value);
      }
    }
    final icons = _findMaterialIcons();
    if (icons != null) {
      await _loadFont('MaterialIcons', [icons]);
    }
  });

  for (final candidate in _candidates) {
    testWidgets('render ${candidate.id}', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: _frameKey,
            child: Scaffold(
              backgroundColor: const Color(0xFFFAFAF8),
              body: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (label, size, weight) in _sizes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$label  $size  w${weight.value}',
                              style: TextStyle(
                                fontFamily: candidate.family,
                                fontFamilyFallback: candidate.fallbacks,
                                fontSize: 10,
                                color: const Color(0xFF9A8F8F),
                              ),
                            ),
                            Text(
                              _headline,
                              style: TextStyle(
                                fontFamily: candidate.family,
                                fontFamilyFallback: candidate.fallbacks,
                                fontSize: size,
                                fontWeight: weight,
                                height: 1.25,
                                color: const Color(0xFF3D2C2E),
                              ),
                            ),
                            Text(
                              _body,
                              style: TextStyle(
                                fontFamily: candidate.family,
                                fontFamilyFallback: candidate.fallbacks,
                                fontSize: size,
                                height: 1.5,
                                color: const Color(0xFF5A4A4C),
                              ),
                            ),
                            Text(
                              _bangla,
                              style: TextStyle(
                                fontFamily: candidate.family,
                                fontFamilyFallback: candidate.fallbacks,
                                fontSize: size,
                                height: 1.6,
                                color: const Color(0xFF3D2C2E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _numbers,
                              style: TextStyle(
                                fontFamily: candidate.family,
                                fontFamilyFallback: candidate.fallbacks,
                                fontSize: size,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF7A6A6C),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final boundary = tester.firstRenderObject<RenderRepaintBoundary>(
        find.byKey(_frameKey),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1.0);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('tool/fonts/comparison/${candidate.id}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        // ignore: avoid_print
        print('wrote ${file.path} (${(await file.length()) ~/ 1024} KB)');
      });
    });
  }
}
