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
import 'engine/widgets.dart';
import 'style_library.dart';

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
// SwitchField, SwitchDims, the rule classes, the library defaults
// (switchDefaults), switchStyle and switchMinterm are generated from
// packages/style_codegen/specs/cupertino/switch.dart into switch.g.dart.

/// The widget states the original CupertinoSwitch passes to
/// `trackOutlineColor`, `trackOutlineWidth` and `mouseCursor`: the
/// toggleable's disabled / hovered / focused, with `selected` added for
/// the selected end and removed for the other (the mouse cursor gets the
/// current value). Never `pressed`.
Set<WidgetState> switchWidgetStates(Minterm m) => <WidgetState>{
      if (m[SwitchDims.disabled] == true) WidgetState.disabled,
      if (m[SwitchDims.hovered] == true) WidgetState.hovered,
      if (m[SwitchDims.focused] == true) WidgetState.focused,
      if (m[SwitchDims.selected] == true) WidgetState.selected,
    };

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
  // Cached per field and property object (map-form values are immutable),
  // so a property kept across builds is sampled once.
  List<SwitchRule> cached<T extends Object>(
          Expando<List<SwitchRule>> cache, WidgetStateProperty<T?> p, SwitchStyle Function(T v) style) =>
      cache[p] ??= List<SwitchRule>.unmodifiable(<SwitchRule>[
        for (final (StateCube c, T v) in expandWidgetStateProperty<T>(p, dims, impossible: impossible))
          SwitchRule(when(c), style: style(v)),
      ]);
  return <SwitchRule>[
    if (trackOutlineColor != null)
      ...cached<Color>(_outlineColorExpansions, trackOutlineColor, (Color v) => SwitchStyle(trackOutlineColor: v)),
    if (trackOutlineWidth != null)
      ...cached<double>(_outlineWidthExpansions, trackOutlineWidth, (double v) => SwitchStyle(trackOutlineWidth: v)),
    if (mouseCursor != null)
      ...cached<MouseCursor>(_cursorExpansions, mouseCursor, (MouseCursor v) => SwitchStyle(mouseCursor: v)),
  ];
}

final Expando<List<SwitchRule>> _outlineColorExpansions = Expando<List<SwitchRule>>('outlineColorExpansions');
final Expando<List<SwitchRule>> _outlineWidthExpansions = Expando<List<SwitchRule>>('outlineWidthExpansions');
final Expando<List<SwitchRule>> _cursorExpansions = Expando<List<SwitchRule>>('cursorExpansions');

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
    this.rules = const <SwitchRule>[],
  })  : assert(activeThumbImage != null || onActiveThumbImageError == null),
        assert(inactiveThumbImage != null || onInactiveThumbImageError == null);

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// trackColor in the `selected` region of [SwitchRule.trackColor].
  ///
  /// Like every color parameter here: a plain [Color] is the same in every
  /// environment; a CupertinoDynamicColor picks its variant from the
  /// environment (brightness x contrast x elevation): it is expanded into
  /// one plain color per environment when the chain is built, the same way
  /// as in a theme rule. To change only some environments, add a rule with
  /// an environment condition to [rules]; it may hold a plain color or a
  /// dynamic color (only the dynamic color's slots inside the condition are
  /// taken).
  final Color? activeTrackColor;

  /// trackColor in the `unselected` region of [SwitchRule.trackColor].
  /// Plain color: same in every environment; dynamic color: expanded per
  /// environment.
  final Color? inactiveTrackColor;

  /// thumbColor in both regions of [SwitchRule.thumbColor] (on and off).
  /// Plain color: same in every environment; dynamic color: expanded per
  /// environment.
  final Color? thumbColor;

  /// thumbColor in the `unselected` region of [SwitchRule.thumbColor]
  /// (wins over [thumbColor] there). Plain color: same in every
  /// environment; dynamic color: expanded per environment.
  final Color? inactiveThumbColor;

  /// true: the selected track derives from CupertinoToken.primaryColor
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

  /// trackOutlineColor / trackOutlineWidth, as in the original
  /// (`WidgetStateProperty`, resolved for the selected and unselected ends):
  ///
  /// * `WidgetStatePropertyAll(v)`: v in every state (a plain rule; a
  ///   dynamic color is expanded per environment).
  /// * `WidgetStateProperty.fromMap`: expanded into one rule per state
  ///   cube ([switchRulesFromWidgetStates]).
  /// * anything else (`resolveWith`): one legacy rule, resolved on every
  ///   lookup with the states the original passes ([switchWidgetStates]);
  ///   a null result falls through to the theme and the defaults, and a
  ///   dynamic color result is resolved for the environment.
  final WidgetStateProperty<Color?>? trackOutlineColor;
  final WidgetStateProperty<double?>? trackOutlineWidth;

  /// thumbIcon in every state (was `WidgetStateProperty<Icon?>`).
  final IconData? thumbIcon;

  /// mouseCursor in every state; a map-form WidgetStateMouseCursor is
  /// expanded into rules, any other WidgetStateMouseCursor becomes one
  /// legacy rule (see [trackOutlineColor]).
  final MouseCursor? mouseCursor;

  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final DragStartBehavior dragStartBehavior;

  /// Call-site rules, after the flat parameters.
  final List<SwitchRule> rules;

  /// The call-site provider: one rule per flat parameter (a region rule
  /// where the field's default is partitioned, else a rule under
  /// `SwitchWhen()` or a hand-written condition), then [rules].
  List<SwitchRule> callSiteRules() {
    const SwitchWhen every = SwitchWhen();
    SwitchRule all(SwitchStyle s) => SwitchRule(every, style: s);
    final MouseCursor? cursor = mouseCursor;
    final Color? thumbOff = inactiveThumbColor ?? thumbColor;
    return <SwitchRule>[
      // A derive in one region: region constructors take values only, so
      // this one is written with the region's condition.
      if (applyTheme ?? false)
        const SwitchRule.when(selected: true, style: .derive(trackColor: .fromToken(.primaryColor))),
      if (activeTrackColor != null || inactiveTrackColor != null)
        SwitchRule.trackColor(selected: activeTrackColor, unselected: inactiveTrackColor),
      if (thumbColor != null || thumbOff != null) SwitchRule.thumbColor(selected: thumbColor, unselected: thumbOff),
      if (trackOutlineColor case final WidgetStateProperty<Color?> p)
        ..._legacyRules<Color>(p, SwitchField.trackOutlineColor, (Color v) => all(SwitchStyle(trackOutlineColor: v)),
            () => switchRulesFromWidgetStates(trackOutlineColor: p)),
      if (trackOutlineWidth case final WidgetStateProperty<double?> p)
        ..._legacyRules<double>(p, SwitchField.trackOutlineWidth, (double v) => all(SwitchStyle(trackOutlineWidth: v)),
            () => switchRulesFromWidgetStates(trackOutlineWidth: p)),
      if (focusColor != null) all(SwitchStyle(focusColor: focusColor)),
      if (onLabelColor != null) all(SwitchStyle(onLabelColor: onLabelColor)),
      if (offLabelColor != null) all(SwitchStyle(offLabelColor: offLabelColor)),
      if (activeThumbImage != null)
        SwitchRule(const SwitchWhen(selected: true), style: SwitchStyle(thumbImage: activeThumbImage)),
      if (inactiveThumbImage != null)
        SwitchRule(const SwitchWhen(selected: false), style: SwitchStyle(thumbImage: inactiveThumbImage)),
      if (thumbIcon != null) all(SwitchStyle(thumbIcon: thumbIcon)),
      if (cursor != null)
        if (cursor is WidgetStateProperty<MouseCursor?>)
          ..._legacyRules<MouseCursor>(cursor as WidgetStateProperty<MouseCursor?>, SwitchField.mouseCursor,
              (MouseCursor v) => SwitchRule.mouseCursor(enabled: v, disabled: v),
              () => switchRulesFromWidgetStates(mouseCursor: cursor as WidgetStateProperty<MouseCursor?>))
        else
          SwitchRule.mouseCursor(enabled: cursor, disabled: cursor),
      ...rules,
    ];
  }

  /// The rules of one legacy `WidgetStateProperty` parameter: a
  /// [WidgetStatePropertyAll] is one plain rule ([plain]); a map-form
  /// value is expanded ([expand]); anything else is one legacy rule.
  static List<SwitchRule> _legacyRules<T extends Object>(WidgetStateProperty<T?> p, SwitchField field,
      SwitchRule Function(T v) plain, List<SwitchRule> Function() expand) {
    if (p is WidgetStatePropertyAll<T?>) {
      final T? v = p.resolve(const <WidgetState>{});
      return <SwitchRule>[if (v != null) plain(v)];
    }
    if (isExpandableWidgetStateProperty(p)) {
      return expand();
    }
    return <SwitchRule>[SwitchRule._legacy(field, WidgetStatePropertyRule(p, switchWidgetStates))];
  }

  @override
  State<Switch> createState() => _SwitchWidgetState();

  /// The resolved style of a switch at any state (design doc 7.6): the
  /// defaults, the theme and scopes visible at [context], then [rules].
  /// Pass `rules: sw.callSiteRules()` to include an instance's flat
  /// parameters. Delegates to the generated [resolveSwitchStyle].
  static SwitchStyle resolveStyle(
    BuildContext context, {
    bool selected = false,
    bool disabled = false,
    bool pressed = false,
    bool focused = false,
    bool hovered = false,
    Brightness? brightness,
    bool? highContrast,
    CupertinoUserInterfaceLevelData? interfaceLevel,
    List<SwitchRule> rules = const <SwitchRule>[],
  }) =>
      resolveSwitchStyle(context,
          selected: selected,
          disabled: disabled,
          pressed: pressed,
          focused: focused,
          hovered: hovered,
          brightness: brightness,
          highContrast: highContrast,
          interfaceLevel: interfaceLevel,
          rules: rules);

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
        HSLColor.fromColor(replaceAlpha(activeTrackColor, kCupertinoFocusColorOpacity))
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
        ..color = replaceAlpha(onLabelColor, onLabelOpacity)
        ..style = PaintingStyle.fill;
      canvas.drawRect(onLabelRect, onLabelPaint);
      final Paint offLabelPaint = Paint()
        ..color = replaceAlpha(offLabelColor, offLabelOpacity)
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
