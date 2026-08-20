// ignore_for_file: prefer_const_constructors

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';

typedef _StateFactory = NakedState Function(Set<WidgetState> states);

class _ContractCase {
  const _ContractCase({
    required this.description,
    required this.orderedStates,
    required this.create,
  });

  final String description;
  final List<WidgetState> orderedStates;
  final _StateFactory create;
}

/// Verification test to ensure hashCode/equals contract is honored.
///
/// The contract states: if a == b, then a.hashCode == b.hashCode
///
/// This test verifies that state objects with the same content (but
/// potentially different Set instances/ordering) have matching hashCodes.
void main() {
  group('hashCode/equals contract verification', () {
    Set<WidgetState> orderedStateSet(Iterable<WidgetState> states) =>
        <WidgetState>{...states};

    void expectHashCodeContract({
      required _StateFactory create,
      required List<WidgetState> orderedStates,
    }) {
      final states1 = orderedStateSet(orderedStates);
      final states2 = orderedStateSet(orderedStates.reversed);

      final state1 = create(states1);
      final state2 = create(states2);

      expect(state1 == state2, isTrue);
      expect(state1.hashCode, equals(state2.hashCode));
    }

    final cases = <_ContractCase>[
      _ContractCase(
        description: 'NakedLinkState',
        orderedStates: [WidgetState.hovered, WidgetState.focused],
        create: (states) => NakedLinkState(
          states: states,
          linkUrl: Uri.parse('https://example.com/docs'),
        ),
      ),
      _ContractCase(
        description: 'NakedButtonState',
        orderedStates: [WidgetState.hovered, WidgetState.focused],
        create: (states) => NakedButtonState(states: states),
      ),
      _ContractCase(
        description: 'NakedDisclosureState',
        orderedStates: [WidgetState.selected, WidgetState.focused],
        create: (states) =>
            NakedDisclosureState(states: states, isExpanded: true),
      ),
      _ContractCase(
        description: 'NakedPopoverState',
        orderedStates: [WidgetState.hovered, WidgetState.pressed],
        create: (states) => NakedPopoverState(states: states, isOpen: true),
      ),
      _ContractCase(
        description: 'NakedCheckboxState',
        orderedStates: [WidgetState.focused, WidgetState.hovered],
        create: (states) => NakedCheckboxState(
          states: states,
          isChecked: true,
          tristate: false,
        ),
      ),
      _ContractCase(
        description: 'NakedToggleState',
        orderedStates: [WidgetState.disabled, WidgetState.focused],
        create: (states) => NakedToggleState(states: states, isToggled: true),
      ),
      _ContractCase(
        description: 'NakedToggleOptionState',
        orderedStates: [WidgetState.selected, WidgetState.focused],
        create: (states) =>
            NakedToggleOptionState<String>(states: states, value: 'opt1'),
      ),
      _ContractCase(
        description: 'NakedSliderState',
        orderedStates: [WidgetState.pressed, WidgetState.focused],
        create: (states) => NakedSliderState(
          states: states,
          values: const [25, 75],
          min: 0,
          max: 100,
          step: 1,
          minSpacing: 0,
          orientation: Axis.horizontal,
          inverted: false,
          textDirection: TextDirection.ltr,
          isDragging: false,
        ),
      ),
      _ContractCase(
        description: 'NakedMenuState',
        orderedStates: [WidgetState.hovered, WidgetState.selected],
        create: (states) => NakedMenuState(states: states, isOpen: false),
      ),
      _ContractCase(
        description: 'NakedMenuItemState',
        orderedStates: [WidgetState.hovered, WidgetState.selected],
        create: (states) =>
            NakedMenuItemState<String>(states: states, value: 'item1'),
      ),
      _ContractCase(
        description: 'NakedTabState',
        orderedStates: [WidgetState.selected, WidgetState.focused],
        create: (states) => NakedTabState(states: states, tabId: 'tab1'),
      ),
      _ContractCase(
        description: 'NakedTextFieldState',
        orderedStates: [WidgetState.focused, WidgetState.hovered],
        create: (states) => NakedTextFieldState(
          states: states,
          text: 'hello',
          hasText: true,
          isReadOnly: false,
        ),
      ),
      _ContractCase(
        description: 'NakedRadioState',
        orderedStates: [WidgetState.selected, WidgetState.focused],
        create: (states) =>
            NakedRadioState<String>(states: states, value: 'option1'),
      ),
      _ContractCase(
        description: 'NakedSelectState',
        orderedStates: [WidgetState.focused, WidgetState.hovered],
        create: (states) => NakedSelectState<String>(
          states: states,
          isOpen: true,
          value: 'selected',
        ),
      ),
      _ContractCase(
        description: 'NakedSelectOptionState',
        orderedStates: [WidgetState.selected, WidgetState.hovered],
        create: (states) =>
            NakedSelectOptionState<String>(states: states, value: 'opt1'),
      ),
      _ContractCase(
        description: 'NakedAccordionGroupState',
        orderedStates: [WidgetState.focused, WidgetState.hovered],
        create: (states) => NakedAccordionGroupState(
          states: states,
          expandedCount: 1,
          minExpanded: 0,
          maxExpanded: 3,
        ),
      ),
      _ContractCase(
        description: 'NakedAccordionItemState',
        orderedStates: [WidgetState.selected, WidgetState.focused],
        create: (states) => NakedAccordionItemState<String>(
          states: states,
          value: 'item1',
          isExpanded: true,
          canCollapse: true,
          canExpand: false,
        ),
      ),
    ];

    for (final c in cases) {
      test('${c.description} honors contract', () {
        expectHashCodeContract(
          create: c.create,
          orderedStates: c.orderedStates,
        );
      });
    }

    test('Different states have different equality', () {
      final state1 = NakedButtonState(states: {WidgetState.hovered});
      final state2 = NakedButtonState(states: {WidgetState.focused});

      // Different content = not equal
      expect(state1 == state2, isFalse);
      // hashCodes MAY differ (but don't have to - collisions are allowed)
    });

    test('NakedDisclosureState expansion participates in equality', () {
      final collapsed = NakedDisclosureState(states: {}, isExpanded: false);
      final expanded = NakedDisclosureState(states: {}, isExpanded: true);

      expect(collapsed, isNot(expanded));
    });
  });
}
