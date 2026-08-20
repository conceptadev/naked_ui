import 'package:flutter/material.dart';
import 'package:naked_ui/naked_ui.dart';

class DisclosureExample extends StatefulWidget {
  const DisclosureExample({super.key});

  @override
  State<DisclosureExample> createState() => _DisclosureExampleState();
}

class _DisclosureExampleState extends State<DisclosureExample> {
  bool _showDeliveryDetails = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _UncontrolledDisclosure(),
            const SizedBox(height: 16),
            NakedDisclosure(
              expanded: _showDeliveryDetails,
              onExpandedChanged: (value) {
                setState(() => _showDeliveryDetails = value);
              },
              builder: _buildTrigger,
              panel: const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ships in 2–3 business days with tracking.'),
                ),
              ),
              transitionBuilder: (context, animation, child) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: child,
                ),
              ),
              itemBuilder: _buildItem,
              child: const Text('Delivery details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UncontrolledDisclosure extends StatelessWidget {
  const _UncontrolledDisclosure();

  @override
  Widget build(BuildContext context) {
    return NakedDisclosure(
      defaultExpanded: true,
      semanticHint: 'Shows or hides return policy details',
      builder: _buildTrigger,
      panel: const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Unused items can be returned within 30 days.'),
        ),
      ),
      transitionBuilder: (context, animation, child) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      itemBuilder: _buildItem,
      child: const Text('What is the return policy?'),
    );
  }
}

Widget _buildTrigger(
  BuildContext context,
  NakedDisclosureState state,
  Widget? child,
) {
  final color = state.when(
    disabled: Colors.grey.shade200,
    pressed: Colors.blue.shade100,
    hovered: Colors.blue.shade50,
    focused: Colors.blue.shade50,
    orElse: Colors.white,
  );

  return AnimatedContainer(
    duration: const Duration(milliseconds: 120),
    padding: const EdgeInsets.all(16),
    color: color,
    child: Row(
      children: [
        Expanded(
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontWeight: FontWeight.w600),
            child: child!,
          ),
        ),
        AnimatedRotation(
          turns: state.isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    ),
  );
}

Widget _buildItem(
  BuildContext context,
  NakedDisclosureState state,
  Widget? child,
) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(
        color: state.isFocused ? Colors.blue : Colors.grey.shade300,
        width: state.isFocused ? 2 : 1,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(borderRadius: BorderRadius.circular(11), child: child),
  );
}
