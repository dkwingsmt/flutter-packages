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
import 'widgets.dart';

export 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButtonSize;

part 'button.g.dart';

/// Alias for [CupertinoButtonSize] to match the unprefixed [Button] naming.
typedef ButtonSize = CupertinoButtonSize;

/// The background style of a [Button] (was the private
/// `_ButtonStyle`; now a dimension rules can name).
enum ButtonAppearance {
  /// No background, primary foreground.
  plain,

  /// Translucent primary background, primary foreground.
  tinted,

  /// Solid primary background, contrasting foreground.
  filled,
}

enum _ButtonField implements ButtonField {
  backgroundColor,
  foregroundColor,
  focusColor,
  padding,
  borderRadius,
  minimumSize,
  alignment,
  textStyle,
  iconTheme,
  pressedOpacity,
  mouseCursor,
}

// Original constants (cupertino_ui constants.dart), repeated here as rule
// values.
const double _kTintedOpacityLight = 0.12; // kButtonTintedOpacityLight
const double _kTintedOpacityDark = 0.26; // kButtonTintedOpacityDark
const double _kDefaultIconSize = 20.0; // kButtonDefaultIconSize
const EnvAlpha _kTintedAlpha = EnvAlpha(light: _kTintedOpacityLight, dark: _kTintedOpacityDark);

const Set<ButtonAppearance> _plain = <ButtonAppearance>{ButtonAppearance.plain};
const Set<ButtonAppearance> _tinted = <ButtonAppearance>{ButtonAppearance.tinted};
const Set<ButtonAppearance> _filled = <ButtonAppearance>{ButtonAppearance.filled};

/// The library defaults, as one const rule list. Labels are provenance
/// only (debugSources); the region constants in button.g.dart
/// (`ButtonBackgroundColorRegions`, ...) are named by the region
/// they cover.
const List<ButtonRule> buttonDefaults = <ButtonRule>[
  // Every appearance and state.
  ButtonRule(ButtonWhen(), label: 'rest',
      style: ButtonStyle(pressedOpacity: 0.4, alignment: Alignment.center)),

  // Size table (kButtonPadding / SizeBorderRadius / MinSize).
  ButtonRule(ButtonWhen(sizeStyle: <ButtonSize>{ButtonSize.small}), label: 'rest',
      style: ButtonStyle(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        borderRadius: BorderRadius.all(Radius.circular(40)),
        minimumSize: Size(28, 28),
      ),
      derive: ButtonDerive(textStyle: CupertinoTokens.actionSmallTextStyle)),
  ButtonRule(ButtonWhen(sizeStyle: <ButtonSize>{ButtonSize.medium}), label: 'rest',
      style: ButtonStyle(
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        borderRadius: BorderRadius.all(Radius.circular(40)),
        minimumSize: Size(32, 32),
      ),
      derive: ButtonDerive(textStyle: CupertinoTokens.actionTextStyle)),
  ButtonRule(ButtonWhen(sizeStyle: <ButtonSize>{ButtonSize.large}), label: 'rest',
      style: ButtonStyle(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        minimumSize: Size(44, 44),
      ),
      derive: ButtonDerive(textStyle: CupertinoTokens.actionTextStyle)),

  // Foreground: primary, tertiaryLabel when disabled; filled buttons use
  // primaryContrastingColor in every state.
  ButtonRule(ButtonWhen(disabled: false), label: 'rest',
      derive: ButtonDerive(foregroundColor: CupertinoTokens.primaryColor)),
  ButtonRule(ButtonWhen(disabled: true), label: 'disabled',
      style: ButtonStyle(foregroundColor: CupertinoColors.tertiaryLabel)),
  ButtonRule(ButtonWhen(appearance: _filled), label: 'rest',
      derive: ButtonDerive(foregroundColor: CupertinoTokens.primaryContrastingColor)),

  // Background: tinted = primary at the tinted opacity (0.12 light, 0.26
  // dark; one derive rule, the alpha picked per environment), filled =
  // primary (forced opaque, like `withOpacity(1.0)`); disabled =
  // tertiarySystemFill (the tinted / filled constructors' default
  // disabledColor). Plain buttons have no default background.
  ButtonRule(ButtonWhen(appearance: _tinted, disabled: false), label: 'rest',
      derive: ButtonDerive(backgroundColor: TokenRef(CupertinoTokens.primaryColor, alpha: _kTintedAlpha))),
  ButtonRule(ButtonWhen(appearance: _filled, disabled: false), label: 'rest',
      derive: ButtonDerive(backgroundColor: TokenRef(CupertinoTokens.primaryColor, alpha: 1.0))),
  ButtonRule(
      ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.tinted, ButtonAppearance.filled}, disabled: true),
      label: 'disabled',
      style: ButtonStyle(backgroundColor: CupertinoColors.tertiarySystemFill)),

  // Mouse cursor (the original's _defaultCursor). Off the web both values
  // are `defer` (accepted redundancy: one rule pair covers web and native).
  ButtonRule(ButtonWhen(disabled: false), label: 'rest',
      style: ButtonStyle(mouseCursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer)),
  ButtonRule(ButtonWhen(disabled: true), label: 'disabled',
      style: ButtonStyle(mouseCursor: MouseCursor.defer)),

  // Text and icon follow the final foreground (a same-component derive). Last,
  // so the token text style written above (it carries primaryColor) does
  // not overwrite the derived color.
  ButtonRule(ButtonWhen(), label: 'rest',
      derive: ButtonDerive(
        textStyleColor: FieldRef(ButtonField.foregroundColor),
        iconThemeColor: FieldRef(ButtonField.foregroundColor),
      )),
];

/// Static description of the component (spec + defaults).
final ComponentStyle<ButtonField> buttonStyle = ComponentStyle<ButtonField>(
  channel: ButtonRule,
  spec: ComponentSpec<ButtonField>(
    name: 'Button',
    fields: ButtonField.values,
    dimensions: ButtonDims.all,
    fieldTypes: const <ButtonField, Type>{
      ButtonField.backgroundColor: Color,
      ButtonField.foregroundColor: Color,
      ButtonField.focusColor: Color,
    },
    composites: const <ButtonField, Composite>{
      ButtonField.textStyle: textStyleComposite,
      ButtonField.iconTheme: iconThemeComposite,
    },
    // FocusableActionDetector is disabled and the tap handlers are null
    // while disabled.
    impossible: <Condition>[
      Condition(<Dimension<Object>, Object>{ButtonDims.disabled: true, ButtonDims.pressed: true}),
      Condition(<Dimension<Object>, Object>{ButtonDims.disabled: true, ButtonDims.focused: true}),
    ],
  ),
  defaults: <RawRule<ButtonField>>[for (final ButtonRule r in buttonDefaults) r.toRaw()],
);

/// The minterm of a button state.
Minterm buttonMinterm({
  required bool disabled,
  required bool pressed,
  required bool focused,
  required ButtonAppearance appearance,
  required ButtonSize sizeStyle,
  required ResolvedEnvironment env,
}) =>
    Minterm(ButtonDims.all, <Object>[disabled, pressed, focused, appearance, sizeStyle, ...env.values]);

/// A tinted background from a base color: the tinted opacity per
/// brightness, as one dynamic color (expanded per environment like any
/// other). Used by the `color:` parameter of tinted buttons, which the
/// original also tinted.
Color tintedBackground(Color c) => mapColorVariants(
    c, (Color v, Brightness b) => applyAlpha(v, b == Brightness.light ? _kTintedOpacityLight : _kTintedOpacityDark),
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

  /// backgroundColor in the enabled region of this appearance
  /// ([ButtonBackgroundColorRegions.tintedEnabled] /
  /// [ButtonBackgroundColorRegions.filledEnabled]; on a plain
  /// button [ButtonBackgroundColorRegions.plainAnyState]); tinted buttons apply the
  /// tinted opacity to it, as before. On a plain button the disabled state
  /// then shows [disabledColor] (default quaternarySystemFill), as before.
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

  /// foregroundColor in every state (enabled + disabled regions, or
  /// [ButtonForegroundColorRegions.filledAnyState]). Plain color:
  /// same in every environment; dynamic color: expanded per environment.
  final Color? foregroundColor;

  /// backgroundColor in the disabled region. On a plain button it only
  /// applies together with [color], as before. Plain color: same in every
  /// environment; dynamic color: expanded per environment.
  final Color? disabledColor;

  /// Each in its field's `anyState` region (every state).
  final EdgeInsetsGeometry? padding;
  final Size? minimumSize;
  final double? pressedOpacity;
  final BorderRadius? borderRadius;
  final AlignmentGeometry? alignment;

  /// focusColor in every state. Plain color: same in every environment;
  /// dynamic color: expanded per environment.
  final Color? focusColor;

  /// mouseCursor in every state. A map-form WidgetStateMouseCursor
  /// (`WidgetStateMouseCursor.fromMap`) is expanded into rules; a
  /// `resolveWith` closure is rejected.
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

  /// The call-site provider: one rule per flat parameter (each under its
  /// region constant), then [states].
  List<ButtonRule> callSiteRules() {
    final ButtonAppearance a = appearance;
    final List<ButtonRule> out = <ButtonRule>[];
    final Color? bg = color;
    if (bg != null) {
      switch (a) {
        case ButtonAppearance.plain:
          out
            ..add(ButtonRule(ButtonBackgroundColorRegions.plainAnyState,
                style: ButtonStyle(backgroundColor: bg)))
            // Compatibility mapping: the original painted disabledColor
            // (default quaternarySystemFill) on a disabled plain button
            // only when `color` was set.
            ..add(ButtonRule(const ButtonWhen(appearance: _plain, disabled: true),
                style: ButtonStyle(backgroundColor: disabledColor ?? CupertinoColors.quaternarySystemFill)));
        case ButtonAppearance.tinted:
          out.add(ButtonRule(ButtonBackgroundColorRegions.tintedEnabled,
              style: ButtonStyle(backgroundColor: tintedBackground(bg))));
        case ButtonAppearance.filled:
          out.add(ButtonRule(ButtonBackgroundColorRegions.filledEnabled,
              style: ButtonStyle(backgroundColor: bg)));
      }
    }
    final Color? dis = disabledColor;
    if (dis != null && a != ButtonAppearance.plain) {
      out.add(ButtonRule(
          a == ButtonAppearance.tinted
              ? ButtonBackgroundColorRegions.tintedDisabled
              : ButtonBackgroundColorRegions.filledDisabled,
          style: ButtonStyle(backgroundColor: dis)));
    }
    final Color? fg = foregroundColor;
    if (fg != null) {
      final ButtonStyle s = ButtonStyle(foregroundColor: fg);
      out.add(switch (a) {
        ButtonAppearance.plain => ButtonRule.any(
            <ButtonWhen>[ButtonForegroundColorRegions.plainEnabled, ButtonForegroundColorRegions.plainDisabled],
            style: s),
        ButtonAppearance.tinted => ButtonRule.any(
            <ButtonWhen>[ButtonForegroundColorRegions.tintedEnabled, ButtonForegroundColorRegions.tintedDisabled],
            style: s),
        ButtonAppearance.filled => ButtonRule(ButtonForegroundColorRegions.filledAnyState, style: s),
      });
    }
    if (focusColor != null) {
      out.add(ButtonRule(ButtonFocusColorRegions.anyState, style: ButtonStyle(focusColor: focusColor)));
    }
    if (padding != null) {
      out.add(ButtonRule(ButtonPaddingRegions.anyState, style: ButtonStyle(padding: padding)));
    }
    if (borderRadius != null) {
      out.add(ButtonRule(ButtonBorderRadiusRegions.anyState, style: ButtonStyle(borderRadius: borderRadius)));
    }
    if (minimumSize != null) {
      out.add(ButtonRule(ButtonMinimumSizeRegions.anyState, style: ButtonStyle(minimumSize: minimumSize)));
    }
    if (alignment != null) {
      out.add(ButtonRule(ButtonAlignmentRegions.anyState, style: ButtonStyle(alignment: alignment)));
    }
    if (pressedOpacity != null) {
      out.add(ButtonRule(ButtonPressedOpacityRegions.anyState,
          style: ButtonStyle(pressedOpacity: pressedOpacity)));
    }
    final MouseCursor? cursor = mouseCursor;
    if (cursor != null) {
      if (cursor is WidgetStateProperty<MouseCursor?>) {
        out.addAll(buttonRulesFromWidgetStates(mouseCursor: cursor as WidgetStateProperty<MouseCursor?>));
      } else {
        out.add(ButtonRule.any(
            <ButtonWhen>[ButtonMouseCursorRegions.enabled, ButtonMouseCursorRegions.disabled],
            style: ButtonStyle(mouseCursor: cursor)));
      }
    }
    out.addAll(states);
    return out;
  }

  @override
  State<Button> createState() => _ButtonWidgetState();

  /// The resolved style of this button (theme,
  /// scopes and this call site) at any state, not only the current one.
  /// Environment dims not set by a StyleTheme / StyleScope come from
  /// [context].
  ButtonStyle resolveStyle(BuildContext context,
      {bool disabled = false, bool pressed = false, bool focused = false}) {
    final StyleNode node = StyleTheme.peekNode(context);
    final Minterm m = buttonMinterm(
        disabled: disabled,
        pressed: pressed,
        focused: focused,
        appearance: appearance,
        sizeStyle: sizeStyle,
        env: node.effectiveEnvironment.resolve(context));
    return ButtonStyle.fromValues(
        StyleResolver<ButtonField>(buttonStyle).resolve(node, callSiteRules(), m));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'));
    properties.add(EnumProperty<ButtonAppearance>('appearance', appearance));
  }
}

/// Compatibility entry for map-form WidgetStateProperty values: one rule
/// per merged cube over (disabled, pressed, focused). Closures throw.
List<ButtonRule> buttonRulesFromWidgetStates({WidgetStateProperty<MouseCursor?>? mouseCursor}) {
  const List<WidgetState> dims = <WidgetState>[WidgetState.disabled, WidgetState.pressed, WidgetState.focused];
  bool impossible(Set<WidgetState> s) =>
      s.contains(WidgetState.disabled) && (s.contains(WidgetState.pressed) || s.contains(WidgetState.focused));
  ButtonWhen when(StateCube c) => ButtonWhen(
      disabled: c[WidgetState.disabled], pressed: c[WidgetState.pressed], focused: c[WidgetState.focused]);
  return <ButtonRule>[
    if (mouseCursor != null)
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
    // Unset focusColor: the original's computation from the background (or
    // activeBlue). Not expressible as a rule (only identity derives and
    // token alpha exist); see NOTES. activeBlue is resolved here, which
    // the original forgot.
    final Color effectiveFocusOutlineColor = s.focusColor ??
        HSLColor.fromColor(applyAlpha(
                backgroundColor ??
                    resolveDynamicColor(CupertinoColors.activeBlue,
                        brightness: env.brightness, highContrast: env.highContrast, level: env.interfaceLevel),
                kCupertinoFocusColorOpacity))
            .withLightness(kCupertinoFocusColorBrightness)
            .withSaturation(kCupertinoFocusColorSaturation)
            .toColor();

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
            : BorderSide.none,
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
                    padding: s.padding ?? EdgeInsets.zero,
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
