import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

Future<BuildContext> _pumpEmptyHost(WidgetTester tester) async {
  late BuildContext hostContext;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          hostContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return hostContext;
}

void main() {
  group('NakedDialog', () {
    test('rejects semantics roles other than dialog and alert dialog', () {
      expect(
        () => NakedDialog(
          semanticsRole: SemanticsRole.tab,
          child: const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'renders child and returns a value on pop',
      (tester) async {
        String? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      result = await showNakedDialog<String>(
                        context: ctx,
                        barrierColor: Colors.black54,
                        builder: (context) => ElevatedButton(
                          onPressed: () =>
                              Navigator.of(context).pop('Success!'),
                          child: const Text('Close Me'),
                        ),
                      );
                    },
                    child: const Text('Open Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Close Me'), findsOneWidget);

        await tester.tap(find.text('Close Me'));
        await tester.pumpAndSettle();

        expect(find.text('Close Me'), findsNothing);
        expect(result, 'Success!');
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    testWidgets('barrierDismissible=true closes on outside tap', (
      tester,
    ) async {
      BuildContext? ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final future = showNakedDialog(
        context: ctx!,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        builder: (context) => const Center(child: Text('Dialog Content')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsNothing);
      await future;
    });

    testWidgets(
      'barrierDismissible=false does not close on outside tap',
      (tester) async {
        BuildContext? ctx;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                ctx = context;
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        );

        final future = showNakedDialog(
          context: ctx!,
          barrierColor: Colors.black54,
          barrierDismissible: false,
          builder: (context) => const Center(child: Text('Dialog Content')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Dialog Content'), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Still visible
        expect(find.text('Dialog Content'), findsOneWidget);

        // Dismiss programmatically to clean up
        Navigator.of(ctx!).pop();
        await tester.pumpAndSettle();
        await future;
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    testWidgets('ESC dismisses when barrierDismissible=true', (tester) async {
      BuildContext? ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final fut = showNakedDialog(
        context: ctx!,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        builder: (_) => const Center(child: Text('Dialog Content')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dialog Content'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsNothing);
      await fut;
    });

    testWidgets('ESC does not dismiss when barrierDismissible=false', (
      tester,
    ) async {
      BuildContext? ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      final fut = showNakedDialog(
        context: ctx!,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        builder: (_) => const Center(child: Text('Dialog Content')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dialog Content'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Still visible
      expect(find.text('Dialog Content'), findsOneWidget);

      Navigator.of(ctx!).pop();
      await tester.pumpAndSettle();
      await fut;
    });

    testWidgets('respects useRootNavigator with nested Navigator', (
      tester,
    ) async {
      final nestedKey = GlobalKey<NavigatorState>();
      BuildContext? leafContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Navigator(
              key: nestedKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => Builder(
                  builder: (context) {
                    leafContext = context;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Show on root navigator
      final rootFuture = showNakedDialog(
        context: leafContext!,
        useRootNavigator: true,
        barrierColor: Colors.black54,
        builder: (_) => const SizedBox.shrink(),
      );
      await tester.pumpAndSettle();
      expect(nestedKey.currentState!.canPop(), isFalse);
      Navigator.of(leafContext!, rootNavigator: true).pop();
      await tester.pumpAndSettle();
      await rootFuture;

      // Show on nested navigator
      final nestedFuture = showNakedDialog(
        context: leafContext!,
        useRootNavigator: false,
        barrierColor: Colors.black54,
        builder: (_) => const SizedBox.shrink(),
      );
      await tester.pumpAndSettle();
      expect(nestedKey.currentState!.canPop(), isTrue);
      nestedKey.currentState!.pop();
      await tester.pumpAndSettle();
      await nestedFuture;
    });

    testWidgets('Tab traversal stays within dialog (closed loop)', (
      tester,
    ) async {
      BuildContext? ctx;
      final outsideFocus = FocusNode(debugLabel: 'outside');

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              ctx = context;
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    focusNode: outsideFocus,
                    onPressed: () {},
                    child: const Text('Outside Button'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      final fut = showNakedDialog(
        context: ctx!,
        barrierColor: Colors.black54,
        barrierDismissible: true,
        builder: (_) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              // Ensure initial focus is inside the dialog.
              ElevatedButton(
                autofocus: true,
                onPressed: null,
                child: Text('A'),
              ),
              SizedBox(height: 8),
              ElevatedButton(onPressed: null, child: Text('B')),
            ],
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      // Step focus forward multiple times; it should remain within the dialog.
      for (int i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          outsideFocus.hasFocus,
          isFalse,
          reason: 'Focus should remain trapped inside the dialog',
        );
      }

      // Cleanup
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await fut;
    });
  });

  group('showNakedAlertDialog', () {
    testWidgets('rejects an empty semantic label', (tester) async {
      final hostContext = await _pumpEmptyHost(tester);

      expect(() {
        showNakedAlertDialog<void>(
          context: hostContext,
          barrierColor: Colors.black54,
          semanticLabel: '   ',
          builder: (context) => const SizedBox.shrink(),
        );
      }, throwsArgumentError);
    });

    testWidgets('requires a label for a dismissible barrier', (tester) async {
      final hostContext = await _pumpEmptyHost(tester);

      for (final barrierLabel in <String?>[null, '   ']) {
        expect(() {
          showNakedAlertDialog<void>(
            context: hostContext,
            barrierColor: Colors.black54,
            semanticLabel: 'Eliminar archivo',
            barrierDismissible: true,
            barrierLabel: barrierLabel,
            builder: (context) => const SizedBox.shrink(),
          );
        }, throwsArgumentError);
      }
    });

    testWidgets('always moves focus inside and leaves background inert', (
      tester,
    ) async {
      final invokerNode = FocusNode(debugLabel: 'alert invoker');
      final cancelNode = FocusNode(debugLabel: 'alert cancel');
      addTearDown(invokerNode.dispose);
      addTearDown(cancelNode.dispose);
      var invokerActivations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return NakedButton(
                focusNode: invokerNode,
                onPressed: () {
                  invokerActivations += 1;
                  showNakedAlertDialog<void>(
                    context: context,
                    barrierColor: Colors.black54,
                    semanticLabel: 'Eliminar archivo',
                    transitionDuration: Duration.zero,
                    initialFocusNode: cancelNode,
                    builder: (context) => ElevatedButton(
                      focusNode: cancelNode,
                      onPressed: () {},
                      child: const Text('Cancel'),
                    ),
                  );
                },
                child: const Text('Invoker'),
              );
            },
          ),
        ),
      );

      invokerNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();

      expect(invokerActivations, 1);
      expect(FocusManager.instance.primaryFocus, same(cancelNode));

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(invokerActivations, 1);
      expect(find.text('Cancel'), findsOneWidget);

      Navigator.of(tester.element(find.text('Cancel'))).pop();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('opt-in barrier dismissal completes exactly once', (
      tester,
    ) async {
      final invokerNode = FocusNode(debugLabel: 'dismissible alert invoker');
      addTearDown(invokerNode.dispose);
      var completionCount = 0;
      Future<Object?>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                focusNode: invokerNode,
                onPressed: () {
                  result = showNakedAlertDialog<Object>(
                    context: context,
                    barrierColor: Colors.black54,
                    semanticLabel: 'Eliminar archivo',
                    barrierDismissible: true,
                    barrierLabel: 'Cerrar alerta',
                    transitionDuration: Duration.zero,
                    builder: (context) => const SizedBox.square(
                      key: ValueKey('dismissible.alert'),
                      dimension: 200,
                    ),
                  )..whenComplete(() => completionCount += 1);
                },
                child: const Text('Open dismissible alert'),
              );
            },
          ),
        ),
      );

      invokerNode.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Open dismissible alert'));
      await tester.pump();
      await tester.pump();

      await tester.tapAt(const Offset(4, 4));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('dismissible.alert')), findsNothing);
      expect(result, isNotNull);
      expect(await result!, isNull);
      expect(completionCount, 1);
      expect(FocusManager.instance.primaryFocus, same(invokerNode));
    });

    testWidgets('Tab and Shift+Tab loop between known alert actions', (
      tester,
    ) async {
      final firstNode = FocusNode(debugLabel: 'first alert action');
      final secondNode = FocusNode(debugLabel: 'second alert action');
      addTearDown(firstNode.dispose);
      addTearDown(secondNode.dispose);
      final hostContext = await _pumpEmptyHost(tester);

      showNakedAlertDialog<void>(
        context: hostContext,
        barrierColor: Colors.black54,
        semanticLabel: 'Eliminar archivo',
        transitionDuration: Duration.zero,
        initialFocusNode: firstNode,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              focusNode: firstNode,
              onPressed: () {},
              child: const Text('First'),
            ),
            ElevatedButton(
              focusNode: secondNode,
              onPressed: () {},
              child: const Text('Second'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(firstNode));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(secondNode));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(firstNode));

      Navigator.of(hostContext).pop();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('fallback preserves a descendant autofocus request', (
      tester,
    ) async {
      final firstNode = FocusNode(debugLabel: 'first alert action');
      final autofocusNode = FocusNode(debugLabel: 'autofocus alert action');
      addTearDown(firstNode.dispose);
      addTearDown(autofocusNode.dispose);
      final hostContext = await _pumpEmptyHost(tester);

      showNakedAlertDialog<void>(
        context: hostContext,
        barrierColor: Colors.black54,
        semanticLabel: 'Confirm action',
        transitionDuration: Duration.zero,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              focusNode: firstNode,
              onPressed: () {},
              child: const Text('First'),
            ),
            ElevatedButton(
              autofocus: true,
              focusNode: autofocusNode,
              onPressed: () {},
              child: const Text('Autofocus'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(FocusManager.instance.primaryFocus, same(autofocusNode));

      Navigator.of(hostContext).pop();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('closing after removing the invoker does not throw', (
      tester,
    ) async {
      final invokerNode = FocusNode(debugLabel: 'removable alert invoker');
      final cancelNode = FocusNode(debugLabel: 'alert cancel');
      addTearDown(invokerNode.dispose);
      addTearDown(cancelNode.dispose);
      var showInvoker = true;
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return Scaffold(
                body: showInvoker
                    ? ElevatedButton(
                        focusNode: invokerNode,
                        onPressed: () => showNakedAlertDialog<void>(
                          context: context,
                          barrierColor: Colors.black54,
                          semanticLabel: 'Eliminar archivo',
                          transitionDuration: Duration.zero,
                          initialFocusNode: cancelNode,
                          builder: (context) => ElevatedButton(
                            focusNode: cancelNode,
                            onPressed: () {},
                            child: const Text('Cancel'),
                          ),
                        ),
                        child: const Text('Open removable alert'),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      );

      invokerNode.requestFocus();
      await tester.pump();
      await tester.tap(find.text('Open removable alert'));
      await tester.pump();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(cancelNode));

      setHostState(() => showInvoker = false);
      await tester.pump();
      Navigator.of(tester.element(find.text('Cancel'))).pop();
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(invokerNode.hasFocus, isFalse);
    });

    testWidgets(
      'falls back to first traversable action when safe node is unavailable',
      (tester) async {
        BuildContext? hostContext;
        final unavailableNode = FocusNode(
          debugLabel: 'unavailable safe target',
        );
        final firstNode = FocusNode(debugLabel: 'first alert action');
        final secondNode = FocusNode(debugLabel: 'second alert action');
        addTearDown(unavailableNode.dispose);
        addTearDown(firstNode.dispose);
        addTearDown(secondNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                hostContext = context;
                return ElevatedButton(
                  focusNode: unavailableNode,
                  onPressed: () {},
                  child: const Text('Background action'),
                );
              },
            ),
          ),
        );

        showNakedAlertDialog<void>(
          context: hostContext!,
          barrierColor: Colors.black54,
          semanticLabel: 'Eliminar archivo',
          transitionDuration: Duration.zero,
          initialFocusNode: unavailableNode,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                focusNode: firstNode,
                onPressed: () {},
                child: const Text('First'),
              ),
              ElevatedButton(
                focusNode: secondNode,
                onPressed: () {},
                child: const Text('Second'),
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(FocusManager.instance.primaryFocus, same(firstNode));

        Navigator.of(hostContext!).pop();
        await tester.pump();
        await tester.pump();
      },
    );

    testWidgets('focuses the caller safe node and never disposes it', (
      tester,
    ) async {
      final invokerNode = FocusNode(debugLabel: 'alert invoker');
      final cancelNode = FocusNode(debugLabel: 'alert cancel');
      final confirmNode = FocusNode(debugLabel: 'alert confirm');
      addTearDown(invokerNode.dispose);
      addTearDown(cancelNode.dispose);
      addTearDown(confirmNode.dispose);
      Future<String?>? result;
      var cancelCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                focusNode: invokerNode,
                onPressed: () {
                  result = showNakedAlertDialog<String>(
                    context: context,
                    barrierColor: Colors.black54,
                    semanticLabel: 'Eliminar archivo',
                    transitionDuration: Duration.zero,
                    initialFocusNode: cancelNode,
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          focusNode: cancelNode,
                          onPressed: () {
                            cancelCount += 1;
                            Navigator.of(context).pop('cancel');
                          },
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          focusNode: confirmNode,
                          onPressed: () => Navigator.of(context).pop('confirm'),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open alert'),
              ),
            ),
          ),
        ),
      );

      invokerNode.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(invokerNode));

      await tester.tap(find.text('Open alert'));
      await tester.pump();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(cancelNode));

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump();
      expect(await result, 'cancel');
      expect(cancelCount, 1);
      expect(FocusManager.instance.primaryFocus, same(invokerNode));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Focus(focusNode: cancelNode, child: const SizedBox.shrink()),
        ),
      );
      cancelNode.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(cancelNode));
    });

    testWidgets(
      'wraps once, keeps the barrier inert, and safely cancels on Escape',
      (tester) async {
        final invokerNode = FocusNode(debugLabel: 'alert invoker');
        final cancelNode = FocusNode(debugLabel: 'alert cancel');
        addTearDown(invokerNode.dispose);
        addTearDown(cancelNode.dispose);
        Future<String?>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      focusNode: invokerNode,
                      onPressed: () {
                        result = showNakedAlertDialog<String>(
                          context: context,
                          barrierColor: Colors.black54,
                          semanticLabel: 'Eliminar archivo',
                          transitionDuration: Duration.zero,
                          initialFocusNode: cancelNode,
                          builder: (context) => Center(
                            child: SizedBox.square(
                              key: const ValueKey('alert.content'),
                              dimension: 200,
                              child: ElevatedButton(
                                focusNode: cancelNode,
                                onPressed: () =>
                                    Navigator.of(context).pop('cancel'),
                                child: const Text('Cancel'),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open alert'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        invokerNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.pump();

        expect(find.byType(NakedDialog), findsOneWidget);
        expect(
          tester.widget<NakedDialog>(find.byType(NakedDialog)).semanticsRole,
          SemanticsRole.alertDialog,
        );

        await tester.tapAt(const Offset(4, 4));
        await tester.pump();
        expect(find.byKey(const ValueKey('alert.content')), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(find.byKey(const ValueKey('alert.content')), findsNothing);
        expect(await result, isNull);
        expect(FocusManager.instance.primaryFocus, same(invokerNode));
        await tester.pump();
      },
    );

    testWidgets('system back safely cancels once and restores focus', (
      tester,
    ) async {
      final invokerNode = FocusNode(debugLabel: 'system back alert invoker');
      final cancelNode = FocusNode(debugLabel: 'system back alert cancel');
      addTearDown(invokerNode.dispose);
      addTearDown(cancelNode.dispose);
      Future<String?>? result;
      var completionCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              focusNode: invokerNode,
              onPressed: () {
                result = showNakedAlertDialog<String>(
                  context: context,
                  barrierColor: Colors.black54,
                  semanticLabel: 'Eliminar archivo',
                  transitionDuration: Duration.zero,
                  initialFocusNode: cancelNode,
                  builder: (context) => ElevatedButton(
                    key: const ValueKey('system-back.alert'),
                    focusNode: cancelNode,
                    onPressed: () => Navigator.of(context).pop('cancel'),
                    child: const Text('Cancel'),
                  ),
                )..whenComplete(() => completionCount += 1);
              },
              child: const Text('Open alert'),
            ),
          ),
        ),
      );

      invokerNode.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(cancelNode));

      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('system-back.alert')), findsNothing);
      expect(await result, isNull);
      expect(completionCount, 1);
      expect(FocusManager.instance.primaryFocus, same(invokerNode));
    });
  });
}
