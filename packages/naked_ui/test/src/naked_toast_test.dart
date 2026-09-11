import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

const _toastSize = Size(200, 40);

/// A bare WidgetsApp with a caller-owned Overlay: no Material, no Navigator.
Widget _host(
  Widget child, {
  TextDirection textDirection = TextDirection.ltr,
  MediaQueryData Function(MediaQueryData data)? mediaQuery,
}) {
  return WidgetsApp(
    color: const Color(0xFF000000),
    builder: (context, _) {
      Widget result = Directionality(
        textDirection: textDirection,
        child: Overlay.wrap(child: child),
      );
      if (mediaQuery != null) {
        result = MediaQuery(
          data: mediaQuery(MediaQuery.of(context)),
          child: result,
        );
      }

      return result;
    },
  );
}

Widget _box(BuildContext context, NakedToastState<String> toast, _) {
  return ColoredBox(
    key: ValueKey('toast-${toast.data}'),
    color: const Color(0xFF222222),
    child: SizedBox.fromSize(size: _toastSize, child: Text(toast.data)),
  );
}

NakedToastScope<String> _scope({
  NakedToastController<String>? controller,
  NakedToastPlacement placement = NakedToastPlacement.bottomEnd,
  int maxVisible = 3,
  int maxQueued = 20,
  NakedToastBuilder<String> builder = _box,
  Widget child = const SizedBox.expand(),
}) {
  return NakedToastScope<String>(
    controller: controller,
    placement: placement,
    maxVisible: maxVisible,
    maxQueued: maxQueued,
    toastBuilder: builder,
    child: child,
  );
}

NakedToastRequest<String> _request(
  String data, {
  Object? id,
  Duration? duration = const Duration(seconds: 4),
  bool interactive = false,
}) {
  return NakedToastRequest<String>(
    id: id,
    data: data,
    semanticLabel: data,
    duration: duration,
    interactive: interactive,
  );
}

Finder _toast(String data) => find.byKey(ValueKey('toast-$data'));

Future<NakedToastDismissReason> _reason(NakedToastHandle handle) {
  expect(handle.isClosed, isTrue, reason: '${handle.id} is still open');

  return handle.closed;
}

NakedToastController<String> _controller() {
  final controller = NakedToastController<String>();
  addTearDown(controller.dispose);

  return controller;
}

void main() {
  group('NakedToastController', () {
    test('rejects show while detached', () {
      final controller = NakedToastController<String>();
      addTearDown(controller.dispose);

      expect(controller.isAttached, isFalse);
      expect(() => controller.show(_request('a')), throwsStateError);
      expect(controller.dismiss('missing'), isFalse);
      controller.clear();
    });

    testWidgets('validates requests', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));

      expect(
        () => controller.show(
          const NakedToastRequest(data: 'a', semanticLabel: '  '),
        ),
        throwsArgumentError,
      );
      expect(
        () => controller.show(_request('a', duration: Duration.zero)),
        throwsArgumentError,
      );
      expect(
        () => controller.show(_request('a', duration: null)),
        throwsArgumentError,
      );
      expect(controller.visibleCount, 0);
    });

    testWidgets('admits FIFO up to maxVisible and queues the rest', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 2, maxQueued: 2)),
      );

      final a = controller.show(_request('a'));
      final b = controller.show(_request('b'));
      final c = controller.show(_request('c'));
      final d = controller.show(_request('d'));
      await tester.pump();

      expect(_toast('a'), findsOneWidget);
      expect(_toast('b'), findsOneWidget);
      expect(_toast('c'), findsNothing);
      expect((controller.visibleCount, controller.pendingCount), (2, 2));

      final e = controller.show(_request('e'));
      expect(await _reason(c), NakedToastDismissReason.queueOverflow);
      expect(controller.pendingCount, 2);

      a.dismiss();
      await tester.pumpAndSettle();
      expect(_toast('a'), findsNothing);
      expect(_toast('d'), findsOneWidget);
      expect(await _reason(a), NakedToastDismissReason.programmatic);

      expect([b, d, e].map((handle) => handle.isClosed), everyElement(false));
      controller.clear();
      await tester.pumpAndSettle();
      for (final handle in [b, d, e]) {
        expect(await _reason(handle), NakedToastDismissReason.programmatic);
      }
    });

    testWidgets('overflows immediately when maxQueued is zero', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 1, maxQueued: 0)),
      );

      controller.show(_request('a'));
      final b = controller.show(_request('b'));

      expect(await _reason(b), NakedToastDismissReason.queueOverflow);
      expect(controller.pendingCount, 0);
    });

    testWidgets('starts a queued toast timer only after promotion', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 1)),
      );

      final a = controller.show(_request('a'));
      final b = controller.show(
        _request('b', duration: const Duration(seconds: 2)),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(b.isClosed, isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(await _reason(a), NakedToastDismissReason.timeout);

      await tester.pump(const Duration(milliseconds: 1999));
      expect(b.isClosed, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(await _reason(b), NakedToastDismissReason.timeout);
      await tester.pumpAndSettle();
      expect(_toast('b'), findsNothing);
    });

    testWidgets('replaces a same-id toast in place and restarts its lifetime', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));

      final first = controller.show(_request('first', id: 'upload'));
      await tester.pump(const Duration(seconds: 3));
      final second = controller.show(_request('second', id: 'upload'));
      await tester.pump();

      expect(await _reason(first), NakedToastDismissReason.replaced);
      expect(second.id, 'upload');
      expect(controller.visibleCount, 1);
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);

      first.dismiss();
      expect(second.isClosed, isFalse);

      await tester.pump(const Duration(seconds: 3));
      expect(second.isClosed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(await _reason(second), NakedToastDismissReason.timeout);
    });

    testWidgets('replaces a queued same-id toast without promoting it', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 1)),
      );

      controller.show(_request('a'));
      final queued = controller.show(_request('b', id: 'sync'));
      final replacement = controller.show(_request('b2', id: 'sync'));

      expect(await _reason(queued), NakedToastDismissReason.replaced);
      expect((controller.visibleCount, controller.pendingCount), (1, 1));
      expect(replacement.isClosed, isFalse);
    });

    testWidgets('completes each handle once and ignores repeat dismissal', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));

      final handle = controller.show(_request('a', id: 'a'));
      expect(controller.dismiss('a', NakedToastDismissReason.action), isTrue);
      expect(controller.dismiss('a'), isFalse);
      handle.dismiss(NakedToastDismissReason.close);
      controller.clear();

      expect(await _reason(handle), NakedToastDismissReason.action);
    });

    testWidgets('closes every toast when the scope is disposed', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 1)),
      );
      final visible = controller.show(_request('a'));
      final queued = controller.show(_request('b'));

      await tester.pumpWidget(const SizedBox());

      expect(await _reason(visible), NakedToastDismissReason.scopeDisposed);
      expect(await _reason(queued), NakedToastDismissReason.scopeDisposed);
      expect(controller.isAttached, isFalse);
      expect(() => controller.show(_request('c')), throwsStateError);
      // The scope did not dispose the caller-owned controller.
      controller.addListener(() {});
    });

    testWidgets('moves to a new controller when the widget changes', (
      tester,
    ) async {
      final first = _controller();
      final second = _controller();
      await tester.pumpWidget(_host(_scope(controller: first)));
      final handle = first.show(_request('a'));

      await tester.pumpWidget(_host(_scope(controller: second)));
      expect(await _reason(handle), NakedToastDismissReason.scopeDisposed);
      expect(first.isAttached, isFalse);

      second.show(_request('b'));
      await tester.pump();
      expect(_toast('a'), findsNothing);
      expect(_toast('b'), findsOneWidget);
    });

    testWidgets('promotes queued toasts when maxVisible grows', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 1)),
      );
      controller
        ..show(_request('a'))
        ..show(_request('b'));

      await tester.pumpWidget(
        _host(_scope(controller: controller, maxVisible: 2)),
      );

      expect((controller.visibleCount, controller.pendingCount), (2, 0));
      expect(_toast('b'), findsOneWidget);
    });

    testWidgets('rejects a controller shared by two mounted scopes', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              Expanded(child: _scope(controller: controller)),
              Expanded(child: _scope(controller: controller)),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isStateError);
    });

    testWidgets('rejects show during build', (tester) async {
      await tester.pumpWidget(
        _host(
          _scope(
            child: Builder(
              builder: (context) {
                NakedToastScope.of<String>(context).show(_request('a'));

                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('during build'),
        ),
      );
    });
  });

  group('NakedToastScope lookup and host', () {
    testWidgets('of finds the typed scope and explains a missing one', (
      tester,
    ) async {
      late BuildContext inside;
      late BuildContext outside;
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              Expanded(
                child: _scope(
                  child: Builder(
                    builder: (context) {
                      inside = context;

                      return const SizedBox();
                    },
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  outside = context;

                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      );

      expect(NakedToastScope.of<String>(inside).isAttached, isTrue);
      expect(NakedToastScope.maybeOf<int>(inside), isNull);
      expect(NakedToastScope.maybeOf<String>(outside), isNull);
      expect(
        () => NakedToastScope.of<String>(outside),
        throwsA(
          isA<FlutterError>().having(
            (error) => error.toString(),
            'message',
            contains('below the app Overlay'),
          ),
        ),
      );
    });

    testWidgets('explains a missing Overlay', (tester) async {
      await tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: _scope()),
      );

      expect(
        tester.takeException(),
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('requires an Overlay ancestor'),
        ),
      );
    });

    testWidgets('renders under a bare WidgetsApp with live inherited state', (
      tester,
    ) async {
      final tone = ValueNotifier('light');
      addTearDown(tone.dispose);
      final controller = _controller();

      await tester.pumpWidget(
        _host(
          ValueListenableBuilder<String>(
            valueListenable: tone,
            builder: (context, value, child) => _Tone(value, child: child!),
            child: _scope(
              controller: controller,
              builder: (context, toast, _) =>
                  Text('${toast.data} ${_Tone.of(context)}'),
            ),
          ),
        ),
      );
      controller.show(_request('saved'));
      await tester.pump();
      expect(find.text('saved light'), findsOneWidget);

      tone.value = 'dark';
      await tester.pump();
      expect(find.text('saved dark'), findsOneWidget);
    });
  });

  group('NakedToastScope layout', () {
    const inset = 24.0;
    const screen = Size(800, 600);

    for (final textDirection in TextDirection.values) {
      for (final placement in NakedToastPlacement.values) {
        testWidgets('places $placement in ${textDirection.name}', (
          tester,
        ) async {
          final controller = _controller();
          await tester.pumpWidget(
            _host(
              _scope(controller: controller, placement: placement),
              textDirection: textDirection,
            ),
          );
          controller.show(_request('a'));
          await tester.pump();

          final rect = tester.getRect(_toast('a'));
          final startLeft = textDirection == TextDirection.ltr
              ? inset
              : screen.width - inset - _toastSize.width;
          final endLeft = textDirection == TextDirection.ltr
              ? screen.width - inset - _toastSize.width
              : inset;
          final expectedLeft = switch (placement) {
            NakedToastPlacement.topStart ||
            NakedToastPlacement.bottomStart => startLeft,
            NakedToastPlacement.topCenter || NakedToastPlacement.bottomCenter =>
              (screen.width - _toastSize.width) / 2,
            NakedToastPlacement.topEnd ||
            NakedToastPlacement.bottomEnd => endLeft,
          };
          final isTop = placement.name.startsWith('top');

          expect(rect.left, expectedLeft);
          expect(
            rect.top,
            isTop ? inset : screen.height - inset - _toastSize.height,
          );
        });
      }
    }

    testWidgets('keeps the newest toast nearest the bottom edge', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));
      controller
        ..show(_request('old'))
        ..show(_request('new'));
      await tester.pump();

      expect(tester.getRect(_toast('new')).bottom, screen.height - inset);
      expect(
        tester.getRect(_toast('old')).bottom,
        screen.height - inset - _toastSize.height - 12,
      );
    });

    testWidgets('keeps the newest toast nearest the top edge', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(
          _scope(controller: controller, placement: NakedToastPlacement.topEnd),
        ),
      );
      controller
        ..show(_request('old'))
        ..show(_request('new'));
      await tester.pump();

      expect(tester.getRect(_toast('new')).top, inset);
      expect(tester.getRect(_toast('old')).top, inset + _toastSize.height + 12);
    });

    testWidgets('stays above the safe area and the keyboard', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(
          _scope(controller: controller),
          mediaQuery: (data) => data.copyWith(
            padding: const EdgeInsets.only(bottom: 30),
            viewInsets: const EdgeInsets.only(bottom: 300),
          ),
        ),
      );
      controller.show(_request('a'));
      await tester.pump();

      expect(tester.getRect(_toast('a')).bottom, screen.height - inset - 300);
    });

    testWidgets('passes pointer input through the empty region', (
      tester,
    ) async {
      final controller = _controller();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          _scope(
            controller: controller,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      controller.show(_request('a'));
      await tester.pump();

      await tester.tapAt(const Offset(100, 100));
      await tester.tapAt(Offset(tester.getCenter(_toast('a')).dx, 100));
      expect(taps, 2);

      await tester.tap(_toast('a'));
      expect(taps, 2);
    });
  });

  group('NakedToastScope lifetime', () {
    testWidgets('pauses while hovered and restarts the full duration', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));
      final handle = controller.show(_request('a'));
      await tester.pump();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(_toast('a')));
      await tester.pump(const Duration(seconds: 10));
      expect(handle.isClosed, isFalse);

      await mouse.moveTo(Offset.zero);
      await tester.pump(const Duration(seconds: 3));
      expect(handle.isClosed, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(await _reason(handle), NakedToastDismissReason.timeout);
    });

    testWidgets('pauses while focus is inside and Escape dismisses it', (
      tester,
    ) async {
      final controller = _controller();
      final outside = FocusNode(debugLabel: 'outside');
      final inside = FocusNode(debugLabel: 'inside');
      addTearDown(outside.dispose);
      addTearDown(inside.dispose);
      await tester.pumpWidget(
        _host(
          _scope(
            controller: controller,
            builder: (context, toast, _) =>
                Focus(focusNode: inside, child: _box(context, toast, null)),
            child: Focus(focusNode: outside, child: const SizedBox.expand()),
          ),
        ),
      );
      outside.requestFocus();
      await tester.pump();

      final handle = controller.show(_request('a', interactive: true));
      await tester.pump();
      expect(outside.hasPrimaryFocus, isTrue, reason: 'show never moves focus');

      inside.requestFocus();
      await tester.pump(const Duration(seconds: 10));
      expect(handle.isClosed, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(await _reason(handle), NakedToastDismissReason.close);
      expect(outside.hasPrimaryFocus, isTrue, reason: 'focus is restored');
    });

    testWidgets('pauses while the app is not resumed', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));
      final handle = controller.show(_request('a'));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(seconds: 10));
      expect(handle.isClosed, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      expect(await _reason(handle), NakedToastDismissReason.timeout);
    });

    testWidgets('holds interactive toasts during accessible navigation', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(
          _scope(controller: controller),
          mediaQuery: (data) => data.copyWith(accessibleNavigation: true),
        ),
      );
      final interactive = controller.show(_request('a', interactive: true));
      final advisory = controller.show(_request('b'));

      await tester.pump(const Duration(seconds: 10));
      expect(interactive.isClosed, isFalse);
      expect(await _reason(advisory), NakedToastDismissReason.timeout);
    });

    testWidgets('exposes hover and pause state to the presenter', (
      tester,
    ) async {
      final controller = _controller();
      NakedToastState<String>? seen;
      await tester.pumpWidget(
        _host(
          _scope(
            controller: controller,
            builder: (context, toast, animation) {
              seen = toast;

              return _box(context, toast, animation);
            },
          ),
        ),
      );
      controller.show(_request('a', id: 'a'));
      await tester.pump();
      expect(seen!.isHovered, isFalse);
      expect(seen!.isPaused, isFalse);
      expect(seen!.id, 'a');

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(_toast('a')));
      addTearDown(mouse.removePointer);
      await tester.pump();
      expect(seen!.isHovered, isTrue);
      expect(seen!.isPaused, isTrue);

      seen!.dismiss();
      await tester.pump();
      expect(seen!.isExiting, isTrue);
    });

    testWidgets('runs the exit transition before removing the toast', (
      tester,
    ) async {
      final controller = _controller();
      await tester.pumpWidget(_host(_scope(controller: controller)));
      final handle = controller.show(_request('a'));
      await tester.pumpAndSettle();

      handle.dismiss();
      await tester.pump();
      expect(handle.isClosed, isTrue);
      expect(_toast('a'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 60));
      expect(_toast('a'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(_toast('a'), findsNothing);
    });

    testWidgets('skips motion when animations are disabled', (tester) async {
      final controller = _controller();
      await tester.pumpWidget(
        _host(
          _scope(controller: controller),
          mediaQuery: (data) => data.copyWith(disableAnimations: true),
        ),
      );
      final handle = controller.show(_request('a'));
      await tester.pump();

      handle.dismiss();
      await tester.pump();
      await tester.pump();
      expect(_toast('a'), findsNothing);
    });
  });
}

class _Tone extends InheritedWidget {
  const _Tone(this.value, {required super.child});

  final String value;

  static String of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Tone>()!.value;

  @override
  bool updateShouldNotify(_Tone oldWidget) => value != oldWidget.value;
}
