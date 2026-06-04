import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinCodeField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final int length;
  final bool obscureDigits;
  final bool autofocus;
  final bool enabled;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onCompleted;

  const PinCodeField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.validator,
    this.length = 5,
    this.obscureDigits = true,
    this.autofocus = false,
    this.enabled = true,
    this.textInputAction = TextInputAction.done,
    this.focusNode,
    this.autofillHints = const <String>[],
    this.onChanged,
    this.onSubmitted,
    this.onCompleted,
  });

  @override
  State<PinCodeField> createState() => _PinCodeFieldState();
}

class _PinCodeFieldState extends State<PinCodeField> {
  final _formFieldKey = GlobalKey<FormFieldState<String>>();
  bool _isInternalTextUpdate = false;
  bool _ownsFocusNode = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _attachFocusNode(widget.focusNode);
    widget.controller.addListener(_handleControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final normalized = _normalize(widget.controller.text);
      if (normalized != widget.controller.text) {
        _replaceControllerText(normalized);
      }
      _formFieldKey.currentState?.didChange(normalized);
    });
  }

  @override
  void didUpdateWidget(covariant PinCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocusNode();
      _attachFocusNode(widget.focusNode);
    }

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _formFieldKey.currentState?.didChange(_normalize(widget.controller.text));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    _detachFocusNode();
    super.dispose();
  }

  void _attachFocusNode(FocusNode? node) {
    if (node != null) {
      _focusNode = node;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_handleFocusChanged);
  }

  void _detachFocusNode() {
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _normalize(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length <= widget.length) {
      return digitsOnly;
    }
    return digitsOnly.substring(0, widget.length);
  }

  void _replaceControllerText(String value) {
    if (widget.controller.text == value) return;
    _isInternalTextUpdate = true;
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _isInternalTextUpdate = false;
  }

  void _handleControllerChanged() {
    if (_isInternalTextUpdate) return;

    final normalized = _normalize(widget.controller.text);
    if (normalized != widget.controller.text) {
      _replaceControllerText(normalized);
    }

    _formFieldKey.currentState?.didChange(normalized);
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTextChanged(String value) {
    final normalized = _normalize(value);
    if (normalized != value) {
      _replaceControllerText(normalized);
    }

    _formFieldKey.currentState?.didChange(normalized);
    widget.onChanged?.call(normalized);

    if (normalized.length == widget.length) {
      widget.onCompleted?.call();
    }
  }

  void _handleSubmitted() {
    widget.onSubmitted?.call(_normalize(widget.controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        FormField<String>(
          key: _formFieldKey,
          initialValue: _normalize(widget.controller.text),
          validator: widget.validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          builder: (field) {
            final value = _normalize(widget.controller.text);
            final hasError = field.hasError;
            final activeIndex = value.length == widget.length
                ? widget.length - 1
                : value.length;
            final surfaceColor =
                theme.inputDecorationTheme.fillColor ??
                theme.colorScheme.surface;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.enabled
                      ? () => _focusNode.requestFocus()
                      : null,
                  child: Semantics(
                    textField: true,
                    enabled: widget.enabled,
                    label: widget.label,
                    hint: widget.hint,
                    value: '${value.length}/${widget.length}',
                    child: ExcludeSemantics(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 6.0;
                          final fallbackWidth =
                              (widget.length * 50.0) +
                              ((widget.length - 1) * spacing);
                          final availableWidth = constraints.maxWidth.isFinite
                              ? constraints.maxWidth
                              : fallbackWidth;
                          final computed =
                              (availableWidth -
                                  ((widget.length - 1) * spacing)) /
                              widget.length;
                          final bubbleSize = computed
                              .clamp(40.0, 50.0)
                              .toDouble();

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(widget.length, (index) {
                              final isFilled = index < value.length;
                              final isActive =
                                  _focusNode.hasFocus && index == activeIndex;
                              final borderColor = hasError
                                  ? theme.colorScheme.error
                                  : (isActive
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor.withValues(
                                            alpha: 0.9,
                                          ));
                              final fillColor = hasError
                                  ? theme.colorScheme.error.withValues(
                                      alpha: theme.brightness == Brightness.dark
                                          ? 0.18
                                          : 0.08,
                                    )
                                  : (isFilled
                                        ? theme.colorScheme.primary.withValues(
                                            alpha:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? 0.2
                                                : 0.08,
                                          )
                                        : surfaceColor);

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOutCubic,
                                width: bubbleSize,
                                height: bubbleSize,
                                margin: EdgeInsets.only(
                                  right: index == widget.length - 1
                                      ? 0
                                      : spacing,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: fillColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: isActive ? 2 : 1.2,
                                  ),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 140),
                                  child: !isFilled
                                      ? const SizedBox.shrink()
                                      : widget.obscureDigits
                                      ? Container(
                                          key: ValueKey('dot_$index'),
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: theme
                                                .textTheme
                                                .bodyLarge
                                                ?.color,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : Text(
                                          value[index],
                                          key: ValueKey(
                                            'digit_${index}_${value[index]}',
                                          ),
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 1,
                  height: 1,
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: widget.textInputAction,
                    autofillHints: widget.autofillHints,
                    enableSuggestions: false,
                    autocorrect: false,
                    enableIMEPersonalizedLearning: false,
                    maxLength: widget.length,
                    showCursor: false,
                    cursorColor: Colors.transparent,
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 0.01,
                      height: 0.01,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    onChanged: _handleTextChanged,
                    onFieldSubmitted: (_) => _handleSubmitted(),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      counterText: '',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasError && (field.errorText?.isNotEmpty ?? false))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      field.errorText!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
