// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Switch on the rule-based style model.
///
/// Rewritten from cupertino_ui lib/src/switch.dart (v1.1.3). Gestures,
/// animations and the painter are the original's; the colors, outline,
/// labels, thumb image / icon, cursor and disabled opacity come from rules.
/// Every value, including the ones passed to the constructor, goes through
/// the same chain and is bound per environment, which resolves every
/// CupertinoDynamicColor, so the original's unresolved user colors
/// (trackOutline, activeTrack, inactiveTrack, thumb, inactiveThumb) can't
/// happen.
library;

import 'dart:ui' show lerpDouble;

import 'package:cupertino_ui/cupertino_ui.dart'
    show
        CupertinoColors,
        CupertinoDynamicColor,
        CupertinoUserInterfaceLevelData,
        kCupertinoFocusColorBrightness,
        kCupertinoFocusColorOpacity,
        kCupertinoFocusColorSaturation;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_adapter.dart';
import 'engine/engine.dart';
import 'widgets.dart';

part 'switch.g.dart';

// Painter constants (original, not themeable there either).
const double _kThumbRadius = 14.0;
const double _kTrackHeight = 31.0;
const double _kTrackWidth = 51.0;
const Size _kSwitchSize = Size(59.0, 39.0);
const double _kThumbExtensionFactor = 7.0;
const List<BoxShadow> _kSwitchBoxShadows = <BoxShadow>[
  BoxShadow(color: Color(0x26000000), offset: Offset(0, 3), blurRadius: 8.0),
  BoxShadow(color: Color(0x0F000000), offset: Offset(0, 3), blurRadius: 1.0),
];
const double _kDragCommitThreshold = 0.7;
const double _kDragReverseThreshold = 0.2;
const double _kOnLabelWidth = 1.0;
const double _kOnLabelHeight = 10.0;
const double _kOnLabelPaddingHorizontal = 11.0;
const double _kOffLabelWidth = 1.0;
const double _kOffLabelPaddingHorizontal = 12.0;
const double _kOffLabelRadius = 5.0;
const CupertinoDynamicColor _kOffLabelColor = CupertinoDynamicColor.withBrightnessAndContrast(
  debugLabel: 'offSwitchLabel',
  color: Color.fromARGB(255, 179, 179, 179),
  darkColor: Color.fromARGB(255, 179, 179, 179),
  highContrastColor: Color.fromARGB(255, 255, 255, 255),
  darkHighContrastColor: Color.fromARGB(255, 255, 255, 255),
);

enum _SwitchField implements SwitchField {
  trackColor,
  thumbColor,
  trackOutlineColor,
  trackOutlineWidth,
  focusColor,
  onLabelColor,
  offLabelColor,
  thumbImage,
  thumbIcon,
  thumbIconColor,
  thumbIconSize,
  mouseCursor,
  opacity,
  thumbBackdropColor,
}

/// The library defaults (original values).
const List<SwitchRule> switchDefaults = <SwitchRule>[
  SwitchRule(SwitchWhen(selected: false), label: 'rest',
      style: SwitchStyle(trackColor: CupertinoColors.secondarySystemFill, thumbColor: CupertinoColors.white)),
  SwitchRule(SwitchWhen(selected: true), label: 'selected',
      style: SwitchStyle(trackColor: CupertinoColors.systemGreen, thumbColor: CupertinoColors.white)),
  SwitchRule(SwitchWhen(), label: 'rest',
      style: SwitchStyle(
        trackOutlineWidth: 2.0,
        onLabelColor: CupertinoColors.white,
        offLabelColor: _kOffLabelColor,
        thumbIconColor: CupertinoColors.black,
        thumbIconSize: 16.0,
        opacity: 1.0,
      ),
      derive: SwitchDerive(thumbBackdropColor: CupertinoTokens.scaffoldBackgroundColor)),
  SwitchRule(SwitchWhen(disabled: false), label: 'rest',
      style: SwitchStyle(mouseCursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer)),
  SwitchRule(SwitchWhen(disabled: true), label: 'disabled',
      style: SwitchStyle(mouseCursor: MouseCursor.defer, opacity: 0.5)),
];

final ComponentStyle<SwitchField> switchStyle = ComponentStyle<SwitchField>(
  channel: SwitchRule,
  spec: ComponentSpec<SwitchField>(
    name: 'Switch',
    fields: SwitchField.values,
    dimensions: SwitchDims.all,
    fieldTypes: const <SwitchField, Type>{
      SwitchField.trackColor: Color,
      SwitchField.thumbColor: Color,
      SwitchField.trackOutlineColor: Color,
      SwitchField.focusColor: Color,
      SwitchField.onLabelColor: Color,
      SwitchField.offLabelColor: Color,
      SwitchField.thumbIconColor: Color,
      SwitchField.thumbBackdropColor: Color,
    },
    impossible: <Condition>[
      Condition(<Dimension<Object>, Object>{SwitchDims.disabled: true, SwitchDims.pressed: true}),
      Condition(<Dimension<Object>, Object>{SwitchDims.disabled: true, SwitchDims.focused: true}),
      Condition(<Dimension<Object>, Object>{SwitchDims.disabled: true, SwitchDims.hovered: true}),
    ],
  ),
  defaults: <RawRule<SwitchField>>[for (final SwitchRule r in switchDefaults) r.toRaw()],
);

Minterm switchMinterm({
  required bool disabled,
  required bool selected,
  required bool pressed,
  required bool focused,
  required bool hovered,
  required ResolvedEnvironment env,
}) =>
    Minterm(SwitchDims.all, <Object>[disabled, selected, pressed, focused, hovered, ...env.values]);

/// Compatibility entry for map-form WidgetStateProperty values: rules over
/// (disabled, selected, focused, hovered). A `resolveWith` closure throws.
List<SwitchRule> switchRulesFromWidgetStates({
  WidgetStateProperty<Color?>? trackOutlineColor,
  WidgetStateProperty<double?>? trackOutlineWidth,
  WidgetStateProperty<MouseCursor?>? mouseCursor,
}) {
  const List<WidgetState> dims = <WidgetState>[
    WidgetState.disabled, WidgetState.selected, WidgetState.focused, WidgetState.hovered, //
  ];
  bool impossible(Set<WidgetState> s) =>
      s.contains(WidgetState.disabled) && (s.contains(WidgetState.focused) || s.contains(WidgetState.hovered));
  SwitchWhen when(StateCube c) => SwitchWhen(
      disabled: c[WidgetState.disabled],
      selected: c[WidgetState.selected],
      focused: c[WidgetState.focused],
      hovered: c[WidgetState.hovered]);
  return <SwitchRule>[
    if (trackOutlineColor != null)
      for (final (StateCube c, Color v) in expandWidgetStateProperty<Color>(trackOutlineColor, dims, impossible: impossible))
        SwitchRule(when(c), style: SwitchStyle(trackOutlineColor: v)),
    if (trackOutlineWidth != null)
      for (final (StateCube c, double v) in expandWidgetStateProperty<double>(trackOutlineWidth, dims, impossible: impossible))
        SwitchRule(when(c), style: SwitchStyle(trackOutlineWidth: v)),
    if (mouseCursor != null)
      for (final (StateCube c, MouseCursor v) in expandWidgetStateProperty<MouseCursor>(mouseCursor, dims, impossible: impossible))
        SwitchRule(when(c), style: SwitchStyle(mouseCursor: v)),
  ];
}

/// An iOS-style switch whose look comes from rules.
class Switch extends StatefulWidget {
  const Switch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.thumbColor,
    this.inactiveThumbColor,
    this.applyTheme,
    this.focusColor,
    this.onLabelColor,
    this.offLabelColor,
    this.activeThumbImage,
    this.onActiveThumbImageError,
    this.inactiveThumbImage,
    this.onInactiveThumbImageError,
    this.trackOutlineColor,
    this.trackOutlineWidth,
    this.thumbIcon,
    this.mouseCursor,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.states = const <SwitchRule>[],
  })  : assert(activeThumbImage != null || onActiveThumbImageError == null),
        assert(inactiveThumbImage != null || onInactiveThumbImageError == null);

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// trackColor, region [SwitchTrackColorRegions.selected].
  ///
  /// Like every color parameter here: a plain [Color] is the same in every
  /// environment; a CupertinoDynamicColor picks its variant from the
  /// environment (brightness x contrast x elevation): it is expanded into
  /// one plain color per environment when the chain is built, the same way
  /// as in a theme rule. To change only some environments, add a rule with
  /// an environment condition to [states]; it may hold a plain color or a
  /// dynamic color (only the dynamic color's slots inside the condition are
  /// taken).
  final Color? activeTrackColor;

  /// trackColor, region [SwitchTrackColorRegions.unselected]. Plain color: same in every environment;
  /// dynamic color: expanded per environment.
  final Color? inactiveTrackColor;

  /// thumbColor, both regions (on and off). Plain color: same in every
  /// environment; dynamic color: expanded per environment.
  final Color? thumbColor;

  /// thumbColor, region [SwitchThumbColorRegions.unselected] (after [thumbColor], so it wins there).
  /// Plain color: same in every environment; dynamic color: expanded per
  /// environment.
  final Color? inactiveThumbColor;

  /// true: the selected track derives from CupertinoTokens.primaryColor
  /// (a call-site derive rule). The theme-wide `applyThemeToAll` is not
  /// read; a theme writes that rule itself.
  final bool? applyTheme;

  /// focusColor, every state. Plain color: same in every environment;
  /// dynamic color: expanded per environment.
  final Color? focusColor;

  /// onLabelColor / offLabelColor, every state. Plain color: same in every
  /// environment; dynamic color: expanded per environment.
  final Color? onLabelColor;
  final Color? offLabelColor;

  /// thumbImage when on / off (hand-written conditions `selected: true` /
  /// `selected: false`: the defaults have no thumb image regions).
  final ImageProvider? activeThumbImage;
  final ImageErrorListener? onActiveThumbImageError;
  final ImageProvider? inactiveThumbImage;
  final ImageErrorListener? onInactiveThumbImageError;

  /// trackOutlineColor / trackOutlineWidth in every state. Was a
  /// `WidgetStateProperty`; per-state values go in [states] (or through
  /// [switchRulesFromWidgetStates] for map-form values). Plain
  /// color: same in every environment; dynamic color: expanded per
  /// environment.
  final Color? trackOutlineColor;
  final double? trackOutlineWidth;

  /// thumbIcon in every state (was `WidgetStateProperty<Icon?>`).
  final IconData? thumbIcon;

  /// mouseCursor in every state; a map-form WidgetStateMouseCursor is
  /// expanded into rules, a closure is rejected.
  final MouseCursor? mouseCursor;

  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final DragStartBehavior dragStartBehavior;

  /// Call-site rules, after the flat parameters.
  final List<SwitchRule> states;

  List<SwitchRule> callSiteRules() {
    SwitchRule one(SwitchWhen w, SwitchStyle s) => SwitchRule(w, style: s);
    final MouseCursor? cursor = mouseCursor;
    return <SwitchRule>[
      if (applyTheme ?? false)
        const SwitchRule(SwitchTrackColorRegions.selected,
            derive: SwitchDerive(trackColor: CupertinoTokens.primaryColor)),
      if (activeTrackColor != null)
        one(SwitchTrackColorRegions.selected, SwitchStyle(trackColor: activeTrackColor)),
      if (inactiveTrackColor != null)
        one(SwitchTrackColorRegions.unselected, SwitchStyle(trackColor: inactiveTrackColor)),
      if (thumbColor != null)
        SwitchRule.any(
            <SwitchWhen>[SwitchThumbColorRegions.unselected, SwitchThumbColorRegions.selected],
            style: SwitchStyle(thumbColor: thumbColor)),
      if (inactiveThumbColor != null)
        one(SwitchThumbColorRegions.unselected, SwitchStyle(thumbColor: inactiveThumbColor)),
      if (trackOutlineColor != null)
        one(SwitchTrackOutlineColorRegions.anyState, SwitchStyle(trackOutlineColor: trackOutlineColor)),
      if (trackOutlineWidth != null)
        one(SwitchTrackOutlineWidthRegions.anyState, SwitchStyle(trackOutlineWidth: trackOutlineWidth)),
      if (focusColor != null) one(SwitchFocusColorRegions.anyState, SwitchStyle(focusColor: focusColor)),
      if (onLabelColor != null) one(SwitchOnLabelColorRegions.anyState, SwitchStyle(onLabelColor: onLabelColor)),
      if (offLabelColor != null)
        one(SwitchOffLabelColorRegions.anyState, SwitchStyle(offLabelColor: offLabelColor)),
      if (activeThumbImage != null)
        one(const SwitchWhen(selected: true), SwitchStyle(thumbImage: activeThumbImage)),
      if (inactiveThumbImage != null)
        one(const SwitchWhen(selected: false), SwitchStyle(thumbImage: inactiveThumbImage)),
      if (thumbIcon != null) one(SwitchThumbIconRegions.anyState, SwitchStyle(thumbIcon: thumbIcon)),
      if (cursor != null)
        if (cursor is WidgetStateProperty<MouseCursor?>)
          ...switchRulesFromWidgetStates(mouseCursor: cursor as WidgetStateProperty<MouseCursor?>)
        else
          SwitchRule.any(
              <SwitchWhen>[SwitchMouseCursorRegions.enabled, SwitchMouseCursorRegions.disabled],
              style: SwitchStyle(mouseCursor: cursor)),
      ...states,
    ];
  }

  @override
  State<Switch> createState() => _SwitchWidgetState();

  /// The resolved style of this switch (theme,
  /// scopes and this call site) at any state.
  SwitchStyle resolveStyle(BuildContext context,
      {required bool selected, bool disabled = false, bool pressed = false, bool focused = false, bool hovered = false}) {
    final StyleNode node = StyleTheme.peekNode(context);
    final Minterm m = switchMinterm(
        disabled: disabled,
        selected: selected,
        pressed: pressed,
        focused: focused,
        hovered: hovered,
        env: node.effectiveEnvironment.resolve(context));
    return SwitchStyle.fromValues(
        StyleResolver<SwitchField>(switchStyle).resolve(node, callSiteRules(), m));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('value', value: value, ifTrue: 'on', ifFalse: 'off', showName: true));
    properties.add(ObjectFlagProperty<ValueChanged<bool>>('onChanged', onChanged, ifNull: 'disabled'));
  }
}

class _SwitchWidgetState extends State<Switch> with TickerProviderStateMixin, ToggleableStateMixin {
  final _SwitchPainter _painter = _SwitchPainter();
  final StyleResolver<SwitchField> _resolver = StyleResolver<SwitchField>(switchStyle);

  Offset _dragStartPosition = Offset.zero;
  double _dragDelta = 0;
  bool? _dragValue;

  @override
  void initState() {
    super.initState();
    positionController.duration = const Duration(milliseconds: 200);
    reactionController.duration = const Duration(milliseconds: 300);
    position
      ..curve = Curves.ease
      ..reverseCurve = Curves.ease.flipped;
  }

  @override
  void didUpdateWidget(Switch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      animateToValue();
    }
  }

  @override
  void dispose() {
    _painter.dispose();
    super.dispose();
  }

  @override
  ValueChanged<bool?>? get onChanged => widget.onChanged != null ? _handleChanged : null;

  @override
  bool get tristate => false;

  @override
  bool? get value => widget.value;

  double get _trackInnerLength {
    const double trackInnerStart = _kTrackHeight / 2.0;
    const double trackInnerEnd = _kTrackWidth - trackInnerStart;
    return trackInnerEnd - trackInnerStart;
  }

  void _handleOnTapDown(TapDownDetails details) {
    if (isInteractive) {
      _dragStartPosition = details.globalPosition;
    }
  }

  void _handleDragStart(DragStartDetails details) {
    if (isInteractive) {
      reactionController.forward();
      if (_dragStartPosition != Offset.zero) {
        final double delta = (details.globalPosition - _dragStartPosition).dx / _kTrackWidth;
        _dragDelta = switch (Directionality.of(context)) {
          TextDirection.rtl => -delta,
          TextDirection.ltr => delta,
        };
      }
      _dragValue = value;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (isInteractive) {
      final double delta = details.primaryDelta! / _kTrackWidth;
      _dragDelta += switch (Directionality.of(context)) {
        TextDirection.rtl => -delta,
        TextDirection.ltr => delta,
      };
      final bool valueChangedWhileDragging = widget.value != _dragValue;
      final double threshold = valueChangedWhileDragging ? _kDragReverseThreshold : _kDragCommitThreshold;
      final double effectiveThreshold = widget.value ? -threshold : threshold;
      final bool newDragValue = _dragDelta >= effectiveThreshold;
      if (_dragValue != newDragValue) {
        _emitVibration();
        if (newDragValue) {
          positionController.forward();
        } else {
          positionController.reverse();
        }
        _dragValue = newDragValue;
      }
    }
  }

  bool _needsPositionAnimation = false;

  void _handleDragEnd(DragEndDetails details) {
    if (_dragValue != widget.value) {
      widget.onChanged?.call(!widget.value);
      setState(() {
        _needsPositionAnimation = true;
      });
    }
    _dragStartPosition = Offset.zero;
    _dragDelta = 0;
    _dragValue = null;
    reactionController.reverse();
  }

  void _handleChanged(bool? value) {
    assert(value != null);
    assert(widget.onChanged != null);
    widget.onChanged?.call(value!);
    _emitVibration();
  }

  void _emitVibration() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        HapticFeedback.lightImpact();
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    StyleDebug.onComponentBuild?.call(widget);
    if (_needsPositionAnimation) {
      _needsPositionAnimation = false;
      animateToValue();
    }

    final StyleNode node = StyleTheme.nodeOf(context, SwitchRule);
    final ResolvedEnvironment env = node.effectiveEnvironment.resolve(context);
    final List<SwitchRule> callSite = widget.callSiteRules();
    final Set<WidgetState> st = states;
    final bool disabled = !isInteractive;
    final bool focused = !disabled && st.contains(WidgetState.focused);
    final bool hovered = !disabled && st.contains(WidgetState.hovered);

    // selected is animated: resolve both ends (and both pressed variants
    // of the thumb) and let the painter interpolate, as the original does.
    SwitchStyle at({required bool selected, bool pressed = false}) {
      final Minterm m = switchMinterm(
          disabled: disabled, selected: selected, pressed: pressed && !disabled, focused: focused, hovered: hovered, env: env);
      assert(switchStyle.spec.debugCheckPossible(m));
      return SwitchStyle.fromValues(_resolver.resolve(node, callSite, m));
    }

    final SwitchStyle active = at(selected: true);
    final SwitchStyle inactive = at(selected: false);
    final SwitchStyle activePressed = at(selected: true, pressed: true);
    final SwitchStyle inactivePressed = at(selected: false, pressed: true);
    final SwitchStyle current = widget.value ? active : inactive;

    const Color fallback = Color(0xFF000000);
    final Color activeTrackColor = active.trackColor ?? fallback;
    final (Color, Color)? onOffLabelColors = MediaQuery.onOffSwitchLabelsOf(context)
        ? (current.onLabelColor ?? fallback, current.offLabelColor ?? fallback)
        : null;

    // Unset focusColor: the original's computation from the (resolved)
    // selected track color. Not a rule; see NOTES.
    final Color focusColor = current.focusColor ??
        HSLColor.fromColor(applyAlpha(activeTrackColor, kCupertinoFocusColorOpacity))
            .withLightness(kCupertinoFocusColorBrightness)
            .withSaturation(kCupertinoFocusColorSaturation)
            .toColor();

    return Semantics(
      toggled: widget.value,
      child: GestureDetector(
        excludeFromSemantics: true,
        onTapDown: _handleOnTapDown,
        onHorizontalDragStart: _handleDragStart,
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        dragStartBehavior: widget.dragStartBehavior,
        child: Opacity(
          opacity: current.opacity ?? 1.0,
          child: buildToggleable(
            mouseCursor: WidgetStatePropertyAll<MouseCursor>(current.mouseCursor ?? MouseCursor.defer),
            focusNode: widget.focusNode,
            onFocusChange: widget.onFocusChange,
            autofocus: widget.autofocus,
            size: _kSwitchSize,
            painter: _painter
              ..position = position
              ..reaction = reaction
              ..reactionFocusFade = reactionFocusFade
              ..reactionHoverFade = reactionHoverFade
              ..focusColor = focusColor
              ..downPosition = downPosition
              ..isFocused = st.contains(WidgetState.focused)
              ..isHovered = st.contains(WidgetState.hovered)
              ..activeColor = active.thumbColor ?? fallback
              ..inactiveColor = inactive.thumbColor ?? fallback
              ..activePressedColor = activePressed.thumbColor ?? fallback
              ..inactivePressedColor = inactivePressed.thumbColor ?? fallback
              ..onOffLabelColors = onOffLabelColors
              ..activeThumbImage = active.thumbImage
              ..onActiveThumbImageError = widget.onActiveThumbImageError
              ..inactiveThumbImage = inactive.thumbImage
              ..onInactiveThumbImageError = widget.onInactiveThumbImageError
              ..activeTrackColor = activeTrackColor
              ..activeTrackOutlineColor = active.trackOutlineColor
              ..activeTrackOutlineWidth = active.trackOutlineWidth
              ..inactiveTrackColor = inactive.trackColor ?? fallback
              ..inactiveTrackOutlineColor = inactive.trackOutlineColor
              ..inactiveTrackOutlineWidth = inactive.trackOutlineWidth
              ..configuration = createLocalImageConfiguration(context)
              ..isInteractive = isInteractive
              ..trackInnerLength = _trackInnerLength
              ..textDirection = Directionality.of(context)
              ..activeIconColor = active.thumbIconColor ?? fallback
              ..inactiveIconColor = inactive.thumbIconColor ?? fallback
              ..activeIcon = active.thumbIcon
              ..inactiveIcon = inactive.thumbIcon
              ..activeIconSize = active.thumbIconSize ?? 16.0
              ..inactiveIconSize = inactive.thumbIconSize ?? 16.0
              ..iconTheme = IconTheme.of(context)
              ..surfaceColor = current.thumbBackdropColor ?? fallback
              ..positionController = positionController,
          ),
        ),
      ),
    );
  }
}

/// The original painter, with the thumb icon as IconData + color + size.
class _SwitchPainter extends ToggleablePainter {
  AnimationController get positionController => _positionController!;
  AnimationController? _positionController;
  set positionController(AnimationController value) {
    if (value == _positionController) {
      return;
    }
    _positionController = value;
    _colorAnimation?.dispose();
    _colorAnimation = CurvedAnimation(parent: positionController, curve: Curves.easeOut, reverseCurve: Curves.easeIn);
    notifyListeners();
  }

  CurvedAnimation? _colorAnimation;

  T _set<T>(T old, T value) {
    if (old != value) {
      notifyListeners();
    }
    return value;
  }

  IconData? _activeIcon;
  set activeIcon(IconData? v) => _activeIcon = _set(_activeIcon, v);
  IconData? _inactiveIcon;
  set inactiveIcon(IconData? v) => _inactiveIcon = _set(_inactiveIcon, v);
  double _activeIconSize = 16.0;
  set activeIconSize(double v) => _activeIconSize = _set(_activeIconSize, v);
  double _inactiveIconSize = 16.0;
  set inactiveIconSize(double v) => _inactiveIconSize = _set(_inactiveIconSize, v);
  IconThemeData? _iconTheme;
  set iconTheme(IconThemeData? v) => _iconTheme = _set(_iconTheme, v);
  Color? _activeIconColor;
  set activeIconColor(Color v) => _activeIconColor = _set(_activeIconColor, v);
  Color? _inactiveIconColor;
  set inactiveIconColor(Color v) => _inactiveIconColor = _set(_inactiveIconColor, v);
  Color? _activePressedColor;
  set activePressedColor(Color v) => _activePressedColor = _set(_activePressedColor, v);
  Color? _inactivePressedColor;
  set inactivePressedColor(Color v) => _inactivePressedColor = _set(_inactivePressedColor, v);
  ImageProvider? _activeThumbImage;
  set activeThumbImage(ImageProvider? v) => _activeThumbImage = _set(_activeThumbImage, v);
  ImageErrorListener? _onActiveThumbImageError;
  set onActiveThumbImageError(ImageErrorListener? v) => _onActiveThumbImageError = _set(_onActiveThumbImageError, v);
  ImageProvider? _inactiveThumbImage;
  set inactiveThumbImage(ImageProvider? v) => _inactiveThumbImage = _set(_inactiveThumbImage, v);
  ImageErrorListener? _onInactiveThumbImageError;
  set onInactiveThumbImageError(ImageErrorListener? v) =>
      _onInactiveThumbImageError = _set(_onInactiveThumbImageError, v);
  Color? _activeTrackColor;
  set activeTrackColor(Color v) => _activeTrackColor = _set(_activeTrackColor, v);
  Color? _activeTrackOutlineColor;
  set activeTrackOutlineColor(Color? v) => _activeTrackOutlineColor = _set(_activeTrackOutlineColor, v);
  Color? _inactiveTrackOutlineColor;
  set inactiveTrackOutlineColor(Color? v) => _inactiveTrackOutlineColor = _set(_inactiveTrackOutlineColor, v);
  double? _activeTrackOutlineWidth;
  set activeTrackOutlineWidth(double? v) => _activeTrackOutlineWidth = _set(_activeTrackOutlineWidth, v);
  double? _inactiveTrackOutlineWidth;
  set inactiveTrackOutlineWidth(double? v) => _inactiveTrackOutlineWidth = _set(_inactiveTrackOutlineWidth, v);
  Color? _inactiveTrackColor;
  set inactiveTrackColor(Color v) => _inactiveTrackColor = _set(_inactiveTrackColor, v);
  ImageConfiguration? _configuration;
  set configuration(ImageConfiguration v) => _configuration = _set(_configuration, v);
  TextDirection? _textDirection;
  set textDirection(TextDirection v) => _textDirection = _set(_textDirection, v);
  Color? _surfaceColor;
  set surfaceColor(Color v) => _surfaceColor = _set(_surfaceColor, v);
  bool? _isInteractive;
  set isInteractive(bool v) => _isInteractive = _set(_isInteractive, v);
  double? _trackInnerLength;
  set trackInnerLength(double v) => _trackInnerLength = _set(_trackInnerLength, v);
  (Color, Color)? _onOffLabelColors;
  set onOffLabelColors((Color, Color)? v) => _onOffLabelColors = _set(_onOffLabelColors, v);

  bool get isInteractive => _isInteractive!;

  final TextPainter _textPainter = TextPainter();
  Color? _cachedThumbColor;
  ImageProvider? _cachedThumbImage;
  ImageErrorListener? _cachedThumbErrorListener;
  BoxPainter? _cachedThumbPainter;

  ShapeDecoration _createDefaultThumbDecoration(Color color, ImageProvider? image, ImageErrorListener? errorListener) {
    return ShapeDecoration(
      color: color,
      image: image == null ? null : DecorationImage(image: image, onError: errorListener),
      shape: const StadiumBorder(),
    );
  }

  bool _isPainting = false;

  void _handleDecorationChanged() {
    if (!_isPainting) {
      notifyListeners();
    }
  }

  bool _stopPressAnimation = false;
  late double? _pressedThumbExtension;

  @override
  void paint(Canvas canvas, Size size) {
    final double currentValue = position.value;
    final double visualPosition = switch (_textDirection!) {
      TextDirection.rtl => 1.0 - currentValue,
      TextDirection.ltr => currentValue,
    };
    if (reaction.status == AnimationStatus.reverse && !_stopPressAnimation) {
      _stopPressAnimation = true;
    } else {
      _stopPressAnimation = false;
    }

    _pressedThumbExtension = reaction.value * _kThumbExtensionFactor;
    final Size thumbSize = Size(_kThumbRadius * 2 + _pressedThumbExtension!, _kThumbRadius * 2);

    final double colorValue = _colorAnimation!.value;
    final Color trackColor = Color.lerp(_inactiveTrackColor, _activeTrackColor, position.value)!;
    final Color? trackOutlineColor = _inactiveTrackOutlineColor == null || _activeTrackOutlineColor == null
        ? null
        : Color.lerp(_inactiveTrackOutlineColor, _activeTrackOutlineColor, colorValue);
    final double? trackOutlineWidth = lerpDouble(_inactiveTrackOutlineWidth, _activeTrackOutlineWidth, colorValue);

    final Color lerpedThumbColor;
    if (!reaction.isDismissed) {
      lerpedThumbColor = Color.lerp(_inactivePressedColor, _activePressedColor, colorValue)!;
    } else if (positionController.status == AnimationStatus.forward) {
      lerpedThumbColor = Color.lerp(_inactivePressedColor, activeColor, colorValue)!;
    } else if (positionController.status == AnimationStatus.reverse) {
      lerpedThumbColor = Color.lerp(inactiveColor, _activePressedColor, colorValue)!;
    } else {
      lerpedThumbColor = Color.lerp(inactiveColor, activeColor, colorValue)!;
    }

    final Color thumbColor = Color.alphaBlend(lerpedThumbColor, _surfaceColor!);

    final IconData? thumbIcon = currentValue < 0.5 ? _inactiveIcon : _activeIcon;
    final double thumbIconSize = currentValue < 0.5 ? _inactiveIconSize : _activeIconSize;
    final ImageProvider? thumbImage = currentValue < 0.5 ? _inactiveThumbImage : _activeThumbImage;
    final ImageErrorListener? thumbErrorListener =
        currentValue < 0.5 ? _onInactiveThumbImageError : _onActiveThumbImageError;

    final Paint paint = Paint()..color = trackColor;
    final Offset trackPaintOffset = _computeTrackPaintOffset(size);
    final Offset thumbPaintOffset = _computeThumbPaintOffset(trackPaintOffset, thumbSize, visualPosition);
    final Rect trackRect = Rect.fromLTWH(trackPaintOffset.dx, trackPaintOffset.dy, _kTrackWidth, _kTrackHeight);

    _paintTrackWith(canvas, paint, trackPaintOffset, trackOutlineColor, trackOutlineWidth, trackRect);

    final double currentReactionValue = reaction.value;
    if (_onOffLabelColors != null) {
      final (Color onLabelColor, Color offLabelColor) = _onOffLabelColors!;
      final double leftLabelOpacity = visualPosition * (1.0 - currentReactionValue);
      final double rightLabelOpacity = (1.0 - visualPosition) * (1.0 - currentReactionValue);
      final (double onLabelOpacity, double offLabelOpacity) = switch (_textDirection!) {
        TextDirection.ltr => (leftLabelOpacity, rightLabelOpacity),
        TextDirection.rtl => (rightLabelOpacity, leftLabelOpacity),
      };
      final (Offset onLabelOffset, Offset offLabelOffset) = switch (_textDirection!) {
        TextDirection.ltr => (
            trackRect.centerLeft.translate(_kOnLabelPaddingHorizontal, 0),
            trackRect.centerRight.translate(-_kOffLabelPaddingHorizontal, 0),
          ),
        TextDirection.rtl => (
            trackRect.centerRight.translate(-_kOnLabelPaddingHorizontal, 0),
            trackRect.centerLeft.translate(_kOffLabelPaddingHorizontal, 0),
          ),
      };
      final Rect onLabelRect = Rect.fromCenter(center: onLabelOffset, width: _kOnLabelWidth, height: _kOnLabelHeight);
      final Paint onLabelPaint = Paint()
        ..color = applyAlpha(onLabelColor, onLabelOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawRect(onLabelRect, onLabelPaint);
      final Paint offLabelPaint = Paint()
        ..color = applyAlpha(offLabelColor, offLabelOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _kOffLabelWidth;
      canvas.drawCircle(offLabelOffset, _kOffLabelRadius, offLabelPaint);
    }
    _paintThumbWith(thumbPaintOffset, canvas, colorValue, thumbColor, thumbImage, thumbErrorListener, thumbIcon,
        thumbIconSize, thumbSize);
  }

  static Offset _computeTrackPaintOffset(Size canvasSize) {
    final double horizontalOffset = (canvasSize.width - _kTrackWidth) / 2.0;
    final double verticalOffset = (canvasSize.height - _kTrackHeight) / 2.0;
    return Offset(horizontalOffset, verticalOffset);
  }

  Offset _computeThumbPaintOffset(Offset trackPaintOffset, Size thumbSize, double visualPosition) {
    const double trackRadius = _kTrackHeight / 2;
    final double additionalThumbRadius = thumbSize.height / 2 - trackRadius;
    final double horizontalProgress = visualPosition * (_trackInnerLength! - _pressedThumbExtension!);
    final double thumbHorizontalOffset =
        trackPaintOffset.dx + trackRadius + (_pressedThumbExtension! / 2) - thumbSize.width / 2 + horizontalProgress;
    final double thumbVerticalOffset = trackPaintOffset.dy - additionalThumbRadius;
    return Offset(thumbHorizontalOffset, thumbVerticalOffset);
  }

  void _paintTrackWith(Canvas canvas, Paint paint, Offset trackPaintOffset, Color? trackOutlineColor,
      double? trackOutlineWidth, Rect trackRect) {
    const double trackRadius = _kTrackHeight / 2;
    final RRect trackRRect = RRect.fromRectAndRadius(trackRect, const Radius.circular(trackRadius));
    canvas.drawRRect(trackRRect, paint);
    if (trackOutlineColor != null) {
      final Rect outlineTrackRect =
          Rect.fromLTWH(trackPaintOffset.dx + 1, trackPaintOffset.dy + 1, _kTrackWidth - 2, _kTrackHeight - 2);
      final RRect outlineTrackRRect = RRect.fromRectAndRadius(outlineTrackRect, const Radius.circular(trackRadius));
      final Paint outlinePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackOutlineWidth ?? 2.0
        ..color = trackOutlineColor;
      canvas.drawRRect(outlineTrackRRect, outlinePaint);
    }
    if (isFocused) {
      final RRect focusedOutline = trackRRect.inflate(1.75);
      final Paint focusedPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = focusColor
        ..strokeWidth = 3.5;
      canvas.drawRRect(focusedOutline, focusedPaint);
    }
    canvas.clipRRect(trackRRect);
  }

  void _paintThumbWith(Offset thumbPaintOffset, Canvas canvas, double currentValue, Color thumbColor,
      ImageProvider? thumbImage, ImageErrorListener? thumbErrorListener, IconData? thumbIcon, double iconSize,
      Size thumbSize) {
    try {
      _isPainting = true;
      if (_cachedThumbPainter == null ||
          thumbColor != _cachedThumbColor ||
          thumbImage != _cachedThumbImage ||
          thumbErrorListener != _cachedThumbErrorListener) {
        _cachedThumbColor = thumbColor;
        _cachedThumbImage = thumbImage;
        _cachedThumbErrorListener = thumbErrorListener;
        _cachedThumbPainter?.dispose();
        _cachedThumbPainter =
            _createDefaultThumbDecoration(thumbColor, thumbImage, thumbErrorListener).createBoxPainter(_handleDecorationChanged);
      }
      final BoxPainter thumbPainter = _cachedThumbPainter!;
      _paintCupertinoThumbShadowAndBorder(canvas, thumbPaintOffset, thumbSize);
      thumbPainter.paint(canvas, thumbPaintOffset, _configuration!.copyWith(size: thumbSize));

      if (thumbIcon != null) {
        final Color iconColor = Color.lerp(_inactiveIconColor, _activeIconColor, currentValue)!;
        final double? iconWeight = _iconTheme?.weight;
        final double? iconFill = _iconTheme?.fill;
        final double? iconGrade = _iconTheme?.grade;
        final double? iconOpticalSize = _iconTheme?.opticalSize;
        final List<Shadow>? iconShadows = _iconTheme?.shadows;
        final TextSpan textSpan = TextSpan(
          text: String.fromCharCode(thumbIcon.codePoint),
          style: TextStyle(
            fontVariations: <FontVariation>[
              if (iconFill != null) FontVariation('FILL', iconFill),
              if (iconWeight != null) FontVariation('wght', iconWeight),
              if (iconGrade != null) FontVariation('GRAD', iconGrade),
              if (iconOpticalSize != null) FontVariation('opsz', iconOpticalSize),
            ],
            color: iconColor,
            fontSize: iconSize,
            inherit: false,
            fontFamily: thumbIcon.fontFamily,
            package: thumbIcon.fontPackage,
            shadows: iconShadows,
          ),
        );
        _textPainter
          ..textDirection = _textDirection
          ..text = textSpan;
        _textPainter.layout();
        final double additionalHorizontalOffset = (thumbSize.width - iconSize) / 2;
        final double additionalVerticalOffset = (thumbSize.height - iconSize) / 2;
        final Offset offset = thumbPaintOffset + Offset(additionalHorizontalOffset, additionalVerticalOffset);
        _textPainter.paint(canvas, offset);
      }
    } finally {
      _isPainting = false;
    }
  }

  void _paintCupertinoThumbShadowAndBorder(Canvas canvas, Offset thumbPaintOffset, Size thumbSize) {
    final RRect thumbBounds = RRect.fromLTRBR(
      thumbPaintOffset.dx,
      thumbPaintOffset.dy,
      thumbPaintOffset.dx + thumbSize.width,
      thumbPaintOffset.dy + thumbSize.height,
      Radius.circular(thumbSize.height / 2.0),
    );
    for (final BoxShadow shadow in _kSwitchBoxShadows) {
      canvas.drawRRect(thumbBounds.shift(shadow.offset), shadow.toPaint());
    }
    canvas.drawRRect(thumbBounds.inflate(0.5), Paint()..color = const Color(0x0A000000));
  }

  @override
  void dispose() {
    _textPainter.dispose();
    _cachedThumbPainter?.dispose();
    _cachedThumbPainter = null;
    _cachedThumbColor = null;
    _cachedThumbImage = null;
    _cachedThumbErrorListener = null;
    _colorAnimation?.dispose();
    super.dispose();
  }
}
