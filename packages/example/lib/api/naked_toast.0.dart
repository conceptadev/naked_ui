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
        body: const Center(child: ToastExample()),
      ),
    );
  }
}

/// Visual tone of an example toast.
enum ToastTone { neutral, danger }

/// The payload each example toast renders.
class ToastMessage {
  const ToastMessage({
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.tone = ToastTone.neutral,
  });

  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ToastTone tone;
}

class ToastExample extends StatefulWidget {
  const ToastExample({
    super.key,
    this.placement = NakedToastPlacement.bottomEnd,
    this.duration = const Duration(seconds: 5),
  });

  final NakedToastPlacement placement;

  /// How long timed toasts stay visible.
  final Duration duration;

  @override
  State<ToastExample> createState() => _ToastExampleState();
}

class _ToastExampleState extends State<ToastExample> {
  final _controller = NakedToastController<ToastMessage>();

  String _lastResult = 'none';
  int _undoCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _show(NakedToastRequest<ToastMessage> request) async {
    final reason = await _controller.show(request).closed;
    if (!mounted) return;
    setState(() => _lastResult = reason.name);
  }

  Future<void> _showSaved() => _show(
    NakedToastRequest(
      // Saving again replaces this toast instead of stacking a copy.
      id: 'saved',
      data: const ToastMessage(title: 'Draft saved'),
      semanticLabel: 'Draft saved',
      duration: widget.duration,
    ),
  );

  Future<void> _showArchived() => _show(
    NakedToastRequest(
      id: 'archived',
      data: ToastMessage(
        title: 'Conversation archived',
        actionLabel: 'Undo',
        onAction: () => setState(() => _undoCount += 1),
      ),
      semanticLabel: 'Conversation archived',
      duration: widget.duration,
      interactive: true,
    ),
  );

  Future<void> _showFailed() => _show(
    const NakedToastRequest(
      id: 'failed',
      data: ToastMessage(
        title: 'Upload failed',
        description: 'Check your connection and try again.',
        actionLabel: 'Retry',
        tone: ToastTone.danger,
      ),
      semanticLabel: 'Upload failed. Check your connection and try again.',
      // Stays until the user retries or closes it.
      duration: null,
      priority: NakedToastPriority.assertive,
      interactive: true,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return NakedToastScope<ToastMessage>(
      controller: _controller,
      placement: widget.placement,
      toastBuilder: (context, toast, animation) =>
          _ToastCard(toast: toast, animation: animation),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          _TriggerButton(
            key: const ValueKey('toast.show.saved'),
            onPressed: _showSaved,
            text: 'Save draft',
            description: 'Polite status that replaces itself',
          ),
          _TriggerButton(
            key: const ValueKey('toast.show.archived'),
            onPressed: _showArchived,
            text: 'Archive conversation',
            description: 'Undo action, pauses on hover and focus',
          ),
          _TriggerButton(
            key: const ValueKey('toast.show.failed'),
            onPressed: _showFailed,
            text: 'Fail upload',
            description: 'Assertive alert that stays until closed',
          ),
          _TriggerButton(
            key: const ValueKey('toast.clear'),
            onPressed: _controller.clear,
            text: 'Clear all',
            description: 'Dismisses visible and queued toasts',
          ),
          Text(
            'Last result: $_lastResult; undo count: $_undoCount',
            key: const ValueKey('toast.result'),
            style: const TextStyle(color: Color(0xFF27272A)),
          ),
        ],
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.toast, required this.animation});

  final NakedToastState<ToastMessage> toast;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final message = toast.data;
    final isDanger = message.tone == ToastTone.danger;

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(animation),
        child: Container(
          key: ValueKey('toast.surface.${toast.id}'),
          width: 340,
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          decoration: BoxDecoration(
            color: isDanger ? const Color(0xFF7F1D1D) : const Color(0xFF18181B),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                // The scope announces semanticLabel; hide the repeated text.
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (message.description case final description?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              description,
                              style: const TextStyle(
                                color: Color(0xFFE4E4E7),
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (message.actionLabel case final label?) ...[
                _ToastButton(
                  key: ValueKey('toast.action.${toast.id}'),
                  onPressed: () {
                    message.onAction?.call();
                    toast.dismiss(NakedToastDismissReason.action);
                  },
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFBFDBFE),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _ToastButton(
                  key: ValueKey('toast.close.${toast.id}'),
                  semanticLabel: 'Dismiss notification',
                  onPressed: toast.dismiss,
                  child: const CustomPaint(
                    size: Size.square(12),
                    painter: _CloseGlyphPainter(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastButton extends StatelessWidget {
  const _ToastButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return NakedButton(
      onPressed: onPressed,
      semanticLabel: semanticLabel,
      builder: (context, state, child) => ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: state.when(
              pressed: const Color(0x33FFFFFF),
              hovered: const Color(0x1FFFFFFF),
              orElse: const Color(0x00FFFFFF),
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: state.isFocused
                  ? const Color(0xFF93C5FD)
                  : const Color(0x00FFFFFF),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(widthFactor: 1, child: child),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _CloseGlyphPainter extends CustomPainter {
  const _CloseGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE4E4E7)
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset.zero, Offset(size.width, size.height), paint)
      ..drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter oldDelegate) => false;
}

class _TriggerButton extends StatelessWidget {
  const _TriggerButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.description,
  });

  final VoidCallback onPressed;
  final String text;
  final String description;

  @override
  Widget build(BuildContext context) {
    return NakedButton(
      onPressed: onPressed,
      builder: (context, state, child) {
        const baseColor = Color(0xFF3D3D3D);
        final backgroundColor = state.when(
          pressed: baseColor.withValues(alpha: 0.8),
          hovered: baseColor.withValues(alpha: 0.9),
          orElse: baseColor,
        );

        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 200),
          width: 280,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.isFocused
                  ? const Color(0xFF2563EB)
                  : const Color(0x00000000),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
