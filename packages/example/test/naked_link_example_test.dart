import 'package:example/api/naked_link.0.dart' as link_example;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fixture exposes the essential Link states and controls', (
    tester,
  ) async {
    await tester.pumpWidget(const link_example.MyApp());

    for (final key in [
      'link.primary',
      'link.disabled',
      'link.result',
      'link.state',
      'link.next-focus',
      'link.disable-primary',
      'link.reset',
    ]) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.text('Result: none'), findsOneWidget);
    expect(
      find.text('hovered:false focused:false pressed:false enabled:true'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('link.primary'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('activation, disabling, and reset are deterministic', (
    tester,
  ) async {
    await tester.pumpWidget(const link_example.MyApp());

    await tester.tap(find.byKey(const ValueKey('link.primary')));
    await tester.pump();
    expect(find.text('Result: documentation'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('link.reset')));
    await tester.tap(find.byKey(const ValueKey('link.disable-primary')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('link.primary')));
    await tester.pump();
    expect(find.text('Result: none'), findsOneWidget);
    expect(
      find.text('hovered:false focused:false pressed:false enabled:false'),
      findsOneWidget,
    );
  });

  testWidgets('fixture exposes enabled and inert semantic contracts', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const link_example.MyApp());

    final enabled = tester
        .getSemantics(find.text('Open documentation'))
        .getSemanticsData();
    expect(enabled.flagsCollection.isLink, isTrue);
    expect(enabled.linkUrl, isNull);
    expect(enabled.hasAction(SemanticsAction.tap), isTrue);

    final disabled = tester
        .getSemantics(find.text('Unavailable documentation'))
        .getSemanticsData();
    expect(disabled.flagsCollection.isLink, isFalse);
    expect(disabled.linkUrl, isNull);
    expect(disabled.hasAction(SemanticsAction.tap), isFalse);
    handle.dispose();
  });
}
