import 'package:flutter/material.dart';
import 'package:naked_ui/naked_ui.dart';

/// Main function
void main() {
  runApp(const MyApp());
}

/// Main App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const SafeArea(
          child: Column(
            children: [
              SizedBox(height: 24),
              Text(
                'Toggle Button Example',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Interact with the toggle button to see its states',
                style: TextStyle(color: Colors.grey),
              ),
              Expanded(child: ToggleButtonExample()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle Button Example
class ToggleButtonExample extends StatefulWidget {
  const ToggleButtonExample({super.key});

  @override
  State<ToggleButtonExample> createState() => _ToggleButtonExampleState();
}

/// Toggle Button Example State
class _ToggleButtonExampleState extends State<ToggleButtonExample> {
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;

  Widget _buildToggleButton({
    required IconData icon,
    required bool isSelected,
    required ValueChanged<bool> onChanged,
    required String tooltip,
  }) {
    return NakedToggle(
      value: isSelected,
      asSwitch: false, // Toggle button semantics
      onChanged: onChanged,
      semanticLabel: tooltip,
      builder: (context, toggleState, child) {
        final isSelected = toggleState.isToggled;
        final isHovered = toggleState.isHovered;
        final isFocused = toggleState.isFocused;
        final isPressed = toggleState.isPressed;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.grey.shade800
                : isHovered
                ? Colors.grey.shade200
                : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: isFocused
                ? Border.all(color: Colors.grey.shade400, width: 2)
                : Border.all(color: Colors.grey.shade300),
            boxShadow: isPressed
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : Colors.grey.shade700,
            size: 18,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Independent formatting toggles',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Bold, Italic, and Underline can be combined.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildToggleButton(
                icon: Icons.format_bold,
                isSelected: _isBold,
                onChanged: (value) => setState(() => _isBold = value),
                tooltip: 'Bold',
              ),
              const SizedBox(width: 8),
              _buildToggleButton(
                icon: Icons.format_italic,
                isSelected: _isItalic,
                onChanged: (value) => setState(() => _isItalic = value),
                tooltip: 'Italic',
              ),
              const SizedBox(width: 8),
              _buildToggleButton(
                icon: Icons.format_underlined,
                isSelected: _isUnderlined,
                onChanged: (value) => setState(() => _isUnderlined = value),
                tooltip: 'Underline',
              ),
            ],
          ),
          const SizedBox(height: 32),
          const ToggleGroupExample(),
        ],
      ),
    );
  }
}

/// Deliberately single-choice fixture for existing segmented-button behavior.
///
/// Real formatting commands that can combine are demonstrated by the retained
/// standalone toggles in [ToggleButtonExample].
class ToggleGroupExample extends StatefulWidget {
  /// Creates a single-choice compatibility fixture.
  const ToggleGroupExample({
    super.key,
    this.orientation = Axis.horizontal,
    this.textDirection = TextDirection.ltr,
    this.disableMiddleOption = false,
  });

  /// The axis used by the group and its arrow-key navigation.
  final Axis orientation;

  /// The direction used for horizontal layout and arrow-key navigation.
  final TextDirection textDirection;

  /// Whether the Italic option is disabled.
  final bool disableMiddleOption;

  @override
  State<ToggleGroupExample> createState() => _ToggleGroupExampleState();
}

class _ToggleGroupExampleState extends State<ToggleGroupExample> {
  static const _values = ['bold', 'italic', 'underline'];
  static const _labels = {
    'bold': 'Bold',
    'italic': 'Italic',
    'underline': 'Underline',
  };

  late final Map<String, FocusNode> _optionFocusNodes = {
    for (final value in _values)
      value: FocusNode(debugLabel: 'toggle group $value'),
  };
  final _removeFocusNode = FocusNode(debugLabel: 'remove focused option');
  final _resetFocusNode = FocusNode(debugLabel: 'reset toggle group');

  var _visibleValues = List<String>.of(_values);
  var _selectedValue = _values.first;
  String? _lastFocusedValue;

  bool get _canRemoveFocusedOption {
    final focusedValue = _lastFocusedValue;
    return _visibleValues.length > 1 &&
        focusedValue != null &&
        _visibleValues.contains(focusedValue);
  }

  void _removeFocusedOption() {
    final focusedValue = _lastFocusedValue;
    if (!_canRemoveFocusedOption || focusedValue == null) return;

    setState(() {
      _visibleValues = _visibleValues
          .where((value) => value != focusedValue)
          .toList();
      if (_selectedValue == focusedValue) {
        _selectedValue = _visibleValues.first;
      }
    });
  }

  void _reset() {
    setState(() {
      _visibleValues = List<String>.of(_values);
      _selectedValue = _values.first;
    });
  }

  Widget _buildOption(String value) {
    final label = _labels[value]!;
    final enabled = !(widget.disableMiddleOption && value == 'italic');

    return NakedToggleOption<String>(
      key: Key('toggle-group.option.$value'),
      value: value,
      enabled: enabled,
      focusNode: _optionFocusNodes[value],
      onFocusChange: (focused) {
        if (focused) {
          setState(() => _lastFocusedValue = value);
        }
      },
      builder: (context, state, child) {
        final foregroundColor = state.isDisabled
            ? Colors.grey.shade400
            : state.isSelected
            ? Colors.white
            : Colors.grey.shade800;

        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: state.isSelected ? Colors.grey.shade800 : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: state.isFocused
                  ? Colors.blue.shade600
                  : Colors.grey.shade300,
              width: state.isFocused ? 2 : 1,
            ),
          ),
          child: Text(label, style: TextStyle(color: foregroundColor)),
        );
      },
    );
  }

  @override
  void dispose() {
    for (final focusNode in _optionFocusNodes.values) {
      focusNode.dispose();
    }
    _removeFocusNode.dispose();
    _resetFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Single-choice compatibility demonstration',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'This group deliberately allows one choice. Use the standalone '
            'formatting controls when Bold, Italic, and Underline must combine.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ),
        const SizedBox(height: 12),
        Directionality(
          textDirection: widget.textDirection,
          child: NakedToggleGroup<String>(
            key: const Key('toggle-group.root'),
            selectedValue: _selectedValue,
            orientation: widget.orientation,
            semanticLabel: 'Single-choice formatting compatibility',
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedValue = value);
              }
            },
            child: Wrap(
              direction: widget.orientation,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in _visibleValues) _buildOption(value),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExcludeSemantics(
          child: Text(
            'Selected: ${_labels[_selectedValue]}',
            key: const Key('toggle-group.value'),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            OutlinedButton(
              key: const Key('toggle-group.remove-focused'),
              focusNode: _removeFocusNode,
              onPressed: _canRemoveFocusedOption ? _removeFocusedOption : null,
              child: const Text('Remove focused'),
            ),
            TextButton(
              key: const Key('toggle-group.reset'),
              focusNode: _resetFocusNode,
              onPressed: _reset,
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }
}
