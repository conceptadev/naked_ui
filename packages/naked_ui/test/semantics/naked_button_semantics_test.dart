import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

import 'semantics_test_utils.dart';

void main() {
  Widget _buildTestApp(Widget child) {
    return MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('NakedButton Semantics', () {
    testWidgets('parity with MaterialButton (enabled)', (tester) async {
      final handle = tester.ensureSemantics();
      await expectSemanticsParity(
        tester: tester,
        material: _buildTestApp(
          ElevatedButton(onPressed: () {}, child: const Text('Click me')),
        ),
        naked: _buildTestApp(
          NakedButton(onPressed: () {}, child: const Text('Click me')),
        ),
        control: ControlType.button,
      );
      handle.dispose();
    });

    testWidgets('parity with MaterialButton when focused', (tester) async {
      final handle = tester.ensureSemantics();
      final focusNodeMaterial = FocusNode();
      final focusNodeNaked = FocusNode();

      // Material focused
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(
            onPressed: () {},
            focusNode: focusNodeMaterial,
            child: const Text('Click me'),
          ),
        ),
      );
      focusNodeMaterial.requestFocus();
      await tester.pump();
      final materialFocused = summarizeMergedButtonFromRoot(tester);

      // Naked focused
      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {},
            focusNode: focusNodeNaked,
            child: const Text('Click me'),
          ),
        ),
      );
      focusNodeNaked.requestFocus();
      await tester.pump();
      final nakedFocused = summarizeMergedButtonFromRoot(tester);

      expect(nakedFocused, equals(materialFocused));

      focusNodeMaterial.dispose();
      focusNodeNaked.dispose();
      handle.dispose();
    });

    testWidgets('parity with MaterialButton when hovered', (tester) async {
      final handle = tester.ensureSemantics();

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await tester.pump();

      // Material hovered
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(onPressed: () {}, child: const Text('Hover')),
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byType(ElevatedButton)));
      await tester.pump();
      final materialHovered = summarizeMergedButtonFromRoot(tester);

      // Naked hovered
      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(onPressed: () {}, child: const Text('Hover')),
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byType(NakedButton)));
      await tester.pump();
      final nakedHovered = summarizeMergedButtonFromRoot(tester);

      expect(nakedHovered, equals(materialHovered));

      await mouse.removePointer();
      handle.dispose();
    });

    testWidgets('parity with MaterialButton when pressed (pointer down)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      // Material press/release
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(onPressed: () {}, child: const Text('Press')),
        ),
      );
      final centerMat = tester.getCenter(find.byType(ElevatedButton));
      final gestureMat = await tester.startGesture(centerMat);
      await tester.pump();
      final materialPressed = summarizeMergedButtonFromRoot(tester);
      await gestureMat.up();
      await tester.pump();
      final materialReleased = summarizeMergedButtonFromRoot(tester);

      // Naked press/release
      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(onPressed: () {}, child: const Text('Press')),
        ),
      );
      final centerN = tester.getCenter(find.byType(NakedButton));
      final gestureN = await tester.startGesture(centerN);
      await tester.pump();
      final nakedPressed = summarizeMergedButtonFromRoot(tester);
      await gestureN.up();
      await tester.pump();
      final nakedReleased = summarizeMergedButtonFromRoot(tester);

      expect(nakedPressed, equals(materialPressed));
      expect(nakedReleased, equals(materialReleased));
      handle.dispose();
    });

    testWidgets(
      'parity with MaterialButton during keyboard activation (Space/Enter)',
      (tester) async {
        final handle = tester.ensureSemantics();

        final focusNodeMaterial = FocusNode();
        final focusNodeNaked = FocusNode();

        // Space key
        bool materialActivatedSpace = false;
        await tester.pumpWidget(
          _buildTestApp(
            ElevatedButton(
              onPressed: () {
                materialActivatedSpace = true;
              },
              focusNode: focusNodeMaterial,
              child: const Text('Key'),
            ),
          ),
        );
        focusNodeMaterial.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        final materialAfterSpace = summarizeMergedButtonFromRoot(tester);

        bool nakedActivatedSpace = false;
        await tester.pumpWidget(
          _buildTestApp(
            NakedButton(
              onPressed: () {
                nakedActivatedSpace = true;
              },
              focusNode: focusNodeNaked,
              child: const Text('Key'),
            ),
          ),
        );
        focusNodeNaked.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.pump();
        final nakedAfterSpace = summarizeMergedButtonFromRoot(tester);

        expect(materialActivatedSpace, isTrue);
        expect(nakedActivatedSpace, isTrue);
        expect(nakedAfterSpace, equals(materialAfterSpace));

        // Enter key
        bool materialActivatedEnter = false;
        await tester.pumpWidget(
          _buildTestApp(
            ElevatedButton(
              onPressed: () {
                materialActivatedEnter = true;
              },
              focusNode: focusNodeMaterial,
              child: const Text('Key'),
            ),
          ),
        );
        focusNodeMaterial.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final materialAfterEnter = summarizeMergedButtonFromRoot(tester);

        bool nakedActivatedEnter = false;
        await tester.pumpWidget(
          _buildTestApp(
            NakedButton(
              onPressed: () {
                nakedActivatedEnter = true;
              },
              focusNode: focusNodeNaked,
              child: const Text('Key'),
            ),
          ),
        );
        focusNodeNaked.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final nakedAfterEnter = summarizeMergedButtonFromRoot(tester);

        expect(materialActivatedEnter, isTrue);
        expect(nakedActivatedEnter, isTrue);
        expect(nakedAfterEnter, equals(materialAfterEnter));

        focusNodeMaterial.dispose();
        focusNodeNaked.dispose();
        handle.dispose();
      },
    );

    testWidgets('parity includes longPress action when provided', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await expectSemanticsParity(
        tester: tester,
        material: _buildTestApp(
          ElevatedButton(
            onPressed: () {},
            onLongPress: () {},
            child: const Text('Hold'),
          ),
        ),
        naked: _buildTestApp(
          NakedButton(
            onPressed: () {},
            onLongPress: () {},
            child: const Text('Hold'),
          ),
        ),
        control: ControlType.button,
      );
      handle.dispose();
    });

    testWidgets('event callbacks: tap and longPress parity', (tester) async {
      final handle = tester.ensureSemantics();

      bool materialTapped = false;
      bool materialLongPressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(
            onPressed: () {
              materialTapped = true;
            },
            onLongPress: () {
              materialLongPressed = true;
            },
            child: const Text('Evt M'),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(materialTapped, isTrue);
      await tester.longPress(find.byType(ElevatedButton));
      await tester.pump();
      expect(materialLongPressed, isTrue);

      bool nakedTapped = false;
      bool nakedLongPressed = false;
      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {
              nakedTapped = true;
            },
            onLongPress: () {
              nakedLongPressed = true;
            },
            child: const Text('Evt N'),
          ),
        ),
      );
      await tester.tap(find.byType(NakedButton));
      await tester.pump();
      expect(nakedTapped, isTrue);
      await tester.longPress(find.byType(NakedButton));
      await tester.pump();
      expect(nakedLongPressed, isTrue);

      handle.dispose();
    });

    testWidgets('parity with MaterialButton (disabled)', (tester) async {
      final handle = tester.ensureSemantics();
      await expectSemanticsParity(
        tester: tester,
        material: _buildTestApp(
          const ElevatedButton(onPressed: null, child: Text('Disabled')),
        ),
        naked: _buildTestApp(
          NakedButton(onPressed: null, child: const Text('Disabled')),
        ),
        control: ControlType.button,
      );
      handle.dispose();
    });

    // Replaced by strict parity tests below

    testWidgets('no duplicate tap semantics', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {},
            semanticLabel: 'Test button',
            child: const Text('Click'),
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(NakedButton));
      int tapActionCount =
          node.getSemanticsData().hasAction(SemanticsAction.tap) ? 1 : 0;
      bool visitor(SemanticsNode n) {
        if (n.getSemanticsData().hasAction(SemanticsAction.tap)) {
          tapActionCount++;
        }
        return true;
      }

      node.visitChildren(visitor);
      expect(tapActionCount, 1);

      handle.dispose();
    });
  });

  group('NakedButton Strict Parity (no utils)', () {
    testWidgets('enabled strict parity vs Material', (tester) async {
      final handle = tester.ensureSemantics();

      // Pump Material and capture its exact semantics
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(onPressed: () {}, child: const Text('Strict')),
        ),
      );
      final materialNode = tester.getSemantics(find.bySemanticsLabel('Strict'));
      final strictMatcher = buildStrictMatcherFromSemanticsData(
        materialNode.getSemanticsData(),
      );

      // Sanity: Material matches its own semantics
      expect(materialNode, strictMatcher);

      // Now pump Naked and ensure it matches the same strict semantics
      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(onPressed: () {}, child: const Text('Strict')),
        ),
      );
      // Find button-like semantics node by traversing from Scaffold
      final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
      SemanticsNode? nakedNode;
      bool visitor(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) {
          nakedNode = n;
          return true;
        }
        n.visitChildren(visitor);
        return true;
      }

      root.visitChildren(visitor);
      expect(nakedNode, isNotNull);
      expect(nakedNode!, strictMatcher);

      handle.dispose();
    });

    testWidgets('focused strict parity vs Material', (tester) async {
      final handle = tester.ensureSemantics();
      final fm = FocusNode();
      final fn = FocusNode();

      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(
            onPressed: () {},
            focusNode: fm,
            child: const Text('Focus'),
          ),
        ),
      );
      fm.requestFocus();
      await tester.pump();
      final mNode = tester.getSemantics(find.bySemanticsLabel('Focus'));
      final strict = buildStrictMatcherFromSemanticsData(
        mNode.getSemanticsData(),
      );
      expect(mNode, strict);

      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {},
            focusNode: fn,
            child: const Text('Focus'),
          ),
        ),
      );
      fn.requestFocus();
      await tester.pump();

      final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
      SemanticsNode? nNode;
      bool visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) {
          nNode = n;
          return true;
        }
        n.visitChildren(visit);
        return true;
      }

      root.visitChildren(visit);
      expect(nNode, isNotNull);
      expect(nNode!, strict);

      fm.dispose();
      fn.dispose();
      handle.dispose();
    });

    testWidgets('hovered strict parity vs Material', (tester) async {
      final handle = tester.ensureSemantics();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      await tester.pump();

      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(onPressed: () {}, child: const Text('HoverMe')),
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byType(ElevatedButton)));
      await tester.pump();
      final mNode = tester.getSemantics(find.bySemanticsLabel('HoverMe'));
      final strict = buildStrictMatcherFromSemanticsData(
        mNode.getSemanticsData(),
      );
      expect(mNode, strict);

      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(onPressed: () {}, child: const Text('HoverMe')),
        ),
      );
      await mouse.moveTo(tester.getCenter(find.byType(NakedButton)));
      await tester.pump();

      final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
      SemanticsNode? nNode;
      bool visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) {
          nNode = n;
          return true;
        }
        n.visitChildren(visit);
        return true;
      }

      root.visitChildren(visit);
      expect(nNode, isNotNull);
      expect(nNode!, strict);

      await mouse.removePointer();
      handle.dispose();
    });

    testWidgets('pressed strict parity vs Material', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(onPressed: () {}, child: const Text('PressMe')),
        ),
      );
      final centerM = tester.getCenter(find.byType(ElevatedButton));
      final gM = await tester.startGesture(centerM);
      await tester.pump();
      final mNode = tester.getSemantics(find.bySemanticsLabel('PressMe'));
      final strict = buildStrictMatcherFromSemanticsData(
        mNode.getSemanticsData(),
      );
      expect(mNode, strict);
      await gM.up();
      await tester.pump();

      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(onPressed: () {}, child: const Text('PressMe')),
        ),
      );
      final centerN = tester.getCenter(find.byType(NakedButton));
      final gN = await tester.startGesture(centerN);
      await tester.pump();
      final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
      SemanticsNode? nNode;
      bool visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) {
          nNode = n;
          return true;
        }
        n.visitChildren(visit);
        return true;
      }

      root.visitChildren(visit);
      expect(nNode, isNotNull);
      expect(nNode!, strict);
      await gN.up();
      await tester.pump();

      handle.dispose();
    });

    testWidgets('keyboard activation strict parity (Space/Enter)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final fm = FocusNode();
      final fn = FocusNode();

      // Space
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(
            onPressed: () {},
            focusNode: fm,
            child: const Text('KeyT'),
          ),
        ),
      );
      fm.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();
      final mNode = tester.getSemantics(find.bySemanticsLabel('KeyT'));
      final strict = buildStrictMatcherFromSemanticsData(
        mNode.getSemanticsData(),
      );
      expect(mNode, strict);

      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {},
            focusNode: fn,
            child: const Text('KeyT'),
          ),
        ),
      );
      fn.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump();

      final SemanticsNode root = tester.getSemantics(find.byType(Scaffold));
      SemanticsNode? nNode;
      bool visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) {
          nNode = n;
          return true;
        }
        n.visitChildren(visit);
        return true;
      }

      root.visitChildren(visit);
      expect(nNode, isNotNull);
      expect(nNode!, strict);

      // Enter
      await tester.pumpWidget(
        _buildTestApp(
          ElevatedButton(
            onPressed: () {},
            focusNode: fm,
            child: const Text('KeyT'),
          ),
        ),
      );
      fm.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      final mNode2 = tester.getSemantics(find.bySemanticsLabel('KeyT'));
      final strict2 = buildStrictMatcherFromSemanticsData(
        mNode2.getSemanticsData(),
      );
      expect(mNode2, strict2);

      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {},
            focusNode: fn,
            child: const Text('KeyT'),
          ),
        ),
      );
      fn.requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      final SemanticsNode root2 = tester.getSemantics(find.byType(Scaffold));
      SemanticsNode? nNode2;
      bool visit2(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton || d.hasAction(SemanticsAction.tap)) {
          nNode2 = n;
          return true;
        }
        n.visitChildren(visit2);
        return true;
      }

      root2.visitChildren(visit2);
      expect(nNode2, isNotNull);
      expect(nNode2!, strict2);

      fm.dispose();
      fn.dispose();
      handle.dispose();
    });

    testWidgets('semanticHint lives on the same button node', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _buildTestApp(
          NakedButton(
            onPressed: () {},
            semanticLabel: 'Save',
            semanticHint: 'Saves the current document',
            child: const SizedBox.square(dimension: 24),
          ),
        ),
      );

      final root = tester.getSemantics(find.byType(Scaffold));
      final buttons = collectSemanticsNodes(
        root,
        (node) => node.getSemanticsData().flagsCollection.isButton,
      );
      expect(buttons, hasLength(1));

      final data = buttons.single.getSemanticsData();
      expect(data.label, 'Save');
      expect(data.hint, 'Saves the current document');
      expect(data.hasAction(SemanticsAction.tap), isTrue);

      handle.dispose();
    });
  });
}
