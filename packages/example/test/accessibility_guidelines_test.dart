import 'package:example/api/naked_button.0.dart' as button_example;
import 'package:example/api/naked_dialog.0.dart' as dialog_example;
import 'package:example/api/naked_toggle.0.dart' as toggle_example;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'helpers/accessibility_guideline_helpers.dart';

void main() {
  testWidgets('canonical styled alert dialog meets accessibility guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: dialog_example.AlertDialogExample()),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('alert-dialog.open')));
    await tester.pump();
    await tester.pump();

    await tester.expectMeetsAccessibilityGuidelines();
  });

  testWidgets('canonical toggle group meets accessibility guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(child: toggle_example.ToggleGroupExample()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.expectMeetsAccessibilityGuidelines();
  });

  testWidgets(
    'horizontal toggle group fits an Android-width surface at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(363.4, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: Center(child: toggle_example.ToggleGroupExample()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        MediaQuery.textScalerOf(
          tester.element(find.byKey(const Key('toggle-group.root'))),
        ).scale(10),
        20,
      );
    },
  );

  testWidgets('vertical toggle group fits a narrow surface at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: toggle_example.ToggleGroupExample(
                orientation: Axis.vertical,
                disableMiddleOption: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('toggle-group.root'))),
      ).scale(10),
      20,
    );
  });

  testWidgets('canonical styled button meets accessibility guidelines', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: button_example.ButtonExample())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.expectMeetsAccessibilityGuidelines();
  });

  testWidgets('label guideline fails for an unnamed interactive target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.square(
              dimension: 48,
              child: NakedButton(
                onPressed: () {},
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      () => tester.expectMeetsAccessibilityGuidelines(
        androidTapTarget: false,
        iOSTapTarget: false,
        textContrast: false,
      ),
      throwsA(isA<TestFailure>()),
    );
  });
}
