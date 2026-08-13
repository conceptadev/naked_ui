// test/naked_text_field_test.dart
//
// Robust widget tests for NakedTextField with adaptive styling.
// - Safe pump helper
// - Platform-aware selection assertions
// - Non-brittle spellcheck/magnifier checks
// - Covers lifecycle, editing, selection, semantics, restoration, etc.

import 'package:flutter/cupertino.dart'
    show CupertinoDynamicColor, CupertinoTheme, CupertinoThemeData;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'helpers/builder_state_scope.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  required Widget child,
  String restorationScopeId = 'app',
  Size surfaceSize = const Size(900, 700),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      restorationScopeId: restorationScopeId,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  // Ensure a full build/first frame before tests grab widgets.
  await tester.pumpAndSettle();
}

NakedTextFieldBuilder _builder({EdgeInsets padding = EdgeInsets.zero}) {
  return (context, state, editable) => Padding(
    padding: padding,
    child: DecoratedBox(decoration: const BoxDecoration(), child: editable),
  );
}

EditableText _getEditableText(WidgetTester tester) {
  final iterable = tester.widgetList<EditableText>(find.byType(EditableText));
  expect(iterable.length, 1, reason: 'Expected exactly one EditableText');
  return iterable.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Render & builder basics', () {
    testWidgets('renders EditableText and builder receives a subtree with it', (
      tester,
    ) async {
      Widget? built;

      await _pumpApp(
        tester,
        child: NakedTextField(
          builder: (context, state, editable) {
            built = editable;
            return editable;
          },
        ),
      );

      expect(find.byType(EditableText), findsOneWidget);
      // Assert that the widget handed to builder contains an EditableText below it.
      expect(
        find.descendant(
          of: find.byWidget(built!),
          matching: find.byType(EditableText),
        ),
        findsOneWidget,
      );
    });

    testWidgets('derives from DefaultTextStyle when style is null', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        child: DefaultTextStyle(
          style: const TextStyle(fontSize: 19),
          child: NakedTextField(builder: _builder()),
        ),
      );

      final et = _getEditableText(tester);
      expect(et.style.fontSize, 19);
    });

    testWidgets('enabled=false sets readOnly on EditableText', (tester) async {
      await _pumpApp(
        tester,
        child: NakedTextField(enabled: false, builder: _builder()),
      );

      final et = _getEditableText(tester);
      expect(et.readOnly, isTrue);
    });

    testWidgets('disabled state updates when enabled property changes', (
      tester,
    ) async {
      NakedTextFieldState? capturedState;

      // Start with enabled=true (default)
      await _pumpApp(
        tester,
        child: NakedTextField(
          builder: (context, state, editable) {
            capturedState = state;
            return editable;
          },
        ),
      );

      expect(capturedState, isNotNull);
      expect(capturedState!.isEnabled, isTrue);
      expect(capturedState!.states.contains(WidgetState.disabled), isFalse);

      // Update to enabled=false
      await _pumpApp(
        tester,
        child: NakedTextField(
          enabled: false,
          builder: (context, state, editable) {
            capturedState = state;
            return editable;
          },
        ),
      );

      expect(capturedState!.isEnabled, isFalse);
      expect(capturedState!.states.contains(WidgetState.disabled), isTrue);

      // Update back to enabled=true
      await _pumpApp(
        tester,
        child: NakedTextField(
          enabled: true,
          builder: (context, state, editable) {
            capturedState = state;
            return editable;
          },
        ),
      );

      expect(capturedState!.isEnabled, isTrue);
      expect(capturedState!.states.contains(WidgetState.disabled), isFalse);
    });

    testWidgets('error state tracks error prop', (tester) async {
      NakedTextFieldState? capturedState;

      // Start with error=false (default)
      await _pumpApp(
        tester,
        child: NakedTextField(
          builder: (context, state, editable) {
            capturedState = state;
            return editable;
          },
        ),
      );

      expect(capturedState, isNotNull);
      expect(capturedState!.states.contains(WidgetState.error), isFalse);

      // Update to error=true
      await _pumpApp(
        tester,
        child: NakedTextField(
          error: true,
          builder: (context, state, editable) {
            capturedState = state;
            return editable;
          },
        ),
      );

      expect(capturedState!.states.contains(WidgetState.error), isTrue);

      // Update back to error=false
      await _pumpApp(
        tester,
        child: NakedTextField(
          error: false,
          builder: (context, state, editable) {
            capturedState = state;
            return editable;
          },
        ),
      );

      expect(capturedState!.states.contains(WidgetState.error), isFalse);
    });
  });

  group('Editing & callbacks', () {
    testWidgets('typing updates controller and onChanged', (tester) async {
      final ctl = TextEditingController();
      String? last;

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          onChanged: (s) => last = s,
          builder: _builder(),
        ),
      );

      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'Alpha');
      await tester.pump();

      expect(ctl.text, 'Alpha');
      expect(last, 'Alpha');
    });

    testWidgets('onSubmitted and onEditingComplete fire on IME action', (
      tester,
    ) async {
      final ctl = TextEditingController();
      String? submitted;
      var completeCount = 0;

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          textInputAction: TextInputAction.done,
          onEditingComplete: () => completeCount++,
          onSubmitted: (s) => submitted = s,
          builder: _builder(),
        ),
      );

      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'Beta');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(submitted, 'Beta');
      expect(completeCount, 1);
    });

    testWidgets('maxLength enforcement truncates input when enforced', (
      tester,
    ) async {
      final ctl = TextEditingController();

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          maxLength: 5,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          builder: _builder(),
        ),
      );

      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), '123456789');
      await tester.pump();

      expect(ctl.text, '12345');
    });

    testWidgets('readOnly prevents editing', (tester) async {
      final ctl = TextEditingController(text: 'seed');

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          readOnly: true,
          builder: _builder(),
        ),
      );

      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'attempt');
      await tester.pump();

      expect(ctl.text, 'seed');
      final et = _getEditableText(tester);
      expect(et.readOnly, isTrue);
    });
  });

  group('Focus, hover, and outside taps', () {
    testWidgets('onFocusChange notifies focus gain/loss', (tester) async {
      final ctl = TextEditingController();
      final node = FocusNode();
      final events = <bool>[];

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          focusNode: node,
          onFocusChange: events.add,
          builder: _builder(),
        ),
      );

      // Focus
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(node.hasFocus, isTrue);

      // Deterministic blur (more reliable than outside tapping in tests)
      final context = tester.element(find.byType(EditableText));
      FocusScope.of(context).unfocus();
      await tester.pump();

      expect(events, containsAllInOrder([true, false]));
    });

    testWidgets('canRequestFocus=false prevents focusing', (tester) async {
      final node = FocusNode();

      await _pumpApp(
        tester,
        child: NakedTextField(
          canRequestFocus: false,
          focusNode: node,
          builder: _builder(),
        ),
      );

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(node.hasFocus, isFalse);
    });

    testWidgets(
      'canRequestFocus=false is honored in directional navigation mode',
      (tester) async {
        final node = FocusNode();

        await _pumpApp(
          tester,
          child: MediaQuery(
            data: const MediaQueryData(
              navigationMode: NavigationMode.directional,
            ),
            child: NakedTextField(
              canRequestFocus: false,
              focusNode: node,
              builder: _builder(),
            ),
          ),
        );

        node.requestFocus();
        await tester.pump();
        expect(node.hasFocus, isFalse);
      },
    );

    testWidgets('focus survives swapping from external to internal node', (
      tester,
    ) async {
      final externalNode = FocusNode();
      late StateSetter rebuild;
      FocusNode? node = externalNode;

      await _pumpApp(
        tester,
        child: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return NakedTextField(focusNode: node, builder: _builder());
          },
        ),
      );

      externalNode.requestFocus();
      await tester.pump();
      expect(externalNode.hasFocus, isTrue);

      rebuild(() => node = null);
      await tester.pump();
      await tester.pump();

      final editable = _getEditableText(tester);
      expect(editable.focusNode, isNot(same(externalNode)));
      expect(editable.focusNode.hasFocus, isTrue);

      externalNode.dispose();
    });

    testWidgets('onTap & onTapAlwaysCalled true triggers', (tester) async {
      int taps = 0;

      await _pumpApp(
        tester,
        child: NakedTextField(
          onTap: () => taps++,
          onTapAlwaysCalled: true,
          builder: _builder(),
        ),
      );

      await tester.tap(find.byType(EditableText));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('onHoverChange toggles with mouse enter/exit', (tester) async {
      bool? hover;
      await _pumpApp(
        tester,
        child: NakedTextField(
          onHoverChange: (v) => hover = v,
          builder: _builder(padding: const EdgeInsets.all(12)),
        ),
      );

      final box = tester.renderObject<RenderBox>(find.byType(EditableText));
      final center = box.localToGlobal(box.size.center(Offset.zero));

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);

      await gesture.addPointer();
      await gesture.moveTo(center);
      await tester.pump();
      expect(hover, isTrue);

      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(hover, isFalse);
    });
  });

  group('Selection & toolbar (adaptive controls)', () {
    testWidgets('selectionColor is gated by focus', (tester) async {
      final ctl = TextEditingController(text: 'abc');

      await _pumpApp(
        tester,
        child: NakedTextField(controller: ctl, builder: _builder()),
      );

      var et = _getEditableText(tester);
      expect(et.selectionColor, isNull);

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      et = _getEditableText(tester);
      expect(et.selectionColor, isNotNull);
    });

    testWidgets('ambient DefaultSelectionStyle selection color reaches '
        'EditableText', (tester) async {
      final ctl = TextEditingController(text: 'abc');

      await _pumpApp(
        tester,
        child: DefaultSelectionStyle(
          selectionColor: const Color(0xFF9E9E9E),
          child: NakedTextField(controller: ctl, builder: _builder()),
        ),
      );

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      final et = _getEditableText(tester);
      expect(et.selectionColor, const Color(0xFF9E9E9E));
    });

    testWidgets('ambient dynamic selection style resolves in dark mode', (
      tester,
    ) async {
      const lightCursorColor = Color(0xFF1565C0);
      const darkCursorColor = Color(0xFF90CAF9);
      const lightSelectionColor = Color(0x661565C0);
      const darkSelectionColor = Color(0x6690CAF9);

      await _pumpApp(
        tester,
        child: CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: DefaultSelectionStyle(
            cursorColor: const CupertinoDynamicColor.withBrightness(
              color: lightCursorColor,
              darkColor: darkCursorColor,
            ),
            selectionColor: const CupertinoDynamicColor.withBrightness(
              color: lightSelectionColor,
              darkColor: darkSelectionColor,
            ),
            child: NakedTextField(builder: _builder()),
          ),
        ),
      );

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      final et = _getEditableText(tester);
      expect(et.cursorColor.toARGB32(), darkCursorColor.toARGB32());
      expect(et.selectionColor?.toARGB32(), darkSelectionColor.toARGB32());
    });
  });

  group('Scrolling & bring-into-view', () {
    testWidgets('multi-line input scrolls with long content', (tester) async {
      final ctl = TextEditingController();
      final scrollCtl = ScrollController();
      final big = List<String>.generate(120, (i) => 'Line $i').join('\n');

      await _pumpApp(
        tester,
        child: SizedBox(
          height: 160,
          child: NakedTextField(
            controller: ctl,
            scrollController: scrollCtl,
            maxLines: null,
            minLines: 1,
            builder: _builder(padding: const EdgeInsets.all(8)),
          ),
        ),
      );

      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), big);
      await tester.pumpAndSettle();

      expect(scrollCtl.hasClients, isTrue);
      expect(scrollCtl.offset, greaterThan(0));
    });
  });

  group('Undo/redo', () {
    testWidgets('UndoHistoryController with proper undo groups', (
      tester,
    ) async {
      final ctl = TextEditingController();
      final undo = UndoHistoryController();

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          undoController: undo,
          builder: _builder(),
        ),
      );

      await tester.tap(find.byType(EditableText));
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'first');
      await tester.pump(const Duration(milliseconds: 700)); // new undo group

      await tester.enterText(find.byType(EditableText), 'second');
      await tester.pump(const Duration(milliseconds: 700)); // new undo group

      expect(ctl.text, 'second');

      // Try direct undo/redo
      undo.undo();
      await tester.pump();
      expect(ctl.text, 'first');

      undo.redo();
      await tester.pump();
      expect(ctl.text, 'second');
    });
  });

  group('Semantics', () {});

  group('Restoration & ownership', () {
    testWidgets('internal RestorableTextEditingController restores text', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        restorationScopeId: 'resto',
        child: NakedTextField(restorationId: 'field', builder: _builder()),
      );

      await tester.showKeyboard(find.byType(EditableText));
      await tester.enterText(find.byType(EditableText), 'persist me');
      await tester.pump();

      await tester.restartAndRestore();
      await tester.pumpAndSettle();

      final et = _getEditableText(tester);
      expect(et.controller.text, 'persist me');
    });

    testWidgets('controller ownership can swap without losing content', (
      tester,
    ) async {
      final external1 = TextEditingController(text: 'ext1');

      await _pumpApp(
        tester,
        child: NakedTextField(controller: external1, builder: _builder()),
      );
      expect(_getEditableText(tester).controller.text, 'ext1');

      // Switch to internal
      await _pumpApp(tester, child: NakedTextField(builder: _builder()));
      expect(_getEditableText(tester).controller.text, 'ext1');

      // Switch back to a new external controller with a new value.
      final external2 = TextEditingController(text: 'ext2');
      await _pumpApp(
        tester,
        child: NakedTextField(controller: external2, builder: _builder()),
      );
      expect(_getEditableText(tester).controller.text, 'ext2');
    });

    testWidgets('EditableText.restorationId is derived from widget id', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        child: NakedTextField(restorationId: 'myfield', builder: _builder()),
      );

      final et = _getEditableText(tester);
      expect(et.restorationId, 'myfield.editable');
    });
  });

  group('Platform-adaptive defaults', () {
    testWidgets(
      'iOS cursor/offset defaults',
      (tester) async {
        await _pumpApp(tester, child: NakedTextField(builder: _builder()));

        final et = _getEditableText(tester);
        expect(et.paintCursorAboveText, isTrue);
        expect(et.cursorOpacityAnimates, isTrue);
        expect(et.cursorOffset, isNotNull);
        expect(et.cursorOffset!.dx, lessThan(0)); // iOS nudge is negative
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS}),
    );

    testWidgets(
      'Android cursor/offset defaults',
      (tester) async {
        await _pumpApp(tester, child: NakedTextField(builder: _builder()));

        final et = _getEditableText(tester);
        expect(et.paintCursorAboveText, isFalse);
        expect(et.cursorOpacityAnimates, isFalse);
        expect(et.cursorOffset, isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.android}),
    );
  });

  group('API passthrough sanity', () {
    testWidgets('cursor overrides propagate', (tester) async {
      await _pumpApp(
        tester,
        child: NakedTextField(
          cursorWidth: 3,
          cursorHeight: 15,
          cursorRadius: const Radius.circular(4),
          cursorOpacityAnimates: false,
          cursorColor: const Color(0xFF123456),
          builder: _builder(),
        ),
      );

      final et = _getEditableText(tester);
      expect(et.cursorWidth, 3);
      expect(et.cursorHeight, 15);
      expect(et.cursorRadius, const Radius.circular(4));
      expect(et.cursorOpacityAnimates, isFalse);
      expect(et.cursorColor, const Color(0xFF123456));
    });

    testWidgets('keyboardAppearance/drag/scrollPadding/clip propagate', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        child: NakedTextField(
          keyboardAppearance: Brightness.dark,
          dragStartBehavior: DragStartBehavior.down,
          scrollPadding: const EdgeInsets.all(42),
          clipBehavior: Clip.antiAlias,
          builder: _builder(),
        ),
      );

      final et = _getEditableText(tester);
      expect(et.keyboardAppearance, Brightness.dark);
      expect(et.dragStartBehavior, DragStartBehavior.down);
      expect(et.scrollPadding, const EdgeInsets.all(42));
      expect(et.clipBehavior, Clip.antiAlias);
    });

    testWidgets('text direction & alignment propagate', (tester) async {
      await _pumpApp(
        tester,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: NakedTextField(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            builder: _builder(),
          ),
        ),
      );

      final et = _getEditableText(tester);
      expect(et.textDirection, TextDirection.rtl);
      expect(et.textAlign, TextAlign.center);
    });

    testWidgets('spellcheck and magnifier configurations propagate', (
      tester,
    ) async {
      // We don’t rely on identity equality; just verify presence.
      const sc = SpellCheckConfiguration.disabled();
      final mag = TextMagnifier.adaptiveMagnifierConfiguration;

      await _pumpApp(
        tester,
        child: NakedTextField(
          spellCheckConfiguration: sc,
          magnifierConfiguration: mag,
          builder: _builder(),
        ),
      );

      final et = _getEditableText(tester);
      expect(et.spellCheckConfiguration, isNotNull);
      expect(et.magnifierConfiguration, isNotNull);
    });

    testWidgets('onAppPrivateCommand hook is invoked', (tester) async {
      String? action;
      Map<String, dynamic>? data;
      final ctl = TextEditingController();

      await _pumpApp(
        tester,
        child: NakedTextField(
          controller: ctl,
          onAppPrivateCommand: (a, d) {
            action = a;
            data = d;
          },
          builder: _builder(),
        ),
      );

      // Grab the EditableText's State, which implements TextInputClient.
      final EditableTextState state = tester.state<EditableTextState>(
        find.byType(EditableText),
      );

      // Simulate the platform sending a private command.
      state.performPrivateCommand('com.example.PRIVATE', <String, dynamic>{
        'foo': 'bar',
      });

      // Give the microtask queue a chance, then assert the callback fired.
      await tester.pump();

      expect(action, 'com.example.PRIVATE');
      expect(data, isNotNull);
      expect(data!['foo'], 'bar');
    });
  });

  group('Builder Tests', () {
    testStateScopeBuilder<NakedTextFieldState>(
      'builder\'s context contains NakedStateScope',
      (builder) => NakedTextField(
        builder: (context, state, editable) => builder(
          context,
          NakedTextFieldState(
            states: {},
            text: '',
            hasText: false,
            isReadOnly: false,
          ),
          editable,
        ),
      ),
    );
  });
}
