import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/cupertino.dart'
    show
        CupertinoDynamicColor,
        cupertinoDesktopTextSelectionHandleControls,
        cupertinoTextSelectionHandleControls;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
// We import just what we need from Material/Cupertino to keep surface minimal,
// but we intentionally *opt in* to OS-adaptive selection/magnifier.
import 'package:flutter/material.dart'
    show
        TextMagnifier,
        materialTextSelectionHandleControls,
        desktopTextSelectionHandleControls;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'mixins/naked_mixins.dart';
import 'utilities/naked_state_scope.dart';
import 'utilities/state.dart';

/// Builds a text-field surface around the supplied [editableText] widget.
typedef NakedTextFieldBuilder =
    Widget Function(
      BuildContext context,
      NakedTextFieldState value,
      Widget editableText,
    );

/// Immutable view passed to [NakedTextField.builder].
class NakedTextFieldState extends NakedState {
  /// The current text value.
  final String text;

  /// Whether the text field has text content.
  final bool hasText;

  /// Whether the text field is read-only.
  final bool isReadOnly;

  /// Creates an immutable snapshot of text-field state.
  NakedTextFieldState({
    required super.states,
    required this.text,
    required this.hasText,
    required this.isReadOnly,
  });

  /// Returns the nearest [NakedTextFieldState] provided by [NakedStateScope].
  static NakedTextFieldState of(BuildContext context) => NakedState.of(context);

  /// Returns the nearest [NakedTextFieldState] if one is available.
  static NakedTextFieldState? maybeOf(BuildContext context) =>
      NakedState.maybeOf(context);

  /// Returns the [WidgetStatesController] from the nearest scope.
  static WidgetStatesController controllerOf(BuildContext context) =>
      NakedState.controllerOf<NakedTextFieldState>(context);

  /// Returns the [WidgetStatesController] from the nearest scope, if any.
  static WidgetStatesController? maybeControllerOf(BuildContext context) =>
      NakedState.maybeControllerOf<NakedTextFieldState>(context);

  /// Whether the text field is empty.
  bool get isEmpty => !hasText;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NakedTextFieldState &&
        statesEqual(other) &&
        other.text == text &&
        other.hasText == hasText &&
        other.isReadOnly == isReadOnly;
  }

  @override
  int get hashCode => Object.hash(statesHashCode, text, hasText, isReadOnly);
}

/// Headless, builder-first text input built on [EditableText].
///
/// Exposes native-feeling defaults while remaining design-system agnostic.
/// Renders no visuals; use [builder] to style or decorate its editable child.
///
/// ```dart
/// NakedTextField(
///   controller: textController,
///   onChanged: (text) => print('Changed: $text'),
///   builder: (context, editableText) => Container(
///     decoration: BoxDecoration(border: Border.all()),
///     child: editableText,
///   ),
/// )
/// ```
///
/// See also:
/// - [EditableText], the underlying primitive text input.
/// - [TextField], the Material-styled text input for typical apps.
class NakedTextField extends StatefulWidget {
  /// Creates a headless text field backed by [EditableText].
  const NakedTextField({
    super.key,
    this.groupId = EditableText, // Keeps parity with EditableText default.
    this.controller,
    this.focusNode,
    this.undoController,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled = true,
    this.error = false,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorOpacityAnimates,
    this.cursorColor, // override adaptive color if needed
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.selectionControls, // override adaptive controls if needed
    this.onTap, // prefer this name for a field tap
    this.onTapAlwaysCalled = false,
    this.onTapChange,
    this.onTapOutside,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.onTapUpOutside,
    this.stylusHandwritingEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contextMenuBuilder,
    this.canRequestFocus = true,
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
    this.onHoverChange,
    this.onFocusChange,
    this.onPressChange,
    this.style,
    this.builder,
    this.ignorePointers,
    this.semanticLabel,
    this.semanticHint,
    this.semanticErrorText,
    this.strutStyle,
    this.excludeSemantics = false,
  }) : assert(obscuringCharacter.length == 1),
       smartDashesType =
           smartDashesType ??
           (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
       smartQuotesType =
           smartQuotesType ??
           (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
       assert(maxLines == null || maxLines > 0),
       assert(minLines == null || minLines > 0),
       assert(builder != null, 'NakedTextField requires a builder'),
       assert(
         (maxLines == null) || (minLines == null) || (maxLines >= minLines),
         "minLines can't be greater than maxLines",
       ),
       assert(
         !expands || (maxLines == null && minLines == null),
         'minLines and maxLines must be null when expands is true.',
       ),
       assert(
         !obscureText || maxLines == 1,
         'Obscured fields cannot be multiline.',
       ),
       assert(maxLength == null || maxLength > 0);

  /// The magnifier configuration (defaults to platform-appropriate).
  final TextMagnifierConfiguration? magnifierConfiguration;

  /// The controller for the text being edited.
  final TextEditingController? controller;

  /// The focus node for this widget.
  final FocusNode? focusNode;

  /// The undo/redo controller.
  final UndoHistoryController? undoController;

  /// The kind of keyboard to display for this field.
  final TextInputType? keyboardType;

  /// The action button to display on the platform keyboard.
  final TextInputAction? textInputAction;

  /// The automatic capitalization strategy for entered text.
  final TextCapitalization textCapitalization;

  /// How text is aligned horizontally within the field.
  final TextAlign textAlign;

  /// The direction used to interpret and render the text.
  final TextDirection? textDirection;

  /// Whether the field is read-only.
  final bool readOnly;

  /// Whether to show the cursor.
  final bool? showCursor;

  /// Whether the field requests focus when first built.
  final bool autofocus;

  /// The character used for obscuring text.
  final String obscuringCharacter;

  /// Whether to obscure text (for example, passwords).
  final bool obscureText;

  /// Whether to enable autocorrect.
  final bool autocorrect;

  /// The smart dashes type.
  final SmartDashesType smartDashesType;

  /// The smart quotes type.
  final SmartQuotesType smartQuotesType;

  /// Whether to enable suggestions.
  final bool enableSuggestions;

  /// The maximum number of lines.
  final int? maxLines;

  /// The minimum number of lines.
  final int? minLines;

  /// Whether the field expands vertically.
  final bool expands;

  /// The maximum character length.
  final int? maxLength;

  /// How to enforce the maximum length.
  final MaxLengthEnforcement? maxLengthEnforcement;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when editing is complete.
  final VoidCallback? onEditingComplete;

  /// Called when the form is submitted.
  final ValueChanged<String>? onSubmitted;

  /// Called for app private commands.
  final AppPrivateCommandCallback? onAppPrivateCommand;

  /// The input formatters to apply.
  final List<TextInputFormatter>? inputFormatters;

  /// Whether the field is enabled.
  final bool enabled;

  /// Whether the field has an error.
  final bool error;

  /// The width of the text cursor.
  final double cursorWidth;

  /// The cursor height, or null to derive it from the text style.
  final double? cursorHeight;

  /// The radius used to round the cursor corners.
  final Radius? cursorRadius;

  /// Whether cursor opacity changes are animated.
  final bool? cursorOpacityAnimates;

  /// The cursor color.
  ///
  /// If null, uses the ambient [DefaultSelectionStyle.cursorColor] before the
  /// platform fallback.
  final Color? cursorColor;

  /// How selection highlights align vertically with text boxes.
  final ui.BoxHeightStyle selectionHeightStyle;

  /// How selection highlights align horizontally with text boxes.
  final ui.BoxWidthStyle selectionWidthStyle;

  /// Keyboard appearance (iOS).
  final Brightness? keyboardAppearance;

  /// Padding kept visible when scrolling the field into view.
  final EdgeInsets scrollPadding;

  /// When drag gestures begin for scrolling and text selection.
  final DragStartBehavior dragStartBehavior;

  /// The controller for the field's scroll position.
  final ScrollController? scrollController;

  /// The physics used by the field's scrollable content.
  final ScrollPhysics? scrollPhysics;

  /// Clipping behavior for the underlying [EditableText].
  final Clip clipBehavior;

  /// Whether users can select, cut, copy, and paste text.
  final bool enableInteractiveSelection;

  /// Controls the platform text-selection handles and toolbar.
  final TextSelectionControls? selectionControls;

  /// Builds the context menu shown for text-selection actions.
  final EditableTextContextMenuBuilder? contextMenuBuilder;

  /// Called when the field is tapped.
  final GestureTapCallback? onTap;

  /// Whether [onTap] runs for every tap instead of only the first tap series.
  final bool onTapAlwaysCalled;

  /// Called when the field's pressed state changes.
  final ValueChanged<bool>? onTapChange;

  /// Called for a pointer-down event outside the field's tap region.
  final TapRegionCallback? onTapOutside;

  /// Called for a pointer-up event outside the field's tap region.
  final TapRegionUpCallback? onTapUpOutside;

  /// Called when the pointer enters or leaves the field.
  final ValueChanged<bool>? onHoverChange;

  /// Called when the field's aggregate pressed state changes.
  final ValueChanged<bool>? onPressChange;

  /// Hints that identify the field for platform autofill services.
  final Iterable<String>? autofillHints;

  /// Configures insertion of rich content from an input method.
  final ContentInsertionConfiguration? contentInsertionConfiguration;

  /// Focus management
  final bool canRequestFocus;

  /// Called when focus changes.
  final ValueChanged<bool>? onFocusChange;

  /// Restoration
  final String? restorationId;

  /// Whether stylus handwriting input is enabled.
  final bool stylusHandwritingEnabled;

  /// Whether the IME may use entered text for personalized learning.
  final bool enableIMEPersonalizedLearning;

  /// Spell check
  final SpellCheckConfiguration? spellCheckConfiguration;

  /// Grouping for IME (matches [EditableText]).
  final Object groupId;

  /// Text style override (else derives from [DefaultTextStyle]).
  final TextStyle? style;

  /// Defines the strut
  final StrutStyle? strutStyle;

  /// Whether to ignore pointers.
  final bool? ignorePointers;

  /// Builds the visual wrapper around the underlying [EditableText].
  final NakedTextFieldBuilder? builder;

  /// The accessibility label for the field.
  final String? semanticLabel;

  /// The accessibility hint that describes how to use the field.
  final String? semanticHint;

  /// The accessibility announcement for the current validation error.
  final String? semanticErrorText;

  /// Whether to exclude this widget from the semantic tree.
  ///
  /// When true, the widget and its children are hidden from accessibility services.
  final bool excludeSemantics;

  @override
  State<NakedTextField> createState() => _NakedTextFieldState();
}

class _NakedTextFieldState extends State<NakedTextField>
    with
        RestorationMixin,
        WidgetStatesMixin<NakedTextField>,
        FocusNodeMixin<NakedTextField>
    implements TextSelectionGestureDetectorBuilderDelegate, AutofillClient {
  static const Color _neutralBgCursor = Color(0xFFBDBDBD);
  static const int _iOSHorizontalOffset = -2;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  FocusNode? get widgetProvidedNode => widget.focusNode;

  @override
  ValueChanged<bool>? get onFocusChange => _handleFocusChange;

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder = _NakedSelectionGestureDetectorBuilder(
      state: this,
    );

    if (widget.controller == null) {
      _createLocalController();
    }

    _effectiveFocusNode.canRequestFocus =
        widget.canRequestFocus && widget.enabled;
    if (widget.controller != null) {
      _updateAttachedController(widget.controller);
    } else if (_controller != null && !restorePending) {
      _updateAttachedController(_controller!.value);
    }
  }

  bool _canRequestFocusFor(NavigationMode? mode) {
    switch (mode) {
      case NavigationMode.directional:
        return widget.canRequestFocus;
      case NavigationMode.traditional:
      case null:
        return widget.canRequestFocus && widget.enabled;
    }
  }

  void _createLocalController([TextEditingValue? value]) {
    assert(_controller == null);
    _controller = value == null
        ? RestorableTextEditingController()
        : RestorableTextEditingController.fromValue(value);
    if (!restorePending) {
      registerForRestoration(_controller!, 'controller');
    }
  }

  void _updateAttachedController(TextEditingController? newController) {
    _detachControllerListener?.call();
    _detachControllerListener = null;

    if (newController != null) {
      newController.addListener(_handleControllerChanged);
      _detachControllerListener = () {
        newController.removeListener(_handleControllerChanged);
      };
    }
  }

  void _requestKeyboard() => _editableText?.requestKeyboard();

  void _handleControllerChanged() {
    if (!mounted) return;
    // ignore: no-empty-block
    setState(() {});
  }

  void _handleFocusChange(bool focused) {
    updateFocusState(focused, widget.onFocusChange);
  }

  void _handlePressChange(bool pressed) {
    updatePressState(pressed, (value) {
      widget.onTapChange?.call(value);
      widget.onPressChange?.call(value);
    });
  }

  var _enabledEpoch = 0;

  void _handleEnabledChange(NakedTextField oldWidget) {
    if (oldWidget.enabled == widget.enabled) return;
    final epoch = ++_enabledEpoch;
    if (widget.enabled || !updatePressState(false, null)) return;

    final tapCallback = widget.onTapChange;
    final pressCallback = widget.onPressChange;
    if (tapCallback == null && pressCallback == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _enabledEpoch == epoch && !widget.enabled && isDisabled) {
        tapCallback?.call(false);
        pressCallback?.call(false);
      }
    });
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }
    if (cause == SelectionChangedCause.keyboard) return false;
    if (!widget.enabled) return false;
    if (widget.readOnly && _effectiveController.selection.isCollapsed) {
      return false;
    }
    switch (cause) {
      case SelectionChangedCause.longPress:
      case SelectionChangedCause.stylusHandwriting:
        return true;
      case SelectionChangedCause.doubleTap:
      case SelectionChangedCause.drag:
      case SelectionChangedCause.forcePress:
      case SelectionChangedCause.toolbar:
      case SelectionChangedCause.keyboard:
      case SelectionChangedCause.tap:
      case null:
        break;
    }

    return _effectiveController.text.isNotEmpty;
  }

  void _handleSelectionChanged(
    TextSelection selection,
    SelectionChangedCause? cause,
  ) {
    final willShow = _shouldShowSelectionHandles(cause);
    if (willShow != _showSelectionHandles) {
      setState(() => _showSelectionHandles = willShow);
    }

    if (cause == SelectionChangedCause.longPress) {
      _editableText?.bringIntoView(selection.extent);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (cause == SelectionChangedCause.drag) {
          _editableText?.hideToolbar();
        }
        break;
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        break;
    }
  }

  void _handleSelectionHandleTapped() {
    if (_effectiveController.selection.isCollapsed) {
      _editableText?.toggleToolbar();
    }
  }

  void _handleMouseEnter(PointerEnterEvent _) =>
      updateHoverState(true, widget.onHoverChange);

  void _handleMouseExit(PointerExitEvent _) =>
      updateHoverState(false, widget.onHoverChange);

  @override
  void initializeWidgetStates() {
    updateDisabledState(!widget.enabled);
    updateErrorState(widget.error);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navMode = MediaQuery.maybeNavigationModeOf(context);
    _effectiveFocusNode.canRequestFocus = _canRequestFocusFor(_navMode);
  }

  @override
  void didUpdateWidget(NakedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    updateDisabledState(!widget.enabled);
    updateErrorState(widget.error);
    _handleEnabledChange(oldWidget);

    if (widget.controller == null && oldWidget.controller != null) {
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      _controller!.value.removeListener(_handleControllerChanged);
      unregisterFromRestoration(_controller!);
      _controller!.dispose();
      _controller = null;
    }

    final TextEditingController? nextController =
        widget.controller ?? (!restorePending ? _controller?.value : null);
    _updateAttachedController(nextController);

    _effectiveFocusNode.canRequestFocus = _canRequestFocusFor(_navMode);

    if (_effectiveFocusNode.hasFocus &&
        widget.readOnly != oldWidget.readOnly &&
        widget.enabled) {
      final willShow = _shouldShowSelectionHandles(
        SelectionChangedCause.longPress,
      );
      if (willShow != _showSelectionHandles) {
        _showSelectionHandles = willShow;
      }
    }
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (_controller != null) {
      registerForRestoration(_controller!, 'controller');
      _updateAttachedController(_controller!.value);
    }
  }

  @override
  void dispose() {
    _detachControllerListener?.call();
    _detachControllerListener = null;
    _controller?.dispose();
    super.dispose();
  }

  @override
  void autofill(TextEditingValue newEditingValue) =>
      _editableText?.autofill(newEditingValue);

  RestorableTextEditingController? _controller;

  VoidCallback? _detachControllerListener;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!.value;

  FocusNode get _effectiveFocusNode => effectiveFocusNode;

  MaxLengthEnforcement get _effectiveMaxLengthEnforcement =>
      widget.maxLengthEnforcement ??
      LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement(
        defaultTargetPlatform,
      );

  late TextSelectionGestureDetectorBuilder _selectionGestureDetectorBuilder;

  bool _showSelectionHandles = false;

  NavigationMode? _navMode;

  @override
  late bool forcePressEnabled;

  @override
  bool get selectionEnabled =>
      widget.enabled && widget.enableInteractiveSelection;

  EditableTextState? get _editableText => editableTextKey.currentState;

  @override
  String get autofillId {
    // Return empty string if EditableText hasn't built yet.
    // This can happen during the first frame before the child widget builds.
    final editableText = _editableText;
    if (editableText == null) return '';
    return editableText.autofillId;
  }

  @override
  TextInputConfiguration get textInputConfiguration {
    final editableText = _editableText;
    // Return a minimal configuration if EditableText hasn't built yet.
    if (editableText == null) {
      return const TextInputConfiguration();
    }

    final List<String>? hints = widget.autofillHints?.toList(growable: false);
    final AutofillConfiguration ac = hints != null
        ? AutofillConfiguration(
            uniqueIdentifier: autofillId,
            autofillHints: hints,
            currentEditingValue: _effectiveController.value,
            hintText: null,
          )
        : AutofillConfiguration.disabled;

    return editableText.textInputConfiguration.copyWith(
      autofillConfiguration: ac,
    );
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));

    final Brightness keyboardAppearance =
        widget.keyboardAppearance ?? Brightness.light;

    final controller = _effectiveController;
    final focusNode = _effectiveFocusNode;

    final formatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(
          widget.maxLength,
          maxLengthEnforcement: _effectiveMaxLengthEnforcement,
        ),
    ];

    final SpellCheckConfiguration effectiveSpellCheck =
        widget.spellCheckConfiguration ??
        const SpellCheckConfiguration.disabled();

    final DefaultSelectionStyle selectionStyle = DefaultSelectionStyle.of(
      context,
    );
    final Color? cursorColor = CupertinoDynamicColor.maybeResolve(
      widget.cursorColor ?? selectionStyle.cursorColor,
      context,
    );
    final Color? selectionColor = CupertinoDynamicColor.maybeResolve(
      selectionStyle.selectionColor,
      context,
    );

    final _PlatformDefaults p = _PlatformDefaults.resolve(
      context: context,
      cursorColorOverride: cursorColor,
      selectionColorOverride: selectionColor,
      cursorRadiusOverride: widget.cursorRadius,
      cursorOpacityAnimatesOverride: widget.cursorOpacityAnimates,
    );
    forcePressEnabled = p.forcePressEnabled;

    final TextSelectionControls? controls = widget.enableInteractiveSelection
        ? (widget.selectionControls ?? p.platformSelectionControls)
        : null;

    final TextMagnifierConfiguration magnifier =
        widget.magnifierConfiguration ??
        TextMagnifier.adaptiveMagnifierConfiguration;

    Widget editable = Builder(
      builder: (context) {
        final TextStyle textStyle =
            widget.style ?? DefaultTextStyle.of(context).style;

        return EditableText(
          key: editableTextKey,
          controller: controller,
          focusNode: focusNode,
          readOnly: widget.readOnly || !widget.enabled,
          obscuringCharacter: widget.obscuringCharacter,
          obscureText: widget.obscureText,
          autocorrect: widget.autocorrect,
          smartDashesType: widget.smartDashesType,
          smartQuotesType: widget.smartQuotesType,
          enableSuggestions: widget.enableSuggestions,
          style: textStyle,
          strutStyle: widget.strutStyle,
          cursorColor: p.cursorColor,
          backgroundCursorColor: _neutralBgCursor,
          textAlign: widget.textAlign,
          textDirection: widget.textDirection,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          expands: widget.expands,
          autofocus: widget.autofocus,
          showCursor: widget.showCursor,
          showSelectionHandles: _showSelectionHandles,
          selectionColor: focusNode.hasFocus ? p.selectionColor : null,
          selectionControls: controls,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          onChanged: widget.onChanged,
          onEditingComplete: widget.onEditingComplete,
          onSubmitted: widget.onSubmitted,
          onAppPrivateCommand: widget.onAppPrivateCommand,
          onSelectionChanged: _handleSelectionChanged,
          onSelectionHandleTapped: _handleSelectionHandleTapped,
          groupId: widget.groupId,
          onTapOutside: widget.onTapOutside,
          onTapUpOutside: widget.onTapUpOutside,
          inputFormatters: formatters,
          rendererIgnoresPointer: true,
          cursorWidth: widget.cursorWidth,
          cursorHeight: widget.cursorHeight,
          cursorRadius: p.cursorRadius,
          cursorOpacityAnimates: p.cursorOpacityAnimates,
          cursorOffset: p.cursorOffset,
          paintCursorAboveText: p.paintCursorAboveText,
          selectionHeightStyle: widget.selectionHeightStyle,
          selectionWidthStyle: widget.selectionWidthStyle,
          scrollPadding: widget.scrollPadding,
          keyboardAppearance: keyboardAppearance,
          dragStartBehavior: widget.dragStartBehavior,
          enableInteractiveSelection: widget.enableInteractiveSelection,
          scrollController: widget.scrollController,
          scrollPhysics: widget.scrollPhysics,
          autofillClient: this,
          clipBehavior: widget.clipBehavior,
          restorationId: widget.restorationId == null
              ? null
              : '${widget.restorationId!}.editable',
          stylusHandwritingEnabled: widget.stylusHandwritingEnabled,
          enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
          contentInsertionConfiguration: widget.contentInsertionConfiguration,
          contextMenuBuilder: widget.contextMenuBuilder,
          spellCheckConfiguration: effectiveSpellCheck,
          magnifierConfiguration: magnifier,
          undoController: widget.undoController,
        );
      },
    );

    editable = TextFieldTapRegion(
      child: IgnorePointer(
        ignoring: widget.ignorePointers ?? !widget.enabled,
        child: RepaintBoundary(
          child: UnmanagedRestorationScope(bucket: bucket, child: editable),
        ),
      ),
    );

    void _semanticTap() {
      widget.onTap?.call();
      if (!widget.readOnly) {
        final c = controller;
        if (!c.selection.isValid) {
          c.selection = TextSelection.collapsed(offset: c.text.length);
        }
        _requestKeyboard();
      }
    }

    String? _semanticHint() {
      final errorText = widget.error ? widget.semanticErrorText : null;
      if (widget.semanticHint == null || widget.semanticHint!.isEmpty) {
        return errorText;
      }
      if (errorText == null || errorText.isEmpty) {
        return widget.semanticHint;
      }

      return '${widget.semanticHint}\n$errorText';
    }

    Widget withSemantics(Widget child) {
      return widget.excludeSemantics
          ? ExcludeSemantics(child: child)
          : MergeSemantics(
              child: Semantics(
                enabled: widget.enabled,
                liveRegion: widget.error && widget.semanticErrorText != null,
                readOnly: widget.readOnly || !widget.enabled,
                focusable: widget.enabled,
                focused: widget.enabled ? focusNode.hasFocus : null,
                obscured: widget.obscureText,
                multiline: widget.maxLines != 1,
                maxValueLength: widget.maxLength,
                currentValueLength: controller.text.length,
                label: widget.semanticLabel,
                value: widget.obscureText ? null : controller.text,
                hint: _semanticHint(),
                onFocus: widget.enabled && focusNode.canRequestFocus
                    ? focusNode.requestFocus
                    : null,
                onTap: (widget.enabled && !widget.readOnly)
                    ? _semanticTap
                    : null,
                child: child,
              ),
            );
    }

    final textFieldState = NakedTextFieldState(
      states: {...widgetStates, if (focusNode.hasFocus) WidgetState.focused},
      text: controller.text,
      hasText: controller.text.isNotEmpty,
      isReadOnly: widget.readOnly,
    );

    final Widget content = NakedStateScopeBuilder(
      value: textFieldState,
      child: editable,
      builder: (context, value, child) =>
          withSemantics(widget.builder!(context, value, child!)),
    );

    final Widget detector = _selectionGestureDetectorBuilder
        .buildGestureDetector(
          behavior: HitTestBehavior.translucent,
          child: content,
        );

    final Widget maybeMouseRegion = widget.enabled
        ? MouseRegion(
            onEnter: _handleMouseEnter,
            onExit: _handleMouseExit,
            cursor: SystemMouseCursors.text,
            child: detector,
          )
        : detector;

    return maybeMouseRegion;
  }
}

class _NakedSelectionGestureDetectorBuilder
    extends TextSelectionGestureDetectorBuilder {
  final _NakedTextFieldState _state;

  _NakedSelectionGestureDetectorBuilder({required _NakedTextFieldState state})
    : _state = state,
      super(delegate: state);

  @override
  void onUserTap() {
    if (!_state.widget.enabled) return;
    _state.widget.onTap?.call();

    if (!_state.widget.readOnly) {
      final c = _state._effectiveController;
      if (!c.selection.isValid) {
        c.selection = TextSelection.collapsed(offset: c.text.length);
      }
      _state._requestKeyboard();
    }
  }

  @override
  void onTapDown(TapDragDownDetails details) {
    if (!_state.widget.enabled) return;
    super.onTapDown(details);
    _state._handlePressChange(true);
  }

  @override
  void onTapTrackReset() {
    super.onTapTrackReset();
    if (!_state.widget.enabled) return;
    _state._handlePressChange(false);
  }

  @override
  void onForcePressStart(ForcePressDetails details) {
    if (!_state.widget.enabled) return;
    super.onForcePressStart(details);
  }

  @override
  void onForcePressEnd(ForcePressDetails details) {
    if (!_state.widget.enabled) return;
    super.onForcePressEnd(details);
  }

  @override
  void onDoubleTapDown(TapDragDownDetails details) {
    if (!_state.widget.enabled) return;
    super.onDoubleTapDown(details);
    _state._handlePressChange(false);
  }

  @override
  void onTripleTapDown(TapDragDownDetails details) {
    if (!_state.widget.enabled) return;
    super.onTripleTapDown(details);
    _state._handlePressChange(false);
  }

  @override
  void onDragSelectionStart(TapDragStartDetails details) {
    if (!_state.widget.enabled) return;
    super.onDragSelectionStart(details);
    _state._handlePressChange(false);
  }

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    if (!_state.widget.enabled) return;
    super.onSingleTapUp(details);
    _state._handlePressChange(false);
  }

  @override
  void onSingleTapCancel() {
    super.onSingleTapCancel();
    if (!_state.widget.enabled) return;
    _state._handlePressChange(false);
  }

  @override
  bool get onUserTapAlwaysCalled => _state.widget.onTapAlwaysCalled;
}

class _PlatformDefaults {
  final bool forcePressEnabled;
  final bool paintCursorAboveText;
  final bool cursorOpacityAnimates;
  final Color cursorColor;
  final Color selectionColor;
  final Radius? cursorRadius;
  final Offset? cursorOffset;
  final TextSelectionControls? platformSelectionControls;

  static const Color _androidBlue = Color(0xFF2196F3);

  const _PlatformDefaults({
    required this.forcePressEnabled,
    required this.paintCursorAboveText,
    required this.cursorOpacityAnimates,
    required this.cursorColor,
    required this.selectionColor,
    this.cursorRadius,
    this.cursorOffset,
    this.platformSelectionControls,
  });

  static _PlatformDefaults resolve({
    required BuildContext context,
    Color? cursorColorOverride,
    Color? selectionColorOverride,
    Radius? cursorRadiusOverride,
    bool? cursorOpacityAnimatesOverride,
  }) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return _PlatformDefaults(
          forcePressEnabled: true,
          paintCursorAboveText: true,
          cursorOpacityAnimates: cursorOpacityAnimatesOverride ?? true,
          cursorColor: cursorColorOverride ?? const Color(0xFF007AFF),
          selectionColor:
              selectionColorOverride ?? const Color(0x66007AFF), // ~40% alpha
          cursorRadius: cursorRadiusOverride ?? const Radius.circular(2),
          cursorOffset: Offset(
            _NakedTextFieldState._iOSHorizontalOffset /
                MediaQuery.devicePixelRatioOf(context),
            0,
          ),
          platformSelectionControls: cupertinoTextSelectionHandleControls,
        );
      case TargetPlatform.macOS:
        return _PlatformDefaults(
          forcePressEnabled: false,
          paintCursorAboveText: true,
          cursorOpacityAnimates: cursorOpacityAnimatesOverride ?? false,
          cursorColor: cursorColorOverride ?? const Color(0xFF007AFF),
          selectionColor: selectionColorOverride ?? const Color(0x66007AFF),
          cursorRadius: cursorRadiusOverride ?? const Radius.circular(2),
          cursorOffset: Offset(
            _NakedTextFieldState._iOSHorizontalOffset /
                MediaQuery.devicePixelRatioOf(context),
            0,
          ),
          platformSelectionControls:
              cupertinoDesktopTextSelectionHandleControls,
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return _PlatformDefaults(
          forcePressEnabled: false,
          paintCursorAboveText: false,
          cursorOpacityAnimates: cursorOpacityAnimatesOverride ?? false,
          cursorColor: cursorColorOverride ?? _androidBlue,
          selectionColor:
              selectionColorOverride ?? _androidBlue.withValues(alpha: 0.40),
          cursorRadius: cursorRadiusOverride,
          cursorOffset: null,
          platformSelectionControls: materialTextSelectionHandleControls,
        );
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return _PlatformDefaults(
          forcePressEnabled: false,
          paintCursorAboveText: false,
          cursorOpacityAnimates: cursorOpacityAnimatesOverride ?? false,
          cursorColor: cursorColorOverride ?? _androidBlue,
          selectionColor:
              selectionColorOverride ?? _androidBlue.withValues(alpha: 0.40),
          cursorRadius: cursorRadiusOverride,
          cursorOffset: null,
          platformSelectionControls: desktopTextSelectionHandleControls,
        );
    }
  }
}
