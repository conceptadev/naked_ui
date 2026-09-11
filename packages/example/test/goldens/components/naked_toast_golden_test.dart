import 'dart:io';

import 'package:example/api/naked_toast.0.dart' as toast_example;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden_test_harness.dart';

// Triggers sit at the top start so the bottom-end stack never covers them.
const _fixture = SizedBox.expand(
  child: Align(
    alignment: AlignmentDirectional.topStart,
    child: Padding(
      padding: EdgeInsets.all(24),
      child: toast_example.ToastExample(duration: Duration(minutes: 1)),
    ),
  ),
);

Future<void> _showStack(WidgetTester tester) async {
  for (final id in ['saved', 'archived', 'failed']) {
    await tester.tap(find.byKey(ValueKey('toast.show.$id')));
    await tester.pump();
  }
  await tester.pump();
}

Rect _surfaceRect(WidgetTester tester, String id) =>
    tester.getRect(find.byKey(ValueKey('toast.surface.$id')));

void main() {
  setUpAll(loadGoldenTestFont);

  testWidgets('canonical toast stack grows from the bottom-end inset', (
    tester,
  ) async {
    await pumpGoldenSurface(tester, child: _fixture);
    await _showStack(tester);

    final saved = _surfaceRect(tester, 'saved');
    final archived = _surfaceRect(tester, 'archived');
    final failed = _surfaceRect(tester, 'failed');

    // Newest nearest the edge, 24 from the surface corner, 12 between toasts.
    expect(failed.bottom, closeTo(goldenSurfaceSize.height - 24, 0.01));
    expect(failed.right, closeTo(goldenSurfaceSize.width - 24, 0.01));
    expect(failed.top - archived.bottom, closeTo(12, 0.01));
    expect(archived.top - saved.bottom, closeTo(12, 0.01));
  });

  testWidgets(
    'canonical toast stack matches its reference golden',
    (tester) async {
      const goldenKey = ValueKey('toast.golden.surface');
      await pumpGoldenSurface(tester, surfaceKey: goldenKey, child: _fixture);
      await _showStack(tester);

      await expectLater(
        find.byKey(goldenKey),
        matchesGoldenFile('baselines/naked_toast__stacked.png'),
      );
    },
    // Skia text rasterization is host-specific. CI pins this golden to Ubuntu
    // 24.04; macOS must not generate or approve the reference pixels.
    skip: !Platform.isLinux,
  );
}
