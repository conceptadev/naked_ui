import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
// Material exports widgets; no separate widgets import needed.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

class _FakeRegistry<T> extends RadioGroupRegistry<T> {
  _FakeRegistry(this._groupValue);
  final T? _groupValue;
  @override
  T? get groupValue => _groupValue;
  @override
  ValueChanged<T?> get onChanged => (_) {};
  @override
  void registerClient(RadioClient<T> radio) {}
  @override
  void unregisterClient(RadioClient<T> radio) {}
}

SemanticsNode _findRadioNode(WidgetTester tester) {
  final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
  SemanticsNode? found;
  bool dfs(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.flagsCollection.isInMutuallyExclusiveGroup) {
      found = n;
      return true;
    }
    n.visitChildren(dfs);
    return true;
  }

  root.visitChildren(dfs);
  if (found == null) throw StateError('No radio node found');
  return found!;
}

void main() {
  Widget _buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('NakedRadio Semantics', () {
    testWidgets('parity with Material Radio - selected', (tester) async {
      final handle = tester.ensureSemantics();

      final reg = _FakeRegistry<String>('a');
      await expectSemanticsParity(
        tester: tester,
        material: _buildTestApp(Radio<String>(value: 'a', groupRegistry: reg)),
        naked: _buildTestApp(
          NakedRadio<String>(
            value: 'a',
            groupRegistry: reg,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
        control: ControlType.radio,
      );
      handle.dispose();
    });

    testWidgets('parity with Material Radio - unselected', (tester) async {
      final handle = tester.ensureSemantics();
      final reg = _FakeRegistry<String>('b');
      await expectSemanticsParity(
        tester: tester,
        material: _buildTestApp(Radio<String>(value: 'a', groupRegistry: reg)),
        naked: _buildTestApp(
          NakedRadio<String>(
            value: 'a',
            groupRegistry: reg,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
        control: ControlType.radio,
      );
      handle.dispose();
    });

    testWidgets('focus parity', (tester) async {
      final handle = tester.ensureSemantics();
      final fm = FocusNode();
      final fn = FocusNode();

      final reg = _FakeRegistry<String>('a');
      await tester.pumpWidget(
        _buildTestApp(
          Radio<String>(value: 'a', focusNode: fm, groupRegistry: reg),
        ),
      );
      fm.requestFocus();
      await tester.pump();
      final materialFocused = summarizeMergedFromRoot(
        tester,
        control: ControlType.radio,
      );

      await tester.pumpWidget(
        _buildTestApp(
          NakedRadio<String>(
            value: 'a',
            groupRegistry: reg,
            focusNode: fn,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );
      fn.requestFocus();
      await tester.pump();
      final nakedFocused = summarizeMergedFromRoot(
        tester,
        control: ControlType.radio,
      );

      expect(nakedFocused, equals(materialFocused));

      fm.dispose();
      fn.dispose();
      handle.dispose();
    });

    testWidgets('hover parity', (tester) async {
      final handle = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await tester.pump();

      final reg = _FakeRegistry<String>('a');
      await tester.pumpWidget(
        _buildTestApp(Radio<String>(value: 'a', groupRegistry: reg)),
      );
      await mouse.moveTo(tester.getCenter(find.byType(Radio<String>)));
      await tester.pump();
      final materialHovered = summarizeMergedFromRoot(
        tester,
        control: ControlType.radio,
      );

      await tester.pumpWidget(
        _buildTestApp(
          NakedRadio<String>(
            value: 'a',
            groupRegistry: reg,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byType(NakedRadio<String>)));
      await tester.pump();
      final nakedHovered = summarizeMergedFromRoot(
        tester,
        control: ControlType.radio,
      );

      expect(nakedHovered, equals(materialHovered));
      await mouse.removePointer();
      handle.dispose();
    });

    testWidgets('disabled strict parity', (tester) async {
      final handle = tester.ensureSemantics();

      final reg = _FakeRegistry<String>('a');
      await tester.pumpWidget(
        _buildTestApp(
          Radio<String>(value: 'a', enabled: false, groupRegistry: reg),
        ),
      );
      final mNode = tester.getSemantics(find.byType(Radio<String>));
      final strict = buildStrictMatcherFromSemanticsData(
        mNode.getSemanticsData(),
      );

      final reg2 = _FakeRegistry<String>('a');
      await tester.pumpWidget(
        _buildTestApp(
          NakedRadio<String>(
            value: 'a',
            groupRegistry: reg2,
            enabled: false,
            child: const SizedBox(width: 20, height: 20),
          ),
        ),
      );
      expect(_findRadioNode(tester), strict);

      handle.dispose();
    });

    testWidgets(
      'semanticLabel overrides visible child label and preserves radio semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        final reg = _FakeRegistry<String>('a');

        await tester.pumpWidget(
          _buildTestApp(
            NakedRadio<String>(
              value: 'a',
              groupRegistry: reg,
              semanticLabel: 'Option A',
              child: const Text('Visible A'),
            ),
          ),
        );

        final node = _findRadioNode(tester);
        expect(
          node,
          matchesSemantics(
            label: 'Option A',
            hasCheckedState: true,
            isChecked: true,
            hasEnabledState: true,
            isEnabled: true,
            isFocusable: true,
            isInMutuallyExclusiveGroup: true,
            hasTapAction: true,
            hasFocusAction: true,
          ),
        );
        expect(node.getSemanticsData().label, isNot(contains('Visible A')));

        handle.dispose();
      },
    );

    testWidgets('visible child labels radio when semanticLabel is omitted', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final reg = _FakeRegistry<String>('a');

      await tester.pumpWidget(
        _buildTestApp(
          NakedRadio<String>(
            value: 'a',
            groupRegistry: reg,
            child: const Text('Visible A'),
          ),
        ),
      );

      expect(_findRadioNode(tester).getSemanticsData().label, 'Visible A');

      handle.dispose();
    });
  });

  group('NakedRadioGroup', () {
    Widget buildGroup({
      required String? groupValue,
      ValueChanged<String?>? onChanged,
      bool enabled = true,
      String? semanticLabel,
    }) {
      return _buildTestApp(
        NakedRadioGroup<String>(
          groupValue: groupValue,
          onChanged: onChanged,
          enabled: enabled,
          semanticLabel: semanticLabel,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NakedRadio<String>(
                value: 'a',
                child: SizedBox.square(dimension: 20),
              ),
              NakedRadio<String>(
                value: 'b',
                child: SizedBox.square(dimension: 20),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('tap selects through the group onChanged', (tester) async {
      String? selected = 'a';
      await tester.pumpWidget(
        buildGroup(groupValue: selected, onChanged: (v) => selected = v),
      );

      await tester.tap(find.byType(NakedRadio<String>).last);
      await tester.pump();

      expect(selected, 'b');
    });

    testWidgets('null onChanged disables the whole group', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildGroup(groupValue: 'a', onChanged: null));

      await tester.tap(
        find.byType(NakedRadio<String>).last,
        warnIfMissed: false,
      );
      await tester.pump();

      final radios = collectSemanticsNodes(
        tester.getSemantics(find.byType(Scaffold)),
        (n) => n.getSemanticsData().flagsCollection.isInMutuallyExclusiveGroup,
      );
      expect(radios, hasLength(2));
      for (final node in radios) {
        expect(
          node.getSemanticsData().flagsCollection.isEnabled,
          Tristate.isFalse,
        );
      }

      handle.dispose();
    });

    testWidgets('enabled: false disables radios that are enabled themselves', (
      tester,
    ) async {
      String? selected = 'a';
      await tester.pumpWidget(
        buildGroup(
          groupValue: selected,
          onChanged: (v) => selected = v,
          enabled: false,
        ),
      );

      await tester.tap(
        find.byType(NakedRadio<String>).last,
        warnIfMissed: false,
      );
      await tester.pump();

      expect(selected, 'a');
    });

    testWidgets('semanticLabel labels the group without a second role node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildGroup(
          groupValue: 'a',
          onChanged: (_) {},
          semanticLabel: 'Shipping speed',
        ),
      );

      final root = tester.getSemantics(find.byType(Scaffold));
      // Flutter's RadioGroup publishes the single radioGroup role node.
      // The label must not add a second one.
      final roleNodes = collectSemanticsNodes(
        root,
        (n) => n.getSemanticsData().role == SemanticsRole.radioGroup,
      );
      expect(roleNodes, hasLength(1));

      final labeled = collectSemanticsNodes(
        root,
        (n) => n.getSemanticsData().label == 'Shipping speed',
      );
      expect(labeled, hasLength(1));

      handle.dispose();
    });

    testWidgets('without semanticLabel only Flutter\'s role node exists', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildGroup(groupValue: 'a', onChanged: (_) {}));

      final groups = collectSemanticsNodes(
        tester.getSemantics(find.byType(Scaffold)),
        (n) => n.getSemanticsData().role == SemanticsRole.radioGroup,
      );
      expect(groups, hasLength(1));
      expect(groups.single.getSemanticsData().label, isEmpty);

      handle.dispose();
    });

    testWidgets('nested groups of different types keep enabled state aligned', (
      tester,
    ) async {
      int? selectedInner = 1;
      await tester.pumpWidget(
        _buildTestApp(
          NakedRadioGroup<String>(
            groupValue: 'a',
            onChanged: null, // outer group disabled
            child: NakedRadioGroup<int>(
              groupValue: selectedInner,
              onChanged: (v) => selectedInner = v,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NakedRadio<int>(
                    value: 1,
                    child: SizedBox.square(dimension: 20),
                  ),
                  NakedRadio<int>(
                    value: 2,
                    child: SizedBox.square(dimension: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // The int radios belong to the enabled inner group; the disabled
      // outer String group must not leak its state onto them.
      await tester.tap(find.byType(NakedRadio<int>).last);
      await tester.pump();

      expect(selectedInner, 2);
    });
  });
}
