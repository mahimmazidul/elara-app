import 'package:elara_app/screens/root_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

/// The traveling indicator under the bottom navigation bar.
///
/// It was three tweens inside the widget, and the width was `to - from`, which
/// is negative whenever the destination tab is to the left of the current one.
/// Moving right worked and moving left threw "BoxConstraints has a negative
/// minimum width" mid-animation — a crash in a debug build and a bar of the
/// wrong size in a release one, on a gesture as ordinary as going back a tab.
void main() {
  const pageWidth = 390.0;
  const tabCount = 4;

  /// Every ordered pair of tabs, which is every way the reader can move.
  Iterable<(int, int)> transitions() sync* {
    for (var from = 0; from < tabCount; from++) {
      for (var to = 0; to < tabCount; to++) {
        yield (from, to);
      }
    }
  }

  test('the width is never negative, in either direction', () {
    for (final (from, to) in transitions()) {
      for (var step = 0; step <= 20; step++) {
        final t = step / 20;
        final geometry = NavFillGeometry.resolve(
          index: to,
          previousIndex: from,
          tabCount: tabCount,
          pageWidth: pageWidth,
          t: t,
        );
        expect(
          geometry.width,
          greaterThan(0),
          reason: 'from $from to $to at t=$t',
        );
        expect(
          geometry.width.isFinite,
          isTrue,
          reason: 'from $from to $to at t=$t',
        );
      }
    }
  });

  test('it rests exactly one tab wide, under the tab it marks', () {
    for (var index = 0; index < tabCount; index++) {
      final rest = NavFillGeometry.resolve(
        index: index,
        previousIndex: index,
        tabCount: tabCount,
        pageWidth: pageWidth,
        t: 1,
      );
      expect(rest.width, closeTo(pageWidth / tabCount, 0.001));
      expect(rest.left, closeTo(index * pageWidth / tabCount, 0.001));
    }
  });

  test('it swells in flight and settles again', () {
    final midpoint = NavFillGeometry.resolve(
      index: 2,
      previousIndex: 0,
      tabCount: tabCount,
      pageWidth: pageWidth,
      t: 0.5,
    );
    final start = NavFillGeometry.resolve(
      index: 2,
      previousIndex: 0,
      tabCount: tabCount,
      pageWidth: pageWidth,
      t: 0,
    );
    final end = NavFillGeometry.resolve(
      index: 2,
      previousIndex: 0,
      tabCount: tabCount,
      pageWidth: pageWidth,
      t: 1,
    );

    expect(midpoint.width, greaterThan(start.width));
    expect(midpoint.width, greaterThan(end.width));
    // And the swell is centred on the travel, not tacked onto one edge.
    expect(
      midpoint.left + midpoint.width / 2,
      closeTo((start.left + end.left) / 2 + (pageWidth / tabCount) / 2, 0.001),
    );
  });

  test('a backwards move lands where a forwards one started', () {
    final backwards = NavFillGeometry.resolve(
      index: 0,
      previousIndex: 3,
      tabCount: tabCount,
      pageWidth: pageWidth,
      t: 1,
    );
    expect(backwards.left, closeTo(0, 0.001));
    expect(backwards.width, closeTo(pageWidth / tabCount, 0.001));
  });
}
