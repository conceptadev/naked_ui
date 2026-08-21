import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

int _accessibleLabelCount(WidgetTester tester, String label) => tester.semantics
    .simulatedAccessibilityTraversal()
    .where((node) => node.getSemanticsData().label == label)
    .length;

void main() {
  Widget buildApp(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('NakedDisclosure semantics', () {
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
