import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

int _accessibleLabelCount(WidgetTester tester, String label) => tester.semantics
    .simulatedAccessibilityTraversal()
    .where((node) => node.getSemanticsData().label == label)
    .length;

String _controlledIdentifier(SemanticsNode trigger) {
  final controlsNodes = trigger.getSemanticsData().controlsNodes;
  expect(controlsNodes, hasLength(1));
  return controlsNodes!.single;
}

SemanticsNode _nodeWithIdentifier(SemanticsNode root, String identifier) {
  final matches = collectSemanticsNodes(
    root,
    (node) => node.getSemanticsData().identifier == identifier,
    includeMerged: true,
  );
  expect(
    matches,
    hasLength(1),
    reason: 'Expected exactly one semantics node with identifier $identifier.',
  );
  return matches.single;
}

bool _subtreeContainsLabel(SemanticsNode root, String label) {
  final matchingNode = findSemanticsNode(
    root,
    (node) => node.getSemanticsData().label.contains(label),
  );
  return matchingNode != null;
}

void main() {
  Widget buildApp(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('NakedDisclosure semantics', () {
    testWidgets(
      'keeps native semantics identity stable across panel remounts',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildApp(
            const NakedDisclosure(
              defaultExpanded: true,
              child: Text('Trigger'),
              panel: Text('Panel'),
            ),
          ),
        );

        final expandedTrigger = tester.getSemantics(find.text('Trigger'));
        final initialTriggerId = expandedTrigger.id;
        final initialPanelIdentifier = _controlledIdentifier(expandedTrigger);
        final initialPanel = _nodeWithIdentifier(
          tester.getSemantics(find.byType(Scaffold)),
          initialPanelIdentifier,
        );
        expect(initialPanelIdentifier, isNotEmpty);
        expect(initialPanel.id, isNot(expandedTrigger.id));
        expect(_subtreeContainsLabel(initialPanel, 'Panel'), isTrue);

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        expect(
          tester
              .getSemantics(find.text('Trigger'))
              .getSemanticsData()
              .controlsNodes,
          isNull,
        );
        expect(find.text('Panel'), findsNothing);

        await tester.tap(find.text('Trigger'));
        await tester.pump();

        final reopenedTrigger = tester.getSemantics(find.text('Trigger'));
        final reopenedPanelIdentifier = _controlledIdentifier(reopenedTrigger);
        final reopenedPanel = _nodeWithIdentifier(
          tester.getSemantics(find.byType(Scaffold)),
          reopenedPanelIdentifier,
        );
        expect(reopenedTrigger.id, initialTriggerId);
        expect(reopenedPanelIdentifier, initialPanelIdentifier);
        expect(reopenedPanel.id, isNot(reopenedTrigger.id));
        expect(_subtreeContainsLabel(reopenedPanel, 'Panel'), isTrue);

        await tester.tap(find.text('Trigger'));
        await tester.pump();
        await tester.tap(find.text('Trigger'));
        await tester.pump();

        final secondReopenedTrigger = tester.getSemantics(find.text('Trigger'));
        final secondReopenedIdentifier = _controlledIdentifier(
          secondReopenedTrigger,
        );
        final secondReopenedPanel = _nodeWithIdentifier(
          tester.getSemantics(find.byType(Scaffold)),
          secondReopenedIdentifier,
        );
        expect(secondReopenedTrigger.id, initialTriggerId);
        expect(secondReopenedIdentifier, initialPanelIdentifier);
        expect(secondReopenedPanel.id, isNot(secondReopenedTrigger.id));
        expect(_subtreeContainsLabel(secondReopenedPanel, 'Panel'), isTrue);
        handle.dispose();
      },
      skip: kIsWeb,
    );

    testWidgets(
      'keeps controlled native semantics identity stable after a remount',
      (tester) async {
        final handle = tester.ensureSemantics();
        var expanded = true;
        late StateSetter rebuild;
        await tester.pumpWidget(
          buildApp(
            StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return NakedDisclosure(
                  expanded: expanded,
                  onExpandedChanged: (_) {},
                  child: const Text('Controlled trigger'),
                  panel: const Text('Controlled panel'),
                );
              },
            ),
          ),
        );

        final initialTrigger = tester.getSemantics(
          find.text('Controlled trigger'),
        );
        final initialTriggerId = initialTrigger.id;
        final initialIdentifier = _controlledIdentifier(initialTrigger);

        rebuild(() => expanded = false);
        await tester.pump();
        expect(
          tester
              .getSemantics(find.text('Controlled trigger'))
              .getSemanticsData()
              .controlsNodes,
          isNull,
        );

        rebuild(() => expanded = true);
        await tester.pump();
        final reopenedTrigger = tester.getSemantics(
          find.text('Controlled trigger'),
        );
        final reopenedIdentifier = _controlledIdentifier(reopenedTrigger);

        expect(reopenedTrigger.id, initialTriggerId);
        expect(reopenedIdentifier, initialIdentifier);
        final reopenedPanel = _nodeWithIdentifier(
          tester.getSemantics(find.byType(Scaffold)),
          reopenedIdentifier,
        );
        expect(
          _subtreeContainsLabel(reopenedPanel, 'Controlled panel'),
          isTrue,
        );
        handle.dispose();
      },
      skip: kIsWeb,
    );

    testWidgets('uses unique panel identifiers for multiple disclosures', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildApp(
          const Column(
            children: [
              NakedDisclosure(
                defaultExpanded: true,
                child: Text('First trigger'),
                panel: Text('First panel'),
              ),
              NakedDisclosure(
                defaultExpanded: true,
                child: Text('Second trigger'),
                panel: Text('Second panel'),
              ),
            ],
          ),
        ),
      );

      final firstTrigger = tester.getSemantics(find.text('First trigger'));
      final secondTrigger = tester.getSemantics(find.text('Second trigger'));
      final firstPanelIdentifier = _controlledIdentifier(firstTrigger);
      final secondPanelIdentifier = _controlledIdentifier(secondTrigger);
      final root = tester.getSemantics(find.byType(Scaffold));
      final firstPanel = _nodeWithIdentifier(root, firstPanelIdentifier);
      final secondPanel = _nodeWithIdentifier(root, secondPanelIdentifier);
      expect(firstPanelIdentifier, isNotEmpty);
      expect(secondPanelIdentifier, isNotEmpty);
      expect(firstPanelIdentifier, isNot(secondPanelIdentifier));
      expect(firstPanel.id, isNot(firstTrigger.id));
      expect(secondPanel.id, isNot(secondTrigger.id));
      expect(_subtreeContainsLabel(firstPanel, 'First panel'), isTrue);
      expect(_subtreeContainsLabel(secondPanel, 'Second panel'), isTrue);
      handle.dispose();
    });

    testWidgets('controls a distinct panel beneath a semantics container', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildApp(
          Semantics(
            container: true,
            label: 'Outer container',
            child: const NakedDisclosure(
              defaultExpanded: true,
              child: Text('Nested trigger'),
              panel: Text('Nested panel'),
            ),
          ),
        ),
      );

      final trigger = tester.getSemantics(find.text('Nested trigger'));
      final panel = _nodeWithIdentifier(
        tester.getSemantics(find.byType(Scaffold)),
        _controlledIdentifier(trigger),
      );

      expect(panel.id, isNot(trigger.id));
      expect(_subtreeContainsLabel(panel, 'Nested panel'), isTrue);
      expect(_subtreeContainsLabel(panel, 'Nested trigger'), isFalse);
      handle.dispose();
    });

    testWidgets('preserves consumer semantics within the controlled panel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildApp(
          NakedDisclosure(
            defaultExpanded: true,
            child: const Text('Trigger'),
            panel: Column(
              children: [
                Semantics(
                  identifier: 'consumer-panel-id',
                  child: const Text('Consumer panel'),
                ),
                TextButton(onPressed: () {}, child: const Text('Panel action')),
              ],
            ),
          ),
        ),
      );

      final trigger = tester.getSemantics(find.text('Trigger'));
      final relationshipIdentifier = _controlledIdentifier(trigger);
      final root = tester.getSemantics(find.byType(Scaffold));
      final relationshipTarget = _nodeWithIdentifier(
        root,
        relationshipIdentifier,
      );
      final consumerNode = _nodeWithIdentifier(root, 'consumer-panel-id');

      expect(relationshipIdentifier, isNot('consumer-panel-id'));
      expect(relationshipTarget.id, isNot(trigger.id));
      expect(consumerNode.id, isNot(relationshipTarget.id));
      expect(
        _subtreeContainsLabel(relationshipTarget, 'Consumer panel'),
        isTrue,
      );
      expect(
        tester
            .getSemantics(find.text('Panel action'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      handle.dispose();
    });

    testWidgets('exposes one named button with enabled and expanded flags', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildApp(
          const NakedDisclosure(
            defaultExpanded: true,
            child: Text('Details'),
            panel: Text('Panel content'),
          ),
        ),
      );

      expect(
        tester.getSemantics(find.text('Details')),
        matchesSemantics(
          label: 'Details',
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
      final root = tester.getSemantics(find.byType(Scaffold));
      expect(
        countSemanticsNodes(
          root,
          (node) => node.getSemanticsData().flagsCollection.isButton,
        ),
        1,
      );
      handle.dispose();
      expect(
        countSemanticsNodes(
          root,
          (node) => node.getSemanticsData().hasAction(SemanticsAction.tap),
        ),
        1,
      );
    });

    testWidgets('uses visible label for empty or whitespace labels', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final semanticLabel in ['', '   ']) {
        await tester.pumpWidget(
          buildApp(
            NakedDisclosure(
              semanticLabel: semanticLabel,
              child: const Text('Visible label'),
              panel: const Text('Panel'),
            ),
          ),
        );

        expect(
          tester.getSemantics(find.text('Visible label')),
          matchesSemantics(
            label: 'Visible label',
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
      }
      handle.dispose();
    });

    testWidgets(
      'explicit label and hint replace descendants without duplication',
      (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          buildApp(
            const NakedDisclosure(
              semanticLabel: 'Accessible details',
              semanticHint: 'Shows technical information',
              child: Text('Visible details'),
              panel: Text('Panel'),
            ),
          ),
        );

        final node = tester.getSemantics(find.text('Visible details'));
        final data = node.getSemanticsData();
        expect(data.label, 'Accessible details');
        expect(data.hint, 'Shows technical information');
        expect(data.label, isNot(contains('Visible details')));
        final root = tester.getSemantics(find.byType(Scaffold));
        expect(
          countSemanticsNodes(
            root,
            (candidate) => candidate.getSemanticsData().label.contains(
              'Accessible details',
            ),
          ),
          1,
        );
        handle.dispose();
      },
    );

    testWidgets('read-only controlled trigger is disabled with no tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildApp(
          const NakedDisclosure(
            expanded: true,
            child: Text('Read only'),
            panel: Text('Available panel'),
          ),
        ),
      );

      final data = tester
          .getSemantics(find.text('Read only'))
          .getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isEnabled, Tristate.isFalse);
      expect(data.flagsCollection.isExpanded, Tristate.isTrue);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(find.bySemanticsLabel('Available panel'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('expanded panel is exposed and closing panel is excluded', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        buildApp(
          NakedDisclosure(
            defaultExpanded: true,
            child: const Text('Trigger'),
            panel: const Text('Panel semantics'),
            transitionBuilder: (context, animation, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
        ),
      );
      expect(_accessibleLabelCount(tester, 'Panel semantics'), 1);

      await tester.tap(find.text('Trigger'));
      await tester.pump();
      expect(find.text('Panel semantics'), findsOneWidget);
      expect(_accessibleLabelCount(tester, 'Panel semantics'), 0);
      await tester.pumpAndSettle();
      expect(find.text('Panel semantics'), findsNothing);
      handle.dispose();
    });

    testWidgets('excludeSemantics updates without remounting or leaking', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var excludeSemantics = false;
      late StateSetter rebuild;
      await tester.pumpWidget(
        buildApp(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return NakedDisclosure(
                excludeSemantics: excludeSemantics,
                defaultExpanded: true,
                child: const Text('Toggleable trigger'),
                panel: const Text('Toggleable panel'),
              );
            },
          ),
        ),
      );

      expect(_accessibleLabelCount(tester, 'Toggleable trigger'), 1);
      expect(_accessibleLabelCount(tester, 'Toggleable panel'), 1);

      rebuild(() => excludeSemantics = true);
      await tester.pump();

      expect(_accessibleLabelCount(tester, 'Toggleable trigger'), 0);
      expect(_accessibleLabelCount(tester, 'Toggleable panel'), 0);
      final leaked = tester.semantics.simulatedAccessibilityTraversal().where((
        node,
      ) {
        final data = node.getSemanticsData();
        return data.flagsCollection.isButton ||
            data.flagsCollection.isExpanded != Tristate.none ||
            data.hasAction(SemanticsAction.tap);
      }).toList();
      expect(leaked, isEmpty);

      rebuild(() => excludeSemantics = false);
      await tester.pump();
      expect(_accessibleLabelCount(tester, 'Toggleable trigger'), 1);
      expect(_accessibleLabelCount(tester, 'Toggleable panel'), 1);
      handle.dispose();
    });
  });
}
