import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:naked_ui/naked_ui.dart';

void main() {
  runApp(const SemanticsPlaygroundApp());
}

class SemanticsPlaygroundApp extends StatelessWidget {
  const SemanticsPlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: SemanticsPlayground()),
    );
  }
}

class SemanticsPlayground extends StatefulWidget {
  const SemanticsPlayground({super.key});

  @override
  State<SemanticsPlayground> createState() => _SemanticsPlaygroundState();
}

class _SemanticsPlaygroundState extends State<SemanticsPlayground> {
  late final SemanticsHandle _semanticsHandle;

  @override
  void initState() {
    super.initState();
    _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
  }

  @override
  void dispose() {
    _semanticsHandle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: const [
              Text(
                'Semantics Playground',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              _Scenario(
                title: 'Menu',
                defaultChild: _MenuDemo(label: 'Default menu'),
                overrideChild: _MenuDemo(
                  label: 'Visual menu',
                  semanticLabel: 'Override menu trigger',
                ),
              ),
              _Scenario(
                title: 'Accordion',
                defaultChild: _AccordionDemo(label: 'Default accordion'),
                overrideChild: _AccordionDemo(
                  label: 'Visual accordion',
                  semanticLabel: 'Override accordion trigger',
                ),
              ),
              _Scenario(
                title: 'Radio',
                defaultChild: _RadioDemo(label: 'Default radio'),
                overrideChild: _RadioDemo(
                  label: 'Visual radio',
                  semanticLabel: 'Override radio option',
                ),
              ),
              _Scenario(
                title: 'Select',
                defaultChild: _SelectDemo(label: 'Default select'),
                overrideChild: _SelectDemo(
                  label: 'Visual select',
                  semanticLabel: 'Override select trigger',
                ),
              ),
              _Scenario(
                title: 'Slider',
                defaultChild: _SliderDemo(label: 'Default slider'),
                overrideChild: _SliderDemo(
                  label: 'Override slider',
                  formatterPrefix: 'Override slider percent',
                ),
              ),
              _Scenario(
                title: 'Text field',
                defaultChild: _TextFieldDemo(label: 'Default text field'),
                overrideChild: _TextFieldDemo(
                  label: 'Override text field',
                  errorText: 'Override text field error',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Scenario extends StatelessWidget {
  const _Scenario({
    required this.title,
    required this.defaultChild,
    required this.overrideChild,
  });

  final String title;
  final Widget defaultChild;
  final Widget overrideChild;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Variant(label: 'Default semantics', child: defaultChild),
                _Variant(label: 'Override semantics', child: overrideChild),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Variant extends StatelessWidget {
  const _Variant({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          child,
        ],
      ),
    );
  }
}

class _MenuDemo extends StatefulWidget {
  const _MenuDemo({required this.label, this.semanticLabel});

  final String label;
  final String? semanticLabel;

  @override
  State<_MenuDemo> createState() => _MenuDemoState();
}

class _MenuDemoState extends State<_MenuDemo> {
  final _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    return NakedMenu<String>(
      controller: _controller,
      semanticLabel: widget.semanticLabel,
      builder: (context, state, child) => _BoxedControl(
        pressed: state.isPressed,
        focused: state.isFocused,
        child: Text(widget.label),
      ),
      overlayBuilder: (context, info) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: NakedMenuItem<String>(
          value: 'first',
          semanticLabel: '${widget.label} item',
          builder: (context, state, child) => const Padding(
            padding: EdgeInsets.all(12),
            child: Text('First action'),
          ),
        ),
      ),
    );
  }
}

class _AccordionDemo extends StatefulWidget {
  const _AccordionDemo({required this.label, this.semanticLabel});

  final String label;
  final String? semanticLabel;

  @override
  State<_AccordionDemo> createState() => _AccordionDemoState();
}

class _AccordionDemoState extends State<_AccordionDemo> {
  late final NakedAccordionController<String> _controller;

  @override
  void initState() {
    super.initState();
    _controller = NakedAccordionController<String>();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NakedAccordionGroup<String>(
      controller: _controller,
      initialExpandedValues: const [],
      child: NakedAccordion<String>(
        value: widget.label,
        semanticLabel: widget.semanticLabel,
        builder: (context, state) => _BoxedControl(
          pressed: state.isPressed,
          focused: state.isFocused,
          child: Text(widget.label),
        ),
        child: const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Accordion content'),
        ),
      ),
    );
  }
}

class _RadioDemo extends StatefulWidget {
  const _RadioDemo({required this.label, this.semanticLabel});

  final String label;
  final String? semanticLabel;

  @override
  State<_RadioDemo> createState() => _RadioDemoState();
}

class _RadioDemoState extends State<_RadioDemo> {
  String _value = 'current';

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: _value,
      onChanged: (value) => setState(() => _value = value ?? _value),
      child: NakedRadio<String>(
        value: 'current',
        semanticLabel: widget.semanticLabel,
        builder: (context, state, child) => _BoxedControl(
          pressed: state.isPressed,
          focused: state.isFocused,
          child: Text(widget.label),
        ),
      ),
    );
  }
}

class _SelectDemo extends StatefulWidget {
  const _SelectDemo({required this.label, this.semanticLabel});

  final String label;
  final String? semanticLabel;

  @override
  State<_SelectDemo> createState() => _SelectDemoState();
}

class _SelectDemoState extends State<_SelectDemo> {
  String _value = 'one';

  @override
  Widget build(BuildContext context) {
    return NakedSelect<String>(
      value: _value,
      semanticLabel: widget.semanticLabel,
      onChanged: (value) => setState(() => _value = value ?? _value),
      builder: (context, state, child) => _BoxedControl(
        pressed: state.isPressed,
        focused: state.isFocused,
        child: Text(widget.label),
      ),
      overlayBuilder: (context, info) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in const ['one', 'two'])
              NakedSelect.Option(
                value: value,
                semanticLabel: '${widget.label} option $value',
                builder: (context, state, child) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SliderDemo extends StatefulWidget {
  const _SliderDemo({required this.label, this.formatterPrefix});

  final String label;
  final String? formatterPrefix;

  @override
  State<_SliderDemo> createState() => _SliderDemoState();
}

class _SliderDemoState extends State<_SliderDemo> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: NakedSlider(
        values: [_value],
        min: 0,
        max: 1,
        step: 0.01,
        semanticLabels: [widget.label],
        semanticFormatterCallbacks: [
          widget.formatterPrefix == null
              ? null
              : (value) => '${widget.formatterPrefix} ${(value * 100).round()}',
        ],
        onChanged: (values) => setState(() => _value = values.single),
        child: CustomPaint(painter: _SliderPainter(_value)),
      ),
    );
  }
}

class _TextFieldDemo extends StatelessWidget {
  const _TextFieldDemo({required this.label, this.errorText});

  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return NakedTextField(
      semanticLabel: label,
      semanticErrorText: errorText,
      error: errorText != null,
      builder: (context, state, editableText) => _BoxedControl(
        focused: state.isFocused,
        pressed: state.isPressed,
        child: editableText,
      ),
    );
  }
}

class _BoxedControl extends StatelessWidget {
  const _BoxedControl({
    required this.child,
    required this.focused,
    required this.pressed,
  });

  final Widget child;
  final bool focused;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      constraints: const BoxConstraints(minHeight: 44, minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pressed ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: focused ? Colors.blue : Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final active = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final inactive = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), inactive);
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width * value, centerY),
      active,
    );
    canvas.drawCircle(Offset(size.width * value, centerY), 8, active);
  }

  @override
  bool shouldRepaint(_SliderPainter oldDelegate) => oldDelegate.value != value;
}
