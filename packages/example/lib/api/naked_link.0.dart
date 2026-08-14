import 'package:flutter/material.dart';
import 'package:naked_ui/naked_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: SafeArea(child: LinkExample())),
    );
  }
}

/// A small styled fixture for the headless Link contract.
class LinkExample extends StatefulWidget {
  const LinkExample({super.key});

  @override
  State<LinkExample> createState() => _LinkExampleState();
}

class _LinkExampleState extends State<LinkExample> {
  var _result = 'none';
  var _enabled = true;
  var _hovered = false;
  var _focused = false;
  var _pressed = false;

  void _activate() {
    setState(() => _result = 'documentation');
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    setState(() {
      _result = 'none';
      _enabled = true;
      _hovered = false;
      _focused = false;
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NakedLink',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'The widget owns link behavior and state; the callback owns '
                'navigation.',
              ),
              const SizedBox(height: 20),
              NakedLink(
                key: const ValueKey('link.primary'),
                enabled: _enabled,
                onPressed: _activate,
                onHoverChange: (value) => setState(() => _hovered = value),
                onFocusChange: (value) => setState(() => _focused = value),
                onPressChange: (value) => setState(() => _pressed = value),
                child: const Text('Open documentation'),
                builder: (context, state, child) =>
                    _LinkSurface(state: state, child: child!),
              ),
              const SizedBox(height: 12),
              NakedLink(
                key: const ValueKey('link.disabled'),
                enabled: false,
                onPressed: () => setState(() => _result = 'unavailable'),
                child: const Text('Unavailable documentation'),
                builder: (context, state, child) =>
                    _LinkSurface(state: state, child: child!),
              ),
              const SizedBox(height: 20),
              Text('Result: $_result', key: const ValueKey('link.result')),
              const SizedBox(height: 4),
              Text(
                'hovered:$_hovered focused:$_focused '
                'pressed:$_pressed enabled:$_enabled',
                key: const ValueKey('link.state'),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    key: const ValueKey('link.next-focus'),
                    onPressed: () => setState(() => _result = 'next-focus'),
                    child: const Text('Next focus target'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('link.disable-primary'),
                    onPressed: _enabled
                        ? () => setState(() => _enabled = false)
                        : null,
                    child: const Text('Disable Link'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('link.reset'),
                    onPressed: _reset,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkSurface extends StatelessWidget {
  const _LinkSurface({required this.state, required this.child});

  final NakedLinkState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final foreground = state.isDisabled
        ? const Color(0xFF64748B)
        : const Color(0xFF1D4ED8);
    final background = state.when(
      disabled: const Color(0xFFE2E8F0),
      pressed: const Color(0xFFBFDBFE),
      hovered: const Color(0xFFDBEAFE),
      orElse: Colors.transparent,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(
          color: state.isFocused ? const Color(0xFF2563EB) : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
        child: child,
      ),
    );
  }
}
