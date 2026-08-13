import 'dart:io';

import 'package:example/api/naked_dialog.0.dart' as dialog_example;
import 'package:example/api/naked_toggle.0.dart' as toggle_example;
import 'package:example/src/testing/screenshot_evidence.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'helpers/screenshot_test_helpers.dart';
import 'helpers/test_helpers.dart';

const _alertOpenKey = ValueKey('alert-dialog.open');
const _alertTitleKey = ValueKey('alert-dialog.title');
const _alertMessageFocusKey = ValueKey('alert-dialog.message-focus');
const _alertCancelKey = ValueKey('alert-dialog.cancel');
const _alertConfirmKey = ValueKey('alert-dialog.confirm');

void _configureScreenshotView(WidgetTester tester) {
  if (Platform.isAndroid || Platform.isIOS) return;
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _alertScreenshotApp({
  bool longMessage = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Center(
        child: dialog_example.AlertDialogExample(longMessage: longMessage),
      ),
    ),
  );
}

Widget _toggleGroupScreenshotApp({
  Axis orientation = Axis.horizontal,
  TextDirection textDirection = TextDirection.ltr,
  bool disableMiddleOption = false,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Center(
        child: SingleChildScrollView(
          child: toggle_example.ToggleGroupExample(
            orientation: orientation,
            textDirection: textDirection,
            disableMiddleOption: disableMiddleOption,
          ),
        ),
      ),
    ),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultTestTimeout = const Timeout(Duration(minutes: 2));

  testWidgets('dialog open screenshot evidence', (tester) async {
    const screenshotSurfaceKey = ValueKey('dialog.screenshot.surface');
    final usesNativeSurface = Platform.isAndroid || Platform.isIOS;
    if (!usesNativeSurface) {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    await tester.pumpWidget(
      const RepaintBoundary(
        key: screenshotSurfaceKey,
        child: dialog_example.MyApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Basic Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Action'), findsOneWidget);
    final screenshotSurface = find.byKey(screenshotSurfaceKey);
    final logicalSize = tester.getSize(screenshotSurface);
    if (!usesNativeSurface) {
      expect(logicalSize, const Size(800, 600));
    }
    await tester.captureEvidenceScreenshot(
      binding,
      ScreenshotEvidence(
        component: 'dialog',
        scenario: 'open',
        surface: '${logicalSize.width}x${logicalSize.height} logical pixels',
        devicePixelRatio: tester.view.devicePixelRatio,
        animationMode: 'fixed 400ms transition, settled',
      ),
      surface: screenshotSurface,
    );
  });

  testWidgets('alert dialog safe focus screenshot evidence', (tester) async {
    const screenshotSurfaceKey = ValueKey('alert-dialog.screenshot.safe-focus');
    _configureScreenshotView(tester);
    await tester.pumpWidget(
      RepaintBoundary(key: screenshotSurfaceKey, child: _alertScreenshotApp()),
    );
    await tester.pump();

    await tester.tap(find.byKey(_alertOpenKey));
    await tester.pumpUntil(
      () => find.byKey(_alertTitleKey).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 2),
    );
    final cancelButton = tester.widget<NakedButton>(
      find.descendant(
        of: find.byKey(_alertCancelKey),
        matching: find.byType(NakedButton),
      ),
    );
    await tester.pumpUntil(
      () => FocusManager.instance.primaryFocus == cancelButton.focusNode,
      timeout: const Duration(seconds: 2),
    );
    expect(FocusManager.instance.primaryFocus, same(cancelButton.focusNode));

    final screenshotSurface = find.byKey(screenshotSurfaceKey);
    final logicalSize = tester.getSize(screenshotSurface);
    await tester.captureEvidenceScreenshot(
      binding,
      ScreenshotEvidence(
        component: 'alert_dialog',
        scenario: 'open_safe_focus',
        surface: '${logicalSize.width}x${logicalSize.height} logical pixels',
        devicePixelRatio: tester.view.devicePixelRatio,
        animationMode: 'disabled, zero-duration route transition',
      ),
      surface: screenshotSurface,
    );
  });

  testWidgets('alert dialog destructive action screenshot evidence', (
    tester,
  ) async {
    const screenshotSurfaceKey = ValueKey(
      'alert-dialog.screenshot.destructive-action',
    );
    _configureScreenshotView(tester);
    await tester.pumpWidget(
      RepaintBoundary(key: screenshotSurfaceKey, child: _alertScreenshotApp()),
    );
    await tester.pump();

    await tester.tap(find.byKey(_alertOpenKey));
    await tester.pumpUntil(
      () => find.byKey(_alertConfirmKey).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 2),
    );
    await tester.tap(find.byKey(_alertConfirmKey));
    await tester.pumpUntil(
      () =>
          find.text('Result: confirm; confirmations: 1').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 2),
    );
    expect(find.byKey(_alertTitleKey), findsNothing);

    final screenshotSurface = find.byKey(screenshotSurfaceKey);
    final logicalSize = tester.getSize(screenshotSurface);
    await tester.captureEvidenceScreenshot(
      binding,
      ScreenshotEvidence(
        component: 'alert_dialog',
        scenario: 'destructive_action',
        surface: '${logicalSize.width}x${logicalSize.height} logical pixels',
        devicePixelRatio: tester.view.devicePixelRatio,
        animationMode: 'disabled, action completed',
      ),
      surface: screenshotSurface,
    );
  });

  testWidgets('alert dialog long message screenshot evidence', (tester) async {
    const screenshotSurfaceKey = ValueKey(
      'alert-dialog.screenshot.long-message',
    );
    _configureScreenshotView(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotSurfaceKey,
        child: _alertScreenshotApp(
          longMessage: true,
          textScaler: const TextScaler.linear(2),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(_alertOpenKey));
    await tester.pumpUntil(
      () => find.byKey(_alertMessageFocusKey).evaluate().isNotEmpty,
      timeout: const Duration(seconds: 2),
    );
    final messageFocus = tester.widget<Focus>(
      find.byKey(_alertMessageFocusKey),
    );
    await tester.pumpUntil(
      () => FocusManager.instance.primaryFocus == messageFocus.focusNode,
      timeout: const Duration(seconds: 2),
    );
    expect(FocusManager.instance.primaryFocus, same(messageFocus.focusNode));
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(_alertTitleKey)),
      ).scale(10),
      20,
    );

    final screenshotSurface = find.byKey(screenshotSurfaceKey);
    final logicalSize = tester.getSize(screenshotSurface);
    await tester.captureEvidenceScreenshot(
      binding,
      ScreenshotEvidence(
        component: 'alert_dialog',
        scenario: 'long_message_200_text',
        surface: '${logicalSize.width}x${logicalSize.height} logical pixels',
        devicePixelRatio: tester.view.devicePixelRatio,
        textScale: 2,
        animationMode: 'disabled, zero-duration route transition',
      ),
      surface: screenshotSurface,
    );
  });

  testWidgets('toggle group roving RTL screenshot evidence', (tester) async {
    const screenshotSurfaceKey = ValueKey('toggle-group.screenshot.roving-rtl');
    _configureScreenshotView(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotSurfaceKey,
        child: _toggleGroupScreenshotApp(textDirection: TextDirection.rtl),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Directionality.of(
        tester.element(find.textContaining('This group deliberately')),
      ),
      TextDirection.ltr,
    );
    expect(
      Directionality.of(
        tester.element(find.byKey(const Key('toggle-group.root'))),
      ),
      TextDirection.rtl,
    );
    expect(
      tester.getCenter(find.byKey(const Key('toggle-group.option.bold'))).dx,
      greaterThan(
        tester
            .getCenter(find.byKey(const Key('toggle-group.option.italic')))
            .dx,
      ),
    );

    final boldOption = tester.widget<NakedToggleOption<String>>(
      find.byKey(const Key('toggle-group.option.bold')),
    );
    final italicOption = tester.widget<NakedToggleOption<String>>(
      find.byKey(const Key('toggle-group.option.italic')),
    );
    boldOption.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(italicOption.focusNode!.hasPrimaryFocus, isTrue);
    expect(find.text('Selected: Bold'), findsOneWidget);
    if (!Platform.isMacOS) return;

    final screenshotSurface = find.byKey(screenshotSurfaceKey);
    final logicalSize = tester.getSize(screenshotSurface);
    await tester.captureEvidenceScreenshot(
      binding,
      ScreenshotEvidence(
        component: 'toggle_group',
        scenario: 'roving_rtl',
        surface: '${logicalSize.width}x${logicalSize.height} logical pixels',
        devicePixelRatio: tester.view.devicePixelRatio,
        direction: 'RTL',
        animationMode: '120ms focus transition, settled',
      ),
      surface: screenshotSurface,
    );
  });

  testWidgets('toggle group vertical disabled screenshot evidence', (
    tester,
  ) async {
    const screenshotSurfaceKey = ValueKey(
      'toggle-group.screenshot.vertical-disabled',
    );
    _configureScreenshotView(tester);
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotSurfaceKey,
        child: _toggleGroupScreenshotApp(
          orientation: Axis.vertical,
          disableMiddleOption: true,
          textScaler: const TextScaler.linear(2),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boldOption = tester.widget<NakedToggleOption<String>>(
      find.byKey(const Key('toggle-group.option.bold')),
    );
    final italicOption = tester.widget<NakedToggleOption<String>>(
      find.byKey(const Key('toggle-group.option.italic')),
    );
    final underlineOption = tester.widget<NakedToggleOption<String>>(
      find.byKey(const Key('toggle-group.option.underline')),
    );
    boldOption.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(italicOption.focusNode!.canRequestFocus, isFalse);
    expect(underlineOption.focusNode!.hasPrimaryFocus, isTrue);
    expect(find.text('Selected: Bold'), findsOneWidget);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byKey(const Key('toggle-group.root'))),
      ).scale(10),
      20,
    );
    if (!Platform.isAndroid) return;

    final screenshotSurface = find.byKey(screenshotSurfaceKey);
    final logicalSize = tester.getSize(screenshotSurface);
    await tester.captureEvidenceScreenshot(
      binding,
      ScreenshotEvidence(
        component: 'toggle_group',
        scenario: 'vertical_disabled',
        surface: '${logicalSize.width}x${logicalSize.height} logical pixels',
        devicePixelRatio: tester.view.devicePixelRatio,
        textScale: 2,
        animationMode: '120ms focus transition, settled',
      ),
      surface: screenshotSurface,
    );
  });
}
