// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Button on the rule-based style model.
///
/// Rewritten from cupertino_ui lib/src/button.dart (v1.1.3). Default values
/// are the original's (constants.dart, button.dart build). The widget
/// structure (MouseRegion > FocusableActionDetector > RawGestureDetector >
/// Semantics > ConstrainedBox > FadeTransition > DecoratedBox > Padding >
/// Align > DefaultTextStyle > IconTheme) and the press animation are kept
/// as they were; only where values come from changed.
library;

import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoButtonSize,
        CupertinoColors,
        CupertinoDynamicColor,
        CupertinoUserInterfaceLevelData,
        kCupertinoButtonTapMoveSlop,
        kCupertinoFocusColorBrightness,
        kCupertinoFocusColorOpacity,
        kCupertinoFocusColorSaturation;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_adapter.dart';
import 'engine/engine.dart';
import 'engine/padding_scaler.dart';
import 'engine/widgets.dart';
import 'style_library.dart';

export 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButtonSize;

part 'button.g.dart';

// ButtonSize, ButtonAppearance, ButtonField, ButtonDims, the rule classes,
// the library defaults (buttonDefaults), buttonStyle and buttonMinterm are
// generated from packages/style_codegen/specs/cupertino/button.dart into
// button.g.dart.

// Original constants (cupertino_ui constants.dart), repeated here as rule
// values.
const double _kDefaultIconSize = 20.0; // kButtonDefaultIconSize

const Set<ButtonAppearance> _plain = <ButtonAppearance>{ButtonAppearance.plain};


/// The original's focus ring color for a base color: [base] at
/// `kCupertinoFocusColorOpacity`, with the focus lightness and saturation.
Color cupertinoFocusRingColor(Color base) =>
    HSLColor.fromColor(replaceAlpha(base, kCupertinoFocusColorOpacity))
        .withLightness(kCupertinoFocusColorBrightness)
        .withSaturation(kCupertinoFocusColorSaturation)
        .toColor();

/// The default focus ring of a button state as a callback: the ring of
/// the resolved background, or of activeBlue in the state's environment
/// (the original forgot to resolve activeBlue). The widget computes the
/// same value when no rule sets focusColor; a theme can write it as a rule
/// (`ButtonRule.always(style: .derive(focusColor:
/// .computed(defaultButtonFocusColor)))`) and refine it like any
/// other rule. It is not in [buttonDefaults]: that would make focusColor a
/// resolved field that follows every background change, which changes
/// what "a rule changes only the background" means for every rule.
Color defaultButtonFocusColor(ButtonView s) =>
    cupertinoFocusRingColor(s.field(.backgroundColor) ?? s.resolveColor(CupertinoColors.activeBlue));

/// The widget states the original CupertinoButton passes to a
/// `WidgetStateMouseCursor`: disabled, pressed (tap in progress), focused.
Set<WidgetState> buttonMouseCursorStates(Minterm m) => <WidgetState>{
      if (m[ButtonDims.disabled] == true) WidgetState.disabled,
      if (m[ButtonDims.pressed] == true) WidgetState.pressed,
      if (m[ButtonDims.focused] == true) WidgetState.focused,
    };

/// A tinted background from a base color: the tinted opacity per
/// brightness, as one dynamic color (expanded per environment like any
/// other). Used by the `color:` parameter of tinted buttons, which the
/// original also tinted. A value, not a derive: it replaces the color's
/// alpha like the original's `withOpacity`.
Color tintedBackground(Color c) => mapColorVariants(
    c, (Color v, Brightness b) => replaceAlpha(v, b == Brightness.light ? kTintedFillOpacityLight : kTintedFillOpacityDark),
    debugLabel: c is CupertinoDynamicColor ? 'tinted ${c.toString().split('(').first}' : 'tinted color');

/// An iOS-style button whose look comes from rules: library defaults, then
/// [StyleTheme], the enclosing [StyleScope]s, the flat parameters below,
/// and finally [states].
class Button extends StatefulWidget {
  const Button({
    super.key,
    required this.child,
    this.appearance = ButtonAppearance.plain,
    this.sizeStyle = ButtonSize.large,
    this.padding,
    this.color,
    this.foregroundColor,
    this.disabledColor,
    this.minimumSize,
    this.pressedOpacity,
    this.borderRadius,
    this.alignment,
    this.focusColor,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.mouseCursor,
    this.onLongPress,
    this.states = const <ButtonRule>[],
    required this.onPressed,
  });

  /// Sugar for `appearance: ButtonAppearance.tinted`.
  const Button.tinted({
    super.key,
    required this.child,
    this.sizeStyle = ButtonSize.large,
    this.padding,
    this.color,
    this.foregroundColor,
    this.disabledColor,
    this.minimumSize,
    this.pressedOpacity,
    this.borderRadius,
    this.alignment,
    this.focusColor,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.mouseCursor,
    this.onLongPress,
    this.states = const <ButtonRule>[],
    required this.onPressed,
  }) : appearance = ButtonAppearance.tinted;

  /// Sugar for `appearance: ButtonAppearance.filled`.
  const Button.filled({
    super.key,
    required this.child,
    this.sizeStyle = ButtonSize.large,
    this.padding,
    this.color,
    this.foregroundColor,
    this.disabledColor,
    this.minimumSize,
    this.pressedOpacity,
    this.borderRadius,
    this.alignment,
    this.focusColor,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.mouseCursor,
    this.onLongPress,
    this.states = const <ButtonRule>[],
    required this.onPressed,
  }) : appearance = ButtonAppearance.filled;

  final Widget child;
  final ButtonAppearance appearance;
  final ButtonSize sizeStyle;

  /// backgroundColor in the enabled region of this appearance (the
  /// `tintedEnabled` / `filledEnabled` region of [ButtonRule.backgroundColor];
  /// on a plain button `plainAnyState`); tinted buttons apply the tinted
  /// opacity to it, as before. On a plain button the disabled state then
  /// shows [disabledColor] (default quaternarySystemFill), as before.
  ///
  /// Like every color parameter here: a plain [Color] is the same in every
  /// environment; a CupertinoDynamicColor picks its variant from the
  /// environment (brightness x contrast x elevation): it is expanded into
  /// one plain color per environment when the chain is built, the same way
  /// as in a theme rule. To change only some environments, add a rule with
  /// an environment condition to [states]; it may hold a plain color or a
  /// dynamic color (only the dynamic color's slots inside the condition are
  /// taken).
  final Color? color;

  /// foregroundColor in every state of this appearance (the enabled and
  /// disabled regions of [ButtonRule.foregroundColor], or `filledAnyState`).
  /// Plain color: same in every environment; dynamic color: expanded per
  /// environment.
  final Color? foregroundColor;

  /// backgroundColor in the disabled region (`tintedDisabled` /
  /// `filledDisabled` of [ButtonRule.backgroundColor]). On a plain button it
  /// only applies together with [color], as before. Plain color: same in every
  /// environment; dynamic color: expanded per environment.
  final Color? disabledColor;

  /// Each in every state (these fields have one region, so no region
  /// constructor: a rule under `ButtonWhen()`).
  final EdgeInsetsGeometry? padding;
  final Size? minimumSize;
  final double? pressedOpacity;
  final BorderRadius? borderRadius;
  final AlignmentGeometry? alignment;

  /// focusColor in every state. Plain color: same in every environment;
  /// dynamic color: expanded per environment. Unset: the ring of the
  /// background ([defaultButtonFocusColor]).
  final Color? focusColor;

  /// mouseCursor in every state. A map-form WidgetStateMouseCursor
  /// (`WidgetStateMouseCursor.fromMap`) is expanded into rules. Any other
  /// WidgetStateMouseCursor (`resolveWith`, `clickable`, ...) becomes one
  /// legacy rule: resolved with the states the original passes (disabled,
  /// pressed, focused) on every lookup, and a null result falls through
  /// to the theme and the defaults.
  final MouseCursor? mouseCursor;

  /// Call-site rules, after the flat parameters.
  final List<ButtonRule> states;

  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  bool get enabled => onPressed != null || onLongPress != null;

  /// See the original.
  static double tapMoveSlop() => switch (defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia => kCupertinoButtonTapMoveSlop,
        TargetPlatform.macOS || TargetPlatform.linux || TargetPlatform.windows => 0.0,
      };

  /// The call-site provider: one rule per flat parameter (a region rule
  /// where the field's default is partitioned, else a rule under
  /// `ButtonWhen()`), then [states].
  List<ButtonRule> callSiteRules() {
    final ButtonAppearance a = appearance;
    final List<ButtonRule> out = <ButtonRule>[];
    final Color? bg = color;
    if (bg != null) {
      switch (a) {
        case ButtonAppearance.plain:
          out
            ..add(ButtonRule.backgroundColor(plainAnyState: bg))
            // Compatibility mapping: the original painted disabledColor
            // (default quaternarySystemFill) on a disabled plain button
            // only when `color` was set. Finer than any default region, so
            // written with a condition.
            ..add(ButtonRule(const ButtonWhen(appearance: _plain, disabled: true),
                style: ButtonStyle(backgroundColor: disabledColor ?? CupertinoColors.quaternarySystemFill)));
        case ButtonAppearance.tinted:
          out.add(ButtonRule.backgroundColor(tintedEnabled: tintedBackground(bg)));
        case ButtonAppearance.filled:
          out.add(ButtonRule.backgroundColor(filledEnabled: bg));
      }
    }
    final Color? dis = disabledColor;
    if (dis != null && a != ButtonAppearance.plain) {
      out.add(a == ButtonAppearance.tinted
          ? ButtonRule.backgroundColor(tintedDisabled: dis)
          : ButtonRule.backgroundColor(filledDisabled: dis));
    }
    final Color? fg = foregroundColor;
    if (fg != null) {
      out.add(switch (a) {
        ButtonAppearance.plain => ButtonRule.foregroundColor(plainEnabled: fg, plainDisabled: fg),
        ButtonAppearance.tinted => ButtonRule.foregroundColor(tintedEnabled: fg, tintedDisabled: fg),
        ButtonAppearance.filled => ButtonRule.foregroundColor(filledAnyState: fg),
      });
    }
    const ButtonWhen every = ButtonWhen();
    if (focusColor != null) {
      out.add(ButtonRule(every, style: ButtonStyle(focusColor: focusColor)));
    }
    if (padding != null) {
      out.add(ButtonRule(every, style: ButtonStyle(padding: padding)));
    }
    if (borderRadius != null) {
      out.add(ButtonRule(every, style: ButtonStyle(borderRadius: borderRadius)));
    }
    if (minimumSize != null) {
      out.add(ButtonRule(every, style: ButtonStyle(minimumSize: minimumSize)));
    }
    if (alignment != null) {
      out.add(ButtonRule(every, style: ButtonStyle(alignment: alignment)));
    }
    if (pressedOpacity != null) {
      out.add(ButtonRule(every, style: ButtonStyle(pressedOpacity: pressedOpacity)));
    }
    final MouseCursor? cursor = mouseCursor;
    if (cursor != null) {
      if (cursor is WidgetStateProperty<MouseCursor?>) {
        final WidgetStateProperty<MouseCursor?> p = cursor as WidgetStateProperty<MouseCursor?>;
        if (isExpandableWidgetStateProperty(p)) {
          out.addAll(buttonRulesFromWidgetStates(mouseCursor: p));
        } else {
          out.add(ButtonRule._legacy(ButtonField.mouseCursor, WidgetStatePropertyRule(p, buttonMouseCursorStates)));
        }
      } else {
        out.add(ButtonRule.mouseCursor(enabled: cursor, disabled: cursor));
      }
    }
    out.addAll(states);
    return out;
  }

  @override
  State<Button> createState() => _ButtonWidgetState();

  /// The resolved style of a button at any state (design doc 7.6): the
  /// defaults, the theme and scopes visible at [context], then [states].
  /// Pass `states: button.callSiteRules()` to include an instance's flat
  /// parameters. Delegates to the generated [resolveButtonStyle] (a
  /// generator can't add a static member to this hand-written class).
  static ButtonStyle resolveStyle(
    BuildContext context, {
    ButtonAppearance appearance = ButtonAppearance.plain,
    ButtonSize sizeStyle = ButtonSize.large,
    bool disabled = false,
    bool pressed = false,
    bool focused = false,
    Brightness? brightness,
    bool? highContrast,
    CupertinoUserInterfaceLevelData? interfaceLevel,
    List<ButtonRule> states = const <ButtonRule>[],
  }) =>
      resolveButtonStyle(context,
          appearance: appearance,
          sizeStyle: sizeStyle,
          disabled: disabled,
          pressed: pressed,
          focused: focused,
          brightness: brightness,
          highContrast: highContrast,
          interfaceLevel: interfaceLevel,
          states: states);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(EnumProperty<ButtonAppearance>('appearance', appearance));
  }
}

/// Compatibility entry for map-form WidgetStateProperty values: one rule
/// per merged cube over (disabled, pressed, focused). Closures throw here;
/// the `mouseCursor` constructor parameter takes them as a legacy rule.
/// The expansion is cached per property object (map-form values are
/// immutable), so a property kept across builds is sampled once.
List<ButtonRule> buttonRulesFromWidgetStates({WidgetStateProperty<MouseCursor?>? mouseCursor}) {
  if (mouseCursor == null) {
    return const <ButtonRule>[];
  }
  return _buttonCursorExpansions[mouseCursor] ??= List<ButtonRule>.unmodifiable(_expandButtonCursor(mouseCursor));
}

final Expando<List<ButtonRule>> _buttonCursorExpansions = Expando<List<ButtonRule>>('buttonCursorExpansions');

List<ButtonRule> _expandButtonCursor(WidgetStateProperty<MouseCursor?> mouseCursor) {
  const List<WidgetState> dims = <WidgetState>[WidgetState.disabled, WidgetState.pressed, WidgetState.focused];
  bool impossible(Set<WidgetState> s) =>
      s.contains(WidgetState.disabled) && (s.contains(WidgetState.pressed) || s.contains(WidgetState.focused));
  ButtonWhen when(StateCube c) => ButtonWhen(
      disabled: c[WidgetState.disabled], pressed: c[WidgetState.pressed], focused: c[WidgetState.focused]);
  return <ButtonRule>[
    for (final (StateCube c, MouseCursor v) in expandWidgetStateProperty<MouseCursor>(mouseCursor, dims, impossible: impossible))
      ButtonRule(when(c), style: ButtonStyle(mouseCursor: v)),
  ];
}

class _ButtonWidgetState extends State<Button> with SingleTickerProviderStateMixin {
  // Eyeballed values (original).
  static const Duration kFadeOutDuration = Duration(milliseconds: 120);
  static const Duration kFadeInDuration = Duration(milliseconds: 180);
  final Tween<double> _opacityTween = Tween<double>(begin: 1.0);

  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  late bool isFocused;

  final StyleResolver<ButtonField> _resolver = StyleResolver<ButtonField>(buttonStyle);

  @override
  void initState() {
    super.initState();
    isFocused = false;
    _animationController = AnimationController(duration: const Duration(milliseconds: 200), value: 0.0, vsync: this);
    _opacityAnimation = _animationController.drive(CurveTween(curve: Curves.decelerate)).drive(_opacityTween);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _buttonHeldDown = false;
  bool _tapInProgress = false;

  void _handleTapDown(TapDownDetails event) {
    setState(() {
      _tapInProgress = true;
    });
    if (!_buttonHeldDown) {
      _buttonHeldDown = true;
      _animate();
    }
  }

  void _handleTapUp(TapUpDetails event) {
    setState(() {
      _tapInProgress = false;
    });
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
    final RenderBox renderObject = context.findRenderObject()! as RenderBox;
    final Offset localPosition = renderObject.globalToLocal(event.globalPosition);
    if (renderObject.paintBounds.inflate(Button.tapMoveSlop()).contains(localPosition)) {
      _handleTap();
    }
  }

  void _handleTapCancel() {
    setState(() {
      _tapInProgress = false;
    });
    if (_buttonHeldDown) {
      _buttonHeldDown = false;
      _animate();
    }
  }

  void _handleTapMove(TapMoveDetails event) {
    final RenderBox renderObject = context.findRenderObject()! as RenderBox;
    final Offset localPosition = renderObject.globalToLocal(event.globalPosition);
    final bool buttonShouldHeldDown =
        renderObject.paintBounds.inflate(Button.tapMoveSlop()).contains(localPosition);
    if (_tapInProgress && buttonShouldHeldDown != _buttonHeldDown) {
      _buttonHeldDown = buttonShouldHeldDown;
      _animate();
    }
  }

  void _handleTap([Intent? _]) {
    if (widget.onPressed != null) {
      widget.onPressed!();
      context.findRenderObject()!.sendSemanticsEvent(const TapSemanticEvent());
    }
  }

  void _animate() {
    if (_animationController.isAnimating) {
      return;
    }
    final bool wasHeldDown = _buttonHeldDown;
    final TickerFuture ticker = _buttonHeldDown
        ? _animationController.animateTo(1.0, duration: kFadeOutDuration, curve: Curves.easeInOutCubicEmphasized)
        : _animationController.animateTo(0.0, duration: kFadeInDuration, curve: Curves.easeOutCubic);
    ticker.then<void>((void value) {
      if (mounted && wasHeldDown != _buttonHeldDown) {
        _animate();
      }
    });
  }

  void _onShowFocusHighlight(bool showHighlight) {
    setState(() {
      isFocused = showHighlight;
    });
  }

  late final Map<Type, Action<Intent>> _actionMap = <Type, Action<Intent>>{
    ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _handleTap),
  };

  @override
  Widget build(BuildContext context) {
    StyleDebug.onComponentBuild?.call(widget);
    final bool enabled = widget.enabled;
    final StyleNode node = StyleTheme.nodeOf(context, ButtonRule);
    final ResolvedEnvironment env = node.effectiveEnvironment.resolve(context);
    final List<ButtonRule> callSite = widget.callSiteRules();
    final bool focused = enabled && isFocused;
    Minterm minterm({required bool pressed}) => buttonMinterm(
        disabled: !enabled,
        pressed: pressed,
        focused: focused,
        appearance: widget.appearance,
        sizeStyle: widget.sizeStyle,
        env: env);
    final Minterm m = minterm(pressed: enabled && _tapInProgress);
    assert(buttonStyle.spec.debugCheckPossible(m));
    final ButtonStyle s = ButtonStyle.fromValues(_resolver.resolve(node, callSite, m));
    // The fade target: pressedOpacity as resolved in the pressed state.
    final double pressedOpacity = enabled
        ? (_resolver.resolve(node, callSite, minterm(pressed: true))[ButtonField.pressedOpacity] as double?) ?? 1.0
        : 1.0;
    _opacityTween.end = pressedOpacity;

    final Color? backgroundColor = s.backgroundColor;
    final Color effectiveForegroundColor = s.foregroundColor ?? const Color(0xFF000000);
    // Unset focusColor: the same value as [defaultButtonFocusColor] (the
    // original's ring from the background, or from activeBlue, which is
    // resolved here; the original forgot).
    final Color effectiveFocusOutlineColor = s.focusColor ??
        cupertinoFocusRingColor(backgroundColor ??
            resolveDynamicColor(CupertinoColors.activeBlue,
                brightness: env.brightness, highContrast: env.highContrast, level: env.interfaceLevel));

    final TextStyle textStyle = s.textStyle ?? TextStyle(color: effectiveForegroundColor);
    final IconThemeData resolvedIcon = s.iconTheme ?? const IconThemeData();
    final IconThemeData iconTheme = IconTheme.of(context).merge(resolvedIcon).copyWith(
          size: resolvedIcon.size ?? (textStyle.fontSize != null ? textStyle.fontSize! * 1.2 : _kDefaultIconSize),
        );

    final DeviceGestureSettings? gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    final Size? minimumSize = s.minimumSize;

    final ShapeDecoration shapeDecoration = ShapeDecoration(
      shape: RoundedSuperellipseBorder(
        side: focused
            ? BorderSide(color: effectiveFocusOutlineColor, width: 3.5, strokeAlign: BorderSide.strokeAlignOutside)
            : s.side ?? BorderSide.none,
        borderRadius: s.borderRadius ?? BorderRadius.zero,
      ),
      color: backgroundColor,
    );

    return MouseRegion(
      cursor: s.mouseCursor ?? MouseCursor.defer,
      child: FocusableActionDetector(
        actions: _actionMap,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onFocusChange: widget.onFocusChange,
        onShowFocusHighlight: _onShowFocusHighlight,
        enabled: enabled,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(postAcceptSlopTolerance: null),
              (TapGestureRecognizer instance) {
                instance.onTapDown = enabled ? _handleTapDown : null;
                instance.onTapUp = enabled ? _handleTapUp : null;
                instance.onTapCancel = enabled ? _handleTapCancel : null;
                instance.onTapMove = enabled ? _handleTapMove : null;
                instance.gestureSettings = gestureSettings;
              },
            ),
            if (widget.onLongPress != null)
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(),
                (LongPressGestureRecognizer instance) {
                  instance.onLongPress = widget.onLongPress;
                  instance.gestureSettings = gestureSettings;
                },
              ),
          },
          child: Semantics(
            button: true,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minimumSize?.width ?? 0,
                minHeight: minimumSize?.height ?? 0,
              ),
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: DecoratedBox(
                  decoration: shapeDecoration,
                  child: Padding(
                    padding: (s.paddingScaler ?? const PaddingScaler.identity())
                        .apply(s.padding ?? EdgeInsets.zero, MediaQuery.textScalerOf(context), textStyle.fontSize ?? 14.0),
                    child: Align(
                      alignment: s.alignment ?? Alignment.center,
                      widthFactor: 1.0,
                      heightFactor: 1.0,
                      child: DefaultTextStyle(
                        style: textStyle,
                        child: IconTheme(data: iconTheme, child: widget.child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
