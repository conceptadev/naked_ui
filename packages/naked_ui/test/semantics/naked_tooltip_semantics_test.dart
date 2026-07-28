import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

List<SemanticsNode> _nodesWithLabel(WidgetTester tester, String label) {
  return tester.semantics
      .simulatedAccessibilityTraversal()
      .where((node) => node.getSemanticsData().label == label)
      .toList();
}

void main() {
  Widget _buildTestApp(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  Widget _buildNakedTooltip({required String message, required String child}) {
    return NakedTooltip(
      semanticLabel: message,
      overlayBuilder: (context, animation) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(message, style: const TextStyle(color: Colors.white)),
      ),
      child: Text(child),
    );
  }

  group('NakedTooltip Semantics', () {
    testWidgets('basic tooltip semantics structure', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          _buildNakedTooltip(message: 'Tooltip message', child: 'Trigger text'),
        ),
      );

      expect(find.text('Trigger text'), findsOneWidget);

      final triggerNode = tester.getSemantics(find.text('Trigger text'));
      expect(triggerNode, isNotNull);

      handle.dispose();
    });

    testWidgets('tooltip with button-like trigger semantics', (tester) async {
      final handle = tester.ensureSemantics();

      Widget buildMaterialButtonWithTooltip() {
        return _buildTestApp(
          const Tooltip(
            message: 'Button tooltip',
            child: ElevatedButton(onPressed: null, child: Text('Button')),
          ),
        );
      }

      Widget buildNakedButtonWithTooltip() {
        return _buildTestApp(
          NakedTooltip(
            semanticLabel: 'Button tooltip',
            overlayBuilder: (context, animation) => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Button tooltip',
                style: TextStyle(color: Colors.white),
              ),
            ),
            child: const NakedButton(onPressed: null, child: Text('Button')),
          ),
        );
      }

      await expectSemanticsParity(
        tester: tester,
        material: buildMaterialButtonWithTooltip(),
        naked: buildNakedButtonWithTooltip(),
        control: ControlType.button,
      );

      handle.dispose();
    });

    testWidgets('keeps one unchanged trigger node through hover lifecycle', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      const label = 'Filter chats';

      try {
        await tester.pumpWidget(
          _buildTestApp(
            NakedTooltip(
              semanticLabel: label,
              hoverDelay: Duration.zero,
              dismissDelay: Duration.zero,
              animationStyle: AnimationStyle.noAnimation,
              overlayBuilder: (context, animation) => const Text(label),
              child: NakedButton(
                key: const Key('naked-trigger'),
                semanticLabel: label,
                onPressed: () {},
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ),
        );
        final closedTrigger = summarizeMergedFromRoot(
          tester,
          control: ControlType.button,
        );
        final labelCounts = <int>[_nodesWithLabel(tester, label).length];
        final triggerStates = <SemanticsSummary>[closedTrigger];

        await mouse.moveTo(
          tester.getCenter(find.byKey(const Key('naked-trigger'))),
        );
        await tester.pumpAndSettle();

        final openNodes = _nodesWithLabel(tester, label);
        labelCounts.add(openNodes.length);
        final data = openNodes.single.getSemanticsData();
        expect(data.tooltip, label);
        expect(data.flagsCollection.isButton, isTrue);
        expect(data.flagsCollection.isEnabled, Tristate.isTrue);
        expect(data.flagsCollection.isFocused, isNot(Tristate.none));
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        triggerStates.add(
          summarizeMergedFromRoot(tester, control: ControlType.button),
        );

        await mouse.moveTo(const Offset(-1000, -1000));
        await tester.pumpAndSettle();
        labelCounts.add(_nodesWithLabel(tester, label).length);
        triggerStates.add(
          summarizeMergedFromRoot(tester, control: ControlType.button),
        );

        expect(labelCounts, [1, 1, 1]);
        expect(triggerStates, everyElement(closedTrigger));
      } finally {
        await mouse.removePointer();
        handle.dispose();
      }
    });

    testWidgets('can include meaningful custom overlay semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _buildTestApp(
            NakedTooltip(
              open: true,
              semanticLabel: 'Show connection help',
              excludeOverlaySemantics: false,
              animationStyle: AnimationStyle.noAnimation,
              overlayBuilder: (context, animation) => Semantics(
                label: 'Connection status',
                child: const ExcludeSemantics(child: Text('Connected')),
              ),
              child: NakedButton(
                key: const Key('custom-overlay-trigger'),
                semanticLabel: 'Show status',
                onPressed: () {},
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final trigger = _nodesWithLabel(tester, 'Show status').single;
        final overlay = _nodesWithLabel(tester, 'Connection status').single;

        expect(trigger.getSemanticsData().tooltip, 'Show connection help');
        expect(
          trigger.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(overlay.getSemanticsData().label, 'Connection status');
        expect(find.text('Connected'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    for (final (description, semanticLabel) in <(String, String?)>[
      ('omitted', null),
      ('blank', '   '),
    ]) {
      testWidgets(
        'keeps overlay semantics when the trigger tooltip label is $description',
        (tester) async {
          final handle = tester.ensureSemantics();

          try {
            await tester.pumpWidget(
              _buildTestApp(
                NakedTooltip(
                  open: true,
                  semanticLabel: semanticLabel,
                  animationStyle: AnimationStyle.noAnimation,
                  overlayBuilder: (context, animation) =>
                      const Text('Connection status'),
                  child: NakedButton(
                    semanticLabel: 'Show status',
                    onPressed: () {},
                    child: const SizedBox.square(dimension: 40),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final trigger = _nodesWithLabel(tester, 'Show status').single;
            expect(trigger.getSemanticsData().tooltip.trim(), isEmpty);
            expect(_nodesWithLabel(tester, 'Connection status'), hasLength(1));
          } finally {
            handle.dispose();
          }
        },
      );
    }

    testWidgets('can explicitly exclude an unlabeled overlay', (tester) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _buildTestApp(
            NakedTooltip(
              open: true,
              excludeOverlaySemantics: true,
              animationStyle: AnimationStyle.noAnimation,
              overlayBuilder: (context, animation) =>
                  const Text('Connection status'),
              child: NakedButton(
                semanticLabel: 'Show status',
                onPressed: () {},
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_nodesWithLabel(tester, 'Show status'), hasLength(1));
        expect(_nodesWithLabel(tester, 'Connection status'), isEmpty);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('excludeSemantics overrides explicit overlay inclusion', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _buildTestApp(
            NakedTooltip(
              open: true,
              semanticLabel: 'Show connection help',
              excludeSemantics: true,
              excludeOverlaySemantics: false,
              useRootOverlay: true,
              animationStyle: AnimationStyle.noAnimation,
              overlayBuilder: (context, animation) =>
                  const Text('Connection status'),
              child: NakedButton(
                semanticLabel: 'Show status',
                onPressed: () {},
                child: const SizedBox.square(dimension: 40),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(_nodesWithLabel(tester, 'Show status'), isEmpty);
        expect(_nodesWithLabel(tester, 'Connection status'), isEmpty);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('semantics label accessibility', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          _buildNakedTooltip(
            message: 'This is a helpful tooltip',
            child: 'Help',
          ),
        ),
      );

      final data = tester.getSemantics(find.text('Help')).getSemanticsData();
      expect(data.label, 'Help');
      expect(data.tooltip, 'This is a helpful tooltip');

      handle.dispose();
    });

    testWidgets('tooltip without semantics label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedTooltip(
            overlayBuilder: (context, animation) =>
                const Text('Tooltip content'),
            child: const Text('No label'),
          ),
        ),
      );

      expect(find.text('No label'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('No label')),
        matchesSemantics(label: 'No label'),
      );
      expect(
        tester.getSemantics(find.text('No label')).getSemanticsData().tooltip,
        isEmpty,
      );

      handle.dispose();
    });
  });
}
