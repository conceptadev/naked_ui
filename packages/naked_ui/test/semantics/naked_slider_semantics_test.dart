import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

void main() {
  Widget testApp({
    required List<double> values,
    ValueChanged<List<double>>? onChanged,
    double min = 0,
    double max = 100,
    double step = 1,
    double minSpacing = 0,
    bool enabled = true,
    List<FocusNode?>? focusNodes,
    List<String?>? labels,
    List<NakedSliderSemanticFormatterCallback?>? formatters,
    bool excludeSemantics = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: NakedSlider(
            values: values,
            min: min,
            max: max,
            step: step,
            minSpacing: minSpacing,
            enabled: enabled,
            focusNodes: focusNodes,
            semanticLabels: labels,
            semanticFormatterCallbacks: formatters,
            excludeSemantics: excludeSemantics,
            onChanged: onChanged,
            child: const SizedBox(width: 240, height: 48),
          ),
        ),
      ),
    );
  }

  List<SemanticsNode> sliderNodes(WidgetTester tester) {
    final root = tester.getSemantics(find.byType(Scaffold));

    return collectSemanticsNodes(
      root,
      (node) => node.getSemanticsData().flagsCollection.isSlider,
    );
  }

  void performAction(
    WidgetTester tester,
    SemanticsNode node,
    ui.SemanticsAction action,
  ) {
    tester.binding.performSemanticsAction(
      ui.SemanticsActionEvent(
        type: action,
        viewId: tester.view.viewId,
        nodeId: node.id,
      ),
    );
  }

  group('NakedSlider semantics', () {
    testWidgets('exposes one independent slider node per thumb', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          values: const [20, 50, 80],
          labels: const ['Minimum', 'Target', 'Maximum'],
          onChanged: (_) {},
        ),
      );

      final nodes = sliderNodes(tester);
      expect(nodes, hasLength(3));
      expect(nodes.map(summarizeNode).map((summary) => summary.label), [
        'Minimum',
        'Target',
        'Maximum',
      ]);
      expect(nodes.map(summarizeNode).map((summary) => summary.value), [
        '20%',
        '50%',
        '80%',
      ]);
      for (final summary in nodes.map(summarizeNode)) {
        expect(summary.flags, containsAll(['isSlider', 'hasEnabledState']));
        expect(summary.flags, contains('isEnabled'));
        expect(summary.actions, containsAll(['focus', 'increase', 'decrease']));
      }
      handle.dispose();
    });

    testWidgets('each thumb uses its own semantic formatter', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          values: const [20, 80],
          step: 10,
          formatters: [
            (value) => 'From ${value.round()} dollars',
            (value) => 'To ${value.round()} dollars',
          ],
          onChanged: (_) {},
        ),
      );

      final summaries = sliderNodes(tester).map(summarizeNode).toList();
      expect(summaries[0].value, 'From 20 dollars');
      expect(summaries[0].increasedValue, 'From 30 dollars');
      expect(summaries[0].decreasedValue, 'From 10 dollars');
      expect(summaries[1].value, 'To 80 dollars');
      expect(summaries[1].increasedValue, 'To 90 dollars');
      expect(summaries[1].decreasedValue, 'To 70 dollars');
      handle.dispose();
    });

    testWidgets('disabled thumbs expose values without actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(values: const [25, 75], enabled: false, onChanged: (_) {}),
      );

      final summaries = sliderNodes(tester).map(summarizeNode).toList();
      expect(summaries, hasLength(2));
      for (final summary in summaries) {
        expect(summary.flags, containsAll(['isSlider', 'hasEnabledState']));
        expect(summary.flags, isNot(contains('isEnabled')));
        expect(summary.actions, isEmpty);
      }
      handle.dispose();
    });

    testWidgets('focus state belongs only to the focused thumb', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      await tester.pumpWidget(
        testApp(
          values: const [25, 75],
          focusNodes: [first, second],
          onChanged: (_) {},
        ),
      );

      second.requestFocus();
      await tester.pump();

      final summaries = sliderNodes(tester).map(summarizeNode).toList();
      expect(summaries[0].flags, isNot(contains('isFocused')));
      expect(summaries[1].flags, contains('isFocused'));
      handle.dispose();
    });

    testWidgets('boundary thumbs omit impossible semantic actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(values: const [0, 100], onChanged: (_) {}),
      );

      final summaries = sliderNodes(tester).map(summarizeNode).toList();
      expect(summaries[0].actions, isNot(contains('decrease')));
      expect(summaries[0].decreasedValue, isNull);
      expect(summaries[1].actions, isNot(contains('increase')));
      expect(summaries[1].increasedValue, isNull);
      handle.dispose();
    });

    testWidgets('minimum spacing suppresses blocked semantic actions', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(values: const [40, 50], minSpacing: 10, onChanged: (_) {}),
      );

      final summaries = sliderNodes(tester).map(summarizeNode).toList();
      expect(summaries[0].actions, isNot(contains('increase')));
      expect(summaries[1].actions, isNot(contains('decrease')));
      handle.dispose();
    });

    testWidgets('semantic action changes only its target thumb', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var values = <double>[20, 80];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => NakedSlider(
                values: values,
                step: 5,
                onChanged: (next) =>
                    setState(() => values = List<double>.of(next)),
                child: const SizedBox(width: 240, height: 48),
              ),
            ),
          ),
        ),
      );

      var nodes = sliderNodes(tester);
      performAction(tester, nodes[1], ui.SemanticsAction.decrease);
      await tester.pump();
      expect(values, [20, 75]);

      nodes = sliderNodes(tester);
      performAction(tester, nodes[0], ui.SemanticsAction.increase);
      await tester.pump();
      expect(values, [25, 75]);
      handle.dispose();
    });

    testWidgets('excludeSemantics hides every thumb node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          values: const [25, 75],
          excludeSemantics: true,
          onChanged: (_) {},
        ),
      );

      expect(sliderNodes(tester), isEmpty);
      handle.dispose();
    });
  });
}
