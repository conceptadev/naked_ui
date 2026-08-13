import 'package:flutter/material.dart';
import 'package:naked_ui/naked_ui.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Simple Accordion',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Interact with the accordion to see sections expand and collapse',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 24),
              AccordionExample(),
            ],
          ),
        ),
      ),
    );
  }
}

class AccordionExample extends StatefulWidget {
  const AccordionExample({super.key});

  @override
  State<AccordionExample> createState() => _AccordionExampleState();
}

class _AccordionExampleState extends State<AccordionExample> {
  final _controller = NakedAccordionController<String>(max: 1, min: 1);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: NakedAccordionGroup<String>(
        controller: _controller,
        initialExpandedValues: const ['1'],
        child: const Column(
          children: [
            AccordionItem(
              value: '1',
              title: 'Section 1',
              content:
                  'This is the content for section 1. You can put anything here!',
            ),
            SizedBox(height: 8),
            AccordionItem(
              value: '2',
              title: 'Section 2',
              content:
                  'This is the content for section 2. You can put anything here!',
            ),
          ],
        ),
      ),
    );
  }
}

class AccordionItem extends StatefulWidget {
  const AccordionItem({
    super.key,
    required this.value,
    required this.title,
    required this.content,
  });

  final String value;
  final String title;
  final String content;

  @override
  State<AccordionItem> createState() => _AccordionItemState();
}

class _AccordionItemState extends State<AccordionItem> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey.shade100,
      ),
      child: NakedAccordion<String>(
        value: widget.value,
        builder: (context, state) {
          final isExpanded = state.isExpanded;
          final isHoveredOrExpanded = state.isHovered || isExpanded;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              border: Border.all(
                color: isHoveredOrExpanded
                    ? Colors.grey.shade100
                    : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(12),
              color: isHoveredOrExpanded ? Colors.grey.shade100 : Colors.white,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
                    weight: 100,
                  ),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            widget.content,
            style: const TextStyle(color: Color(0xFF3D3D3D)),
          ),
        ),
        transitionBuilder: (child) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation.drive(CurveTween(curve: Curves.easeIn)),
              child: SizeTransition(
                axis: Axis.vertical,
                sizeFactor: animation,
                // Flutter 3.44 deprecates this in favor of `alignment`, which
                // is unavailable on the oldest SDK in the supported matrix.
                // ignore: deprecated_member_use
                axisAlignment: 1,
                child: child,
              ),
            );
          },
          child: child,
        ),
      ),
    );
  }
}
