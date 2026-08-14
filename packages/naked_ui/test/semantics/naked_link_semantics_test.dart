import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

void main() {
  group('NakedLink semantics', () {
    testWidgets('enabled Link exposes its exact role, name, URL, and action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final linkUrl = Uri.parse('https://example.com/docs');

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            linkUrl: linkUrl,
            semanticLabel: 'Documentation',
            semanticHint: 'Opens in a new window',
            onPressed: () {},
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
      handle.dispose();
    });

    testWidgets('visible text names the Link for null or blank overrides', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      for (final semanticLabel in <String?>[null, '   ']) {
        await tester.pumpWidget(
          _testApp(
            NakedLink(
              semanticLabel: semanticLabel,
              onPressed: () {},
              child: const Text('Visible name'),
            ),
          ),
        );

        expect(_singleLinkData(tester).label, 'Visible name');
      }
      handle.dispose();
    });

    testWidgets('semantic label replaces all descendant naming', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            semanticLabel: 'Accessible documentation',
            onPressed: () {},
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

      final labels = _allSemanticsData(
        tester,
      ).map((data) => data.label).where((label) => label.isNotEmpty).toList();
      expect(_singleLinkData(tester).label, 'Accessible documentation');
      expect(
        labels.where((label) => label == 'Accessible documentation'),
        hasLength(1),
      );
      expect(labels, isNot(contains('Visible documentation')));
      expect(labels, isNot(contains('Decorative arrow')));
      handle.dispose();
    });

    testWidgets('focus state follows the supplied focus node', (tester) async {
      final handle = tester.ensureSemantics();
      final focusNode = FocusNode(debugLabel: 'semantic link');
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            focusNode: focusNode,
            onPressed: () {},
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
      expect(
        _singleLinkData(tester).flagsCollection.isFocused,
        Tristate.isTrue,
      );
      handle.dispose();
    });

    testWidgets('semantic tap uses the activation callback exactly once', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var callbackCount = 0;

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            onPressed: () => callbackCount++,
            child: const Text('Documentation'),
          ),
        ),
      );

      final node = _singleLinkNode(tester);
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pump();
      expect(callbackCount, 1);
      handle.dispose();
    });

    testWidgets('inert Links expose no role, URL, focus, or tap action', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final linkUrl = Uri.parse('https://example.com/docs');

      await tester.pumpWidget(
        _testApp(
          Column(
            children: [
              NakedLink(
                linkUrl: linkUrl,
                semanticLabel: 'Missing callback',
                child: const Text('Missing callback child'),
              ),
              NakedLink(
                enabled: false,
                linkUrl: linkUrl,
                semanticLabel: 'Explicitly disabled',
                onPressed: () {},
                child: const Text('Explicitly disabled child'),
              ),
            ],
          ),
        ),
      );

      expect(_linkNodes(tester), isEmpty);
      for (final label in ['Missing callback', 'Explicitly disabled']) {
        final data = _dataWithLabel(tester, label);
        expect(data.flagsCollection.isLink, isFalse);
        expect(data.flagsCollection.isButton, isFalse);
        expect(data.flagsCollection.isEnabled, Tristate.isFalse);
        expect(data.flagsCollection.isFocused, Tristate.none);
        expect(data.linkUrl, isNull);
        expect(data.hasAction(SemanticsAction.tap), isFalse);
      }
      handle.dispose();
    });

    testWidgets('localized label and hint remain exact in RTL', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _testApp(
          Directionality(
            textDirection: TextDirection.rtl,
            child: NakedLink(
              semanticLabel: 'الوثائق',
              semanticHint: 'يفتح في نافذة جديدة',
              onPressed: () {},
              child: const Text('المستندات'),
            ),
          ),
        ),
      );

      final data = _singleLinkData(tester);
      expect(data.label, 'الوثائق');
      expect(data.hint, 'يفتح في نافذة جديدة');
      expect(data.textDirection, TextDirection.rtl);
      handle.dispose();
    });

    testWidgets('excludeSemantics removes Link and descendant semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _testApp(
          NakedLink(
            semanticLabel: 'Documentation',
            excludeSemantics: true,
            onPressed: () {},
            child: const Text('Visible documentation'),
          ),
        ),
      );

      expect(_linkNodes(tester), isEmpty);
      expect(
        _allSemanticsData(tester).where(
          (data) =>
              data.label == 'Documentation' ||
              data.label == 'Visible documentation',
        ),
        isEmpty,
      );
      handle.dispose();
    });
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

SemanticsNode _singleLinkNode(WidgetTester tester) {
  final nodes = _linkNodes(tester);
  expect(nodes, hasLength(1));
  return nodes.single;
}

SemanticsData _singleLinkData(WidgetTester tester) =>
    _singleLinkNode(tester).getSemanticsData();

SemanticsData _dataWithLabel(WidgetTester tester, String label) {
  final matches = _allSemanticsData(
    tester,
  ).where((data) => data.label == label).toList();
  expect(matches, hasLength(1));
  return matches.single;
}

List<SemanticsNode> _linkNodes(WidgetTester tester) {
  final nodes = <SemanticsNode>[];
  _visitSemantics(tester, (node) {
    if (node.getSemanticsData().flagsCollection.isLink) nodes.add(node);
  });
  return nodes;
}

List<SemanticsData> _allSemanticsData(WidgetTester tester) {
  final data = <SemanticsData>[];
  _visitSemantics(tester, (node) => data.add(node.getSemanticsData()));
  return data;
}

void _visitSemantics(WidgetTester tester, ValueChanged<SemanticsNode> visit) {
  final root = tester.getSemantics(find.byType(Scaffold));

  void collect(SemanticsNode node) {
    visit(node);
    node.visitChildren((child) {
      collect(child);
      return true;
    });
  }

  collect(root);
}
