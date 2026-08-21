import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:naked_ui/naked_ui.dart';
import 'package:web/web.dart' as web;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('disclosure controls each remounted web semantics panel', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NakedDisclosure(
              autofocus: true,
              defaultExpanded: true,
              semanticLabel: 'Disclosure trigger',
              panel: Text('Panel'),
              child: Text('Trigger'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panelIds = <String>{};
    final panelIdentifiers = <String>{};

    void expectExpandedRelationship() {
      final trigger = web.document.querySelector(
        '[role="button"][aria-expanded]',
      );
      expect(trigger, isNotNull);
      expect(trigger!.getAttribute('aria-expanded'), 'true');

      final controls = trigger.getAttribute('aria-controls');
      expect(controls, isNotNull);
      final panel = web.document.getElementById(controls!);
      expect(panel, isNotNull);
      expect(
        panel!.getAttribute('flt-semantics-identifier'),
        startsWith('naked-disclosure-panel-'),
      );
      expect(panel.textContent, contains('Panel'));
      panelIds.add(panel.id);
      panelIdentifiers.add(panel.getAttribute('flt-semantics-identifier')!);
    }

    void expectCollapsedRelationship() {
      final trigger = web.document.querySelector(
        '[role="button"][aria-expanded]',
      );
      expect(trigger, isNotNull);
      expect(trigger!.getAttribute('aria-expanded'), 'false');
      expect(trigger.getAttribute('aria-controls'), isNull);
      expect(
        web.document.querySelector(
          '[flt-semantics-identifier^="naked-disclosure-panel-"]',
        ),
        isNull,
      );
    }

    expectExpandedRelationship();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expectCollapsedRelationship();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expectExpandedRelationship();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expectCollapsedRelationship();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expectExpandedRelationship();

    expect(panelIds, hasLength(3));
    expect(panelIdentifiers, hasLength(3));
    semantics.dispose();
  });
}
