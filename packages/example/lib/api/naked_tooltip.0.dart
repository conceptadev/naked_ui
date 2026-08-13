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
                'Simple Tooltip',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Hover the button to see the tooltip',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 24),
              TooltipExample(),
            ],
          ),
        ),
      ),
    );
  }
}

class TooltipExample extends StatelessWidget {
  const TooltipExample({super.key});

  @override
  Widget build(BuildContext context) {
    return NakedTooltip(
      semanticLabel: 'This is a tooltip',
      positioning: const OverlayPositionConfig(
        side: OverlaySide.bottom,
        alignment: OverlayAlignment.end,
        sideOffset: 4,
      ),
      hoverDelay: Duration.zero,
      dismissDelay: const Duration(seconds: 1),
      overlayBuilder: (context, animation) => FadeTransition(
        opacity: animation,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: const Text(
            'This is a tooltip',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Hover me', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
