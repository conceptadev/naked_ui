// ignore_for_file: deprecated_member_use
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

Widget _host(Widget child) {
  return WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) => Overlay.wrap(child: child),
  );
}

/// Presenter that follows the documented contract: visual text is excluded
/// under the toast's labelled node, controls stay separate button nodes.
Widget _presenter(BuildContext context, NakedToastState<String> toast, _) {
  return SizedBox(
    key: ValueKey('toast-${toast.data}'),
    width: 240,
    height: 40,
    child: Row(
      children: [
        Expanded(child: ExcludeSemantics(child: Text(toast.data))),
        Semantics(
          button: true,
          label: 'Dismiss',
          onTap: toast.dismiss,
          child: const SizedBox(width: 24, height: 24),
        ),
      ],
    ),
  );
}

Future<NakedToastController<String>> _pumpScope(
  WidgetTester tester, {
  int maxVisible = 3,
}) async {
  final controller = NakedToastController<String>();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    _host(
      NakedToastScope<String>(
        controller: controller,
        maxVisible: maxVisible,
        toastBuilder: _presenter,
        child: const SizedBox.expand(),
      ),
    ),
  );

  return controller;
}

SemanticsData _data(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();

void main() {
  group('NakedToast semantics', () {
    testWidgets('polite toast is one status node without a live region', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await _pumpScope(tester);

      controller.show(
        const NakedToastRequest(data: 'Saved', semanticLabel: 'Draft saved'),
      );
      await tester.pump();

      final data = _data(tester, 'Draft saved');
      expect(data.role, SemanticsRole.status);
      expect(data.hasFlag(SemanticsFlag.isLiveRegion), isFalse);
      expect(find.bySemanticsLabel('Saved'), findsNothing);
      semantics.dispose();
    });

    testWidgets('assertive toast is an alert node', (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = await _pumpScope(tester);

      controller.show(
        const NakedToastRequest(
          data: 'Failed',
          semanticLabel: 'Upload failed',
          priority: NakedToastPriority.assertive,
        ),
      );
      await tester.pump();

      final data = _data(tester, 'Upload failed');
      expect(data.role, SemanticsRole.alert);
      expect(data.hasFlag(SemanticsFlag.isLiveRegion), isFalse);
      semantics.dispose();
    });

    testWidgets('presenter controls stay separate button nodes', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await _pumpScope(tester);

      final handle = controller.show(
        const NakedToastRequest(
          data: 'Saved',
          semanticLabel: 'Draft saved',
          interactive: true,
        ),
      );
      await tester.pump();

      final toastNode = tester.getSemantics(
        find.bySemanticsLabel('Draft saved'),
      );
      final buttonNode = tester.getSemantics(find.bySemanticsLabel('Dismiss'));
      expect(buttonNode.id, isNot(toastNode.id));
      expect(toastNode.getSemanticsData().label, 'Draft saved');
      expect(
        buttonNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        toastNode.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );

      tester.semantics.tap(find.semantics.byLabel('Dismiss'));
      expect(await handle.closed, NakedToastDismissReason.close);
      semantics.dispose();
    });

    testWidgets('a presenter rebuild keeps the same node', (tester) async {
      final semantics = tester.ensureSemantics();
      final tone = ValueNotifier('light');
      addTearDown(tone.dispose);
      final controller = NakedToastController<String>();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _host(
          NakedToastScope<String>(
            controller: controller,
            toastBuilder: (context, toast, animation) =>
                ValueListenableBuilder<String>(
                  valueListenable: tone,
                  builder: (context, value, _) => KeyedSubtree(
                    key: ValueKey(value),
                    child: _presenter(context, toast, animation),
                  ),
                ),
            child: const SizedBox.expand(),
          ),
        ),
      );
      controller.show(
        const NakedToastRequest(data: 'Saved', semanticLabel: 'Draft saved'),
      );
      await tester.pump();
      final before = tester.getSemantics(find.bySemanticsLabel('Draft saved'));

      tone.value = 'dark';
      await tester.pump();
      final after = tester.getSemantics(find.bySemanticsLabel('Draft saved'));

      expect(after.id, before.id);
      semantics.dispose();
    });

    testWidgets('queued toasts have no node and exiting toasts drop theirs', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final controller = await _pumpScope(tester, maxVisible: 1);

      final first = controller.show(
        const NakedToastRequest(data: 'a', semanticLabel: 'First'),
      );
      controller.show(
        const NakedToastRequest(data: 'b', semanticLabel: 'Second'),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('First'), findsOneWidget);
      expect(find.bySemanticsLabel('Second'), findsNothing);

      first.dismiss();
      await tester.pump();
      expect(find.byKey(const ValueKey('toast-a')), findsOneWidget);
      expect(find.semantics.byLabel('First'), findsNothing);
      expect(find.semantics.byLabel('Second'), findsOne);
      semantics.dispose();
    });
  });
}
