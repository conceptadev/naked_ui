import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

final _destination = Uri.parse('https://example.com/docs');

void main() {
  group('NakedLink semantics', () {
    testWidgets('enabled Link exposes exact name role URL hint and action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final linkUrl = Uri.parse('https://example.com/docs');

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: linkUrl,
              semanticLabel: 'Documentation',
              semanticHint: 'Opens in a new window',
              onActivated: (_) {},
              child: const Text('Visible documentation'),
            ),
          ),
        );

        final data = _singleLinkData(tester);
        expect(data.label, 'Documentation');
        expect(data.hint, 'Opens in a new window');
        expect(data.linkUrl, linkUrl);
        expect(data.flagsCollection.isLink, isTrue);
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.flagsCollection.isEnabled, Tristate.isTrue);
        expect(data.flagsCollection.isFocused, Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('visible text supplies the name when no override is given', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              onActivated: (_) {},
              child: const Text('Visible name'),
            ),
          ),
        );

        expect(_singleLinkData(tester).label, 'Visible name');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('blank semantic label falls back to visible text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              semanticLabel: ' \t\n ',
              onActivated: (_) {},
              child: const Text('Visible name'),
            ),
          ),
        );

        expect(_singleLinkData(tester).label, 'Visible name');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('rich text supplies one complete Link name', (tester) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              onActivated: (_) {},
              child: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Read '),
                    TextSpan(text: 'docs'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(_singleLinkData(tester).label, 'Read docs');
      } finally {
        handle.dispose();
      }
    });

    testWidgets('semantic label replaces child naming without duplication', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              semanticLabel: 'Accessible documentation',
              onActivated: (_) {},
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Visible documentation'),
                  Semantics(
                    label: 'Decorative arrow',
                    image: true,
                    child: const SizedBox(width: 16, height: 16),
                  ),
                ],
              ),
            ),
          ),
        );

        final data = _singleLinkData(tester);
        expect(data.label, 'Accessible documentation');
        final allLabels = _allSemanticsData(tester)
            .map((value) => value.label)
            .where((label) => label.isNotEmpty)
            .toList();
        expect(
          allLabels.where((label) => label == 'Accessible documentation'),
          hasLength(1),
        );
        expect(allLabels, isNot(contains('Visible documentation')));
        expect(allLabels, isNot(contains('Decorative arrow')));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('caller can exclude a decorative external icon', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              semanticHint: 'Opens in a new window',
              onActivated: (_) {},
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('External documentation'),
                  ExcludeSemantics(
                    child: Icon(Icons.open_in_new, semanticLabel: 'External'),
                  ),
                ],
              ),
            ),
          ),
        );

        final data = _singleLinkData(tester);
        expect(data.label, 'External documentation');
        expect(data.hint, 'Opens in a new window');
        expect(
          _allSemanticsData(tester).where((value) => value.label == 'External'),
          isEmpty,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('focus flags follow the known focus node', (tester) async {
      final handle = tester.ensureSemantics();
      final focusNode = FocusNode(debugLabel: 'semantic link');
      addTearDown(focusNode.dispose);

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              focusNode: focusNode,
              linkUrl: _destination,
              onActivated: (_) {},
              child: const Text('Documentation'),
            ),
          ),
        );
        expect(
          _singleLinkData(tester).flagsCollection.isFocused,
          Tristate.isFalse,
        );

        focusNode.requestFocus();
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
        expect(
          _singleLinkData(tester).flagsCollection.isFocused,
          Tristate.isTrue,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('semantic tap uses the same activation path exactly once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final events = <String>[];

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              onActivated: (url) => events.add('observer:$url'),
              child: const Text('Documentation'),
            ),
            resolve: (_, url) {
              events.add('resolver:$url');
              return NakedLinkResolution.handled;
            },
          ),
        );

        final node = _singleLinkNode(tester);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        expect(events, ['observer:$_destination', 'resolver:$_destination']);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('semantic tap remains ordinary while a modifier is held', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final events = <String>[];

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              onActivated: (url) => events.add('observer:$url'),
              child: const Text('Documentation'),
            ),
            resolve: (_, url) {
              events.add('resolver:$url');
              return NakedLinkResolution.handled;
            },
          ),
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        final node = _singleLinkNode(tester);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();

        expect(events, ['observer:$_destination', 'resolver:$_destination']);
      } finally {
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        handle.dispose();
      }
    });

    testWidgets('a resolver does not alter the semantic contract', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLinkResolver(
              resolve: (_, _) => NakedLinkResolution.handled,
              child: NakedLink(
                linkUrl: Uri.parse('https://example.com/docs'),
                semanticLabel: 'Documentation',
                child: const Text('Visible documentation'),
              ),
            ),
          ),
        );

        final data = _singleLinkData(tester);
        expect(data.label, 'Documentation');
        expect(data.flagsCollection.isLink, isTrue);
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.flagsCollection.isEnabled, Tristate.isTrue);
        expect(data.flagsCollection.isFocused, Tristate.isFalse);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
      } finally {
        handle.dispose();
      }
    });

    testWidgets(
      'disabled destination exposes unavailable text without URL or action',
      (tester) async {
        final handle = tester.ensureSemantics();
        final linkUrl = Uri.parse('https://example.com/docs');
        var activations = 0;

        try {
          await tester.pumpWidget(
            _testApp(
              NakedLink(
                enabled: false,
                linkUrl: linkUrl,
                semanticLabel: 'Unavailable documentation',
                onActivated: (_) => activations++,
                child: const Text('Documentation'),
              ),
            ),
          );

          final data = tester
              .getSemantics(find.text('Documentation'))
              .getSemanticsData();
          expect(data.label, 'Unavailable documentation');
          expect(data.linkUrl, isNull);
          expect(data.flagsCollection.isLink, isFalse);
          expect(data.flagsCollection.isButton, isFalse);
          expect(data.flagsCollection.isEnabled, Tristate.isFalse);
          expect(data.hasAction(SemanticsAction.tap), isFalse);
          await tester.tap(find.text('Documentation'));
          await tester.pump();
          expect(activations, 0);
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets('Arabic label and hint remain exact in RTL', (tester) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            Directionality(
              textDirection: TextDirection.rtl,
              child: NakedLink(
                linkUrl: _destination,
                semanticLabel: 'الوثائق',
                semanticHint: 'يفتح في نافذة جديدة',
                onActivated: (_) {},
                child: const Text('المستندات'),
              ),
            ),
          ),
        );

        final data = _singleLinkData(tester);
        expect(data.label, 'الوثائق');
        expect(data.hint, 'يفتح في نافذة جديدة');
        expect(data.textDirection, TextDirection.rtl);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('excludeSemantics removes Link and descendant semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      try {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              semanticLabel: 'Documentation',
              onActivated: (_) {},
              child: const Text('Visible documentation'),
            ),
          ),
        );
        expect(_linkNodes(tester), hasLength(1));

        await tester.pumpWidget(
          _testApp(
            NakedLink(
              linkUrl: _destination,
              semanticLabel: 'Documentation',
              excludeSemantics: true,
              onActivated: (_) {},
              child: const Text('Visible documentation'),
            ),
          ),
        );

        expect(_linkNodes(tester), isEmpty);
        expect(
          _allSemanticsData(tester).where(
            (value) =>
                value.label == 'Documentation' ||
                value.label == 'Visible documentation',
          ),
          isEmpty,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}

Widget _testApp(Widget child, {NakedLinkResolveCallback? resolve}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: NakedLinkResolver(
          resolve: resolve ?? (_, _) => NakedLinkResolution.handled,
          child: child,
        ),
      ),
    ),
  );
}

SemanticsNode _singleLinkNode(WidgetTester tester) {
  final nodes = _linkNodes(tester);
  expect(nodes, hasLength(1));
  return nodes.single;
}

SemanticsData _singleLinkData(WidgetTester tester) =>
    _singleLinkNode(tester).getSemanticsData();

List<SemanticsNode> _linkNodes(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(Scaffold));
  final nodes = <SemanticsNode>[];

  void collect(SemanticsNode node) {
    if (node.getSemanticsData().flagsCollection.isLink) {
      nodes.add(node);
    }
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  collect(root);
  return nodes;
}

List<SemanticsData> _allSemanticsData(WidgetTester tester) {
  final root = tester.getSemantics(find.byType(Scaffold));
  final data = <SemanticsData>[];

  void collect(SemanticsNode node) {
    data.add(node.getSemanticsData());
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  collect(root);
  return data;
}
