import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

void main() {
  Widget _buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('NakedAccordion Semantics', () {
    testWidgets('header uses visible text when semanticLabel is omitted', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedAccordionGroup<String>(
            controller: NakedAccordionController<String>(),
            child: NakedAccordion<String>(
              value: 'item',
              builder: (context, itemState) => const Text('Visible Header'),
              child: const Text('Body'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Visible Header')),
        matchesSemantics(
          label: 'Visible Header',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('semanticLabel overrides visible header text', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedAccordionGroup<String>(
            controller: NakedAccordionController<String>(),
            child: NakedAccordion<String>(
              value: 'item',
              semanticLabel: 'Semantic Header',
              builder: (context, itemState) => const Text('Visible Header'),
              child: const Text('Body'),
            ),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Visible Header')),
        matchesSemantics(
          label: 'Semantic Header',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('excludeSemantics hides visible header fallback', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedAccordionGroup<String>(
            controller: NakedAccordionController<String>(),
            child: NakedAccordion<String>(
              value: 'item',
              excludeSemantics: true,
              builder: (context, itemState) => const Text('Visible Header'),
              child: const Text('Body'),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Visible Header'), findsNothing);
      final root = tester.getSemantics(find.byType(Scaffold));
      final leakedTriggerNodes = collectSemanticsNodes(root, (node) {
        final data = node.getSemanticsData();
        return data.label.contains('Visible Header') ||
            data.flagsCollection.isButton ||
            data.flagsCollection.isExpanded != Tristate.none ||
            data.hasAction(SemanticsAction.tap);
      });
      expect(leakedTriggerNodes, isEmpty);

      handle.dispose();
    });

    testWidgets('collapsed header exposes explicit disclosure contract', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedAccordionGroup<String>(
            controller: NakedAccordionController<String>(),
            child: Column(
              children: [
                NakedAccordion<String>(
                  value: 'item',
                  semanticLabel: 'Header',
                  builder: (context, itemState) => const Text('Header'),
                  child: const Text('Body'),
                ),
              ],
            ),
          ),
        ),
      );
      // Use label to target the header semantics node.
      expect(
        tester.getSemantics(find.text('Header')),
        matchesSemantics(
          label: 'Header',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: false,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );

      handle.dispose();
    });

    testWidgets('expanded semantic properties vs ExpansionTile', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      // Test our NakedAccordion expanded state
      await tester.pumpWidget(
        _buildTestApp(
          NakedAccordionGroup<String>(
            controller: NakedAccordionController<String>(),
            initialExpandedValues: const ['item'],
            child: Column(
              children: [
                NakedAccordion<String>(
                  value: 'item',
                  semanticLabel: 'Header',
                  builder: (context, itemState) => const Text('Header'),
                  child: const Text('Body'),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify header has correct semantic properties
      final headerNode = tester.getSemantics(find.text('Header'));
      final headerData = headerNode.getSemanticsData();

      // Core semantic properties should match Material patterns
      expect(headerData.hasAction(SemanticsAction.tap), isTrue);
      expect(headerData.hasAction(SemanticsAction.focus), isTrue);
      expect(headerData.flagsCollection.isButton, isTrue);
      expect(headerData.flagsCollection.isExpanded, Tristate.isTrue);
      expect(headerData.flagsCollection.isFocused != Tristate.none, isTrue);
      expect(headerData.flagsCollection.isEnabled != Tristate.none, isTrue);
      expect(headerData.flagsCollection.isEnabled == Tristate.isTrue, isTrue);
      expect(
        headerData.label,
        'Header',
      ); // Our better approach: clean header label

      // Verify body content is accessible separately (better than Material's merged approach)
      final bodyFinder = find.text('Body');
      expect(bodyFinder, findsOneWidget);

      handle.dispose();
    });

    testWidgets('itemBuilder preserves disclosure semantics', (tester) async {
      final handle = tester.ensureSemantics();
      final controller = NakedAccordionController<String>();
      addTearDown(controller.dispose);
      var enabled = true;
      late StateSetter rebuild;

      await tester.pumpWidget(
        _buildTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedAccordionGroup<String>(
                controller: controller,
                initialExpandedValues: const ['item'],
                child: NakedAccordion<String>(
                  value: 'item',
                  enabled: enabled,
                  semanticLabel: 'Header',
                  builder: (_, _) => const Text('Header'),
                  itemBuilder: (_, _, child) =>
                      KeyedSubtree(key: const Key('item'), child: child!),
                  child: const Text('Body'),
                ),
              );
            },
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Header')),
        matchesSemantics(
          label: 'Header',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('item')),
          matching: find.text('Body'),
        ),
        findsOneWidget,
      );

      rebuild(() => enabled = false);
      await tester.pump();

      expect(
        tester.getSemantics(find.text('Header')),
        matchesSemantics(
          label: 'Header',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );

      handle.dispose();
    });
  });
}
