// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// SHOULD BE GENERATED. Hand-written in this sample, in the shape a
// generator would emit from the field / dimension declarations in
// button.dart: dimensions, the private field enum's facade, XWhen,
// XStyle, XDerive, XRule (with ==), and the rule-region constants.
// ignore_for_file: library_private_types_in_public_api
part of 'button.dart';

// ---- dimensions ------------------------------------------------------------

/// The dimensions of [Button].
abstract final class ButtonDims {
  static const BoolDimension disabled = BoolDimension('disabled');
  static const BoolDimension pressed = BoolDimension('pressed');
  static const BoolDimension focused = BoolDimension('focused');
  static const Dimension<ButtonAppearance> appearance =
      Dimension<ButtonAppearance>('appearance', ButtonAppearance.values);
  static const Dimension<ButtonSize> sizeStyle =
      Dimension<ButtonSize>('sizeStyle', ButtonSize.values);

  static const List<Dimension<Object>> all = <Dimension<Object>>[
    disabled, pressed, focused, appearance, sizeStyle, //
    EnvDims.brightness, EnvDims.highContrast, EnvDims.interfaceLevel,
  ];
}

// ---- field facade ------------------------------------------------------------

/// Public facade of the private field enum: name fields in [FieldRef]s,
/// e.g. `FieldRef(ButtonField.foregroundColor)`.
abstract final class ButtonField implements Enum {
  static const List<ButtonField> values = _ButtonField.values;

  static const backgroundColor = _ButtonField.backgroundColor;
  static const foregroundColor = _ButtonField.foregroundColor;
  static const focusColor = _ButtonField.focusColor;
  static const padding = _ButtonField.padding;
  static const borderRadius = _ButtonField.borderRadius;
  static const minimumSize = _ButtonField.minimumSize;
  static const alignment = _ButtonField.alignment;
  static const textStyle = _ButtonField.textStyle;
  static const iconTheme = _ButtonField.iconTheme;
  static const pressedOpacity = _ButtonField.pressedOpacity;
  static const mouseCursor = _ButtonField.mouseCursor;
}

// ---- When --------------------------------------------------------------------

/// A condition: null = unconstrained. Bool dims are tri-state; enum dims
/// take a positive set.
@immutable
final class ButtonWhen {
  const ButtonWhen({
    this.disabled,
    this.pressed,
    this.focused,
    this.appearance,
    this.sizeStyle,
    this.brightness,
    this.highContrast,
    this.interfaceLevel,
  });

  final bool? disabled;
  final bool? pressed;
  final bool? focused;
  final Set<ButtonAppearance>? appearance;
  final Set<ButtonSize>? sizeStyle;
  final Set<Brightness>? brightness;
  final bool? highContrast;
  final Set<CupertinoUserInterfaceLevelData>? interfaceLevel;

  Condition toCondition() => Condition(<Dimension<Object>, Object>{
        ButtonDims.disabled: ?disabled,
        ButtonDims.pressed: ?pressed,
        ButtonDims.focused: ?focused,
        ButtonDims.appearance: ?appearance,
        ButtonDims.sizeStyle: ?sizeStyle,
        EnvDims.brightness: ?brightness,
        EnvDims.highContrast: ?highContrast,
        EnvDims.interfaceLevel: ?interfaceLevel,
      });

  @override
  bool operator ==(Object other) =>
      other is ButtonWhen &&
      other.disabled == disabled &&
      other.pressed == pressed &&
      other.focused == focused &&
      setEquals(other.appearance, appearance) &&
      setEquals(other.sizeStyle, sizeStyle) &&
      setEquals(other.brightness, brightness) &&
      other.highContrast == highContrast &&
      setEquals(other.interfaceLevel, interfaceLevel);

  @override
  int get hashCode => Object.hash(disabled, pressed, focused, _setHash(appearance), _setHash(sizeStyle),
      _setHash(brightness), highContrast, _setHash(interfaceLevel));

  @override
  String toString() => toCondition().toString();
}

int? _setHash(Set<Object>? s) => s == null ? null : Object.hashAllUnordered(s);

// ---- Style -------------------------------------------------------------------

/// Every themeable property of [Button]. Null = not set by this
/// rule. Values are data: closure-style values (WidgetStateColor,
/// WidgetStateMouseCursor) are rejected in debug; CupertinoDynamicColor is
/// fine (expanded into one plain color per environment when the chain is
/// built).
@immutable
final class ButtonStyle {
  const ButtonStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.focusColor,
    this.padding,
    this.borderRadius,
    this.minimumSize,
    this.alignment,
    this.textStyle,
    this.iconTheme,
    this.pressedOpacity,
    this.mouseCursor,
  })  : assert(backgroundColor is! WidgetStateProperty<Object?>, 'backgroundColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(foregroundColor is! WidgetStateProperty<Object?>, 'foregroundColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(focusColor is! WidgetStateProperty<Object?>, 'focusColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(mouseCursor is! WidgetStateProperty<Object?>, 'mouseCursor: a style holds data, not a WidgetStateMouseCursor; write one rule per state');

  /// The painted background. Unset = no background.
  final Color? backgroundColor;

  /// Text and icon color (followed by textStyle.color / iconTheme.color
  /// through the default derive).
  final Color? foregroundColor;

  /// The focus ring. Unset = computed by the widget from the resolved
  /// background (or activeBlue), as in the original.
  final Color? focusColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Size? minimumSize;
  final AlignmentGeometry? alignment;

  /// Merged per property across rules (composite).
  final TextStyle? textStyle;

  /// Merged per property across rules (composite). An unset size is
  /// computed by the widget from textStyle.fontSize (x 1.2).
  final IconThemeData? iconTheme;

  /// The opacity the button fades to while pressed (resolved at the
  /// pressed minterm). 1.0 = no fade.
  final double? pressedOpacity;
  final MouseCursor? mouseCursor;

  Style<ButtonField> toStyle() => Style<ButtonField>(<ButtonField, Object>{
        ButtonField.backgroundColor: ?backgroundColor,
        ButtonField.foregroundColor: ?foregroundColor,
        ButtonField.focusColor: ?focusColor,
        ButtonField.padding: ?padding,
        ButtonField.borderRadius: ?borderRadius,
        ButtonField.minimumSize: ?minimumSize,
        ButtonField.alignment: ?alignment,
        ButtonField.textStyle: ?textStyle,
        ButtonField.iconTheme: ?iconTheme,
        ButtonField.pressedOpacity: ?pressedOpacity,
        ButtonField.mouseCursor: ?mouseCursor,
      });

  static ButtonStyle fromValues(Map<ButtonField, Object> v) => ButtonStyle(
        backgroundColor: v[ButtonField.backgroundColor] as Color?,
        foregroundColor: v[ButtonField.foregroundColor] as Color?,
        focusColor: v[ButtonField.focusColor] as Color?,
        padding: v[ButtonField.padding] as EdgeInsetsGeometry?,
        borderRadius: v[ButtonField.borderRadius] as BorderRadius?,
        minimumSize: v[ButtonField.minimumSize] as Size?,
        alignment: v[ButtonField.alignment] as AlignmentGeometry?,
        textStyle: v[ButtonField.textStyle] as TextStyle?,
        iconTheme: v[ButtonField.iconTheme] as IconThemeData?,
        pressedOpacity: v[ButtonField.pressedOpacity] as double?,
        mouseCursor: v[ButtonField.mouseCursor] as MouseCursor?,
      );

  @override
  bool operator ==(Object other) =>
      other is ButtonStyle &&
      other.backgroundColor == backgroundColor &&
      other.foregroundColor == foregroundColor &&
      other.focusColor == focusColor &&
      other.padding == padding &&
      other.borderRadius == borderRadius &&
      other.minimumSize == minimumSize &&
      other.alignment == alignment &&
      other.textStyle == textStyle &&
      other.iconTheme == iconTheme &&
      other.pressedOpacity == pressedOpacity &&
      other.mouseCursor == mouseCursor;

  @override
  int get hashCode => Object.hash(backgroundColor, foregroundColor, focusColor, padding, borderRadius, minimumSize,
      alignment, textStyle, iconTheme, pressedOpacity, mouseCursor);
}

// ---- Derive ------------------------------------------------------------------

/// Derived fields: [FieldRef] (same component) or a token ([TokenRef],
/// or a group token written directly). The `xColor` / `xSize` entries
/// target one property of a composite field (sub-property targets).
@immutable
final class ButtonDerive {
  const ButtonDerive({
    this.backgroundColor,
    this.foregroundColor,
    this.focusColor,
    this.textStyle,
    this.textStyleColor,
    this.iconThemeColor,
  });

  final DeriveSource? backgroundColor;
  final DeriveSource? foregroundColor;
  final DeriveSource? focusColor;
  final DeriveSource? textStyle;

  /// Sub-property target `(textStyle, color)`.
  final DeriveSource? textStyleColor;

  /// Sub-property target `(iconTheme, color)`.
  final DeriveSource? iconThemeColor;

  Derive<ButtonField> toDerive() => Derive<ButtonField>(<ButtonField, DeriveSource>{
        ButtonField.backgroundColor: ?backgroundColor,
        ButtonField.foregroundColor: ?foregroundColor,
        ButtonField.focusColor: ?focusColor,
        ButtonField.textStyle: ?textStyle,
      });

  SubMap<ButtonField> toSub() => <(ButtonField, SubProp), Object>{
        (ButtonField.textStyle, SubProp.color): ?textStyleColor,
        (ButtonField.iconTheme, SubProp.color): ?iconThemeColor,
      };

  @override
  bool operator ==(Object other) =>
      other is ButtonDerive &&
      other.backgroundColor == backgroundColor &&
      other.foregroundColor == foregroundColor &&
      other.focusColor == focusColor &&
      other.textStyle == textStyle &&
      other.textStyleColor == textStyleColor &&
      other.iconThemeColor == iconThemeColor;

  @override
  int get hashCode => Object.hash(backgroundColor, foregroundColor, focusColor, textStyle, textStyleColor, iconThemeColor);
}

// ---- Rule --------------------------------------------------------------------

/// A [Button] rule: condition + partial style + derive. Goes in
/// StyleTheme / StyleScope rule lists (mixed with other components' rules)
/// and in `Button(states: ...)`.
final class ButtonRule extends ComponentRule<ButtonField> {
  const ButtonRule(ButtonWhen this.when,
      {this.style = const ButtonStyle(), this.derive = const ButtonDerive(), this.label})
      : whens = null;

  /// Cross-dimension "or": one rule per condition, sharing one position.
  const ButtonRule.any(List<ButtonWhen> this.whens,
      {this.style = const ButtonStyle(), this.derive = const ButtonDerive(), this.label})
      : when = null;

  final ButtonWhen? when;
  final List<ButtonWhen>? whens;
  final ButtonStyle style;
  final ButtonDerive derive;

  /// Region name of a default rule (`rest`, `disabled`, ...); null elsewhere.
  final String? label;

  @override
  void addTo(RuleChannels channels) => channels.add<ButtonRule>(this);

  static final Expando<RawRule<ButtonField>> _raw = Expando<RawRule<ButtonField>>('raw');

  @override
  RawRule<ButtonField> toRaw() => _raw[this] ??= whens == null
      ? RawRule<ButtonField>(when!.toCondition(),
          style: style.toStyle(), derive: derive.toDerive(), sub: derive.toSub(), label: label)
      : RawRule<ButtonField>.any(<Condition>[for (final ButtonWhen w in whens!) w.toCondition()],
          style: style.toStyle(), derive: derive.toDerive(), sub: derive.toSub(), label: label);

  @override
  bool operator ==(Object other) =>
      other is ButtonRule &&
      other.when == when &&
      listEquals(other.whens, whens) &&
      other.style == style &&
      other.derive == derive &&
      other.label == label;

  @override
  int get hashCode => Object.hash(when, whens == null ? null : Object.hashAll(whens!), style, derive, label);
}

// ---- Rule regions ------------------------------------------------------------
//
// Rule-region constants of the defaults: for a field, the states where a
// given default rule wins. Theme authors and flat parameters use them
// instead of spelling conditions; `test/regions_test.dart` checks each
// against the defaults table. One class per field, each region a
// `static const`, so a region can go into a const rule list. Where regions
// differ between appearances they are split per appearance; a region never
// spans several appearances.
//
// Names describe the region, not the winning rule (the naming function is
// test/support/region_names.dart and the test checks every name and doc
// comment against it): the appearance as
// prefix, then the positive state literals (`disabled`), else `idle` (every
// interaction state off), `enabled` (not disabled, interaction states free)
// or `anyState` (no constraint); semantic values (`selected`) as suffix. The
// doc comment spells the exact condition. Environment dims are never
// constrained.

const Set<ButtonAppearance> _onlyPlain = <ButtonAppearance>{ButtonAppearance.plain};
const Set<ButtonAppearance> _onlyTinted = <ButtonAppearance>{ButtonAppearance.tinted};
const Set<ButtonAppearance> _onlyFilled = <ButtonAppearance>{ButtonAppearance.filled};

/// Regions of `backgroundColor`.
abstract final class ButtonBackgroundColorRegions {
  /// Appearance plain; any disabled / pressed / focused.
  static const ButtonWhen plainAnyState = ButtonWhen(appearance: _onlyPlain);
  /// Not disabled, appearance tinted; any pressed / focused.
  static const ButtonWhen tintedEnabled = ButtonWhen(appearance: _onlyTinted, disabled: false);
  /// Disabled, appearance tinted; any pressed / focused.
  static const ButtonWhen tintedDisabled = ButtonWhen(appearance: _onlyTinted, disabled: true);
  /// Not disabled, appearance filled; any pressed / focused.
  static const ButtonWhen filledEnabled = ButtonWhen(appearance: _onlyFilled, disabled: false);
  /// Disabled, appearance filled; any pressed / focused.
  static const ButtonWhen filledDisabled = ButtonWhen(appearance: _onlyFilled, disabled: true);
}

/// Regions of `foregroundColor`.
abstract final class ButtonForegroundColorRegions {
  /// Not disabled, appearance plain; any pressed / focused.
  static const ButtonWhen plainEnabled = ButtonWhen(appearance: _onlyPlain, disabled: false);
  /// Disabled, appearance plain; any pressed / focused.
  static const ButtonWhen plainDisabled = ButtonWhen(appearance: _onlyPlain, disabled: true);
  /// Not disabled, appearance tinted; any pressed / focused.
  static const ButtonWhen tintedEnabled = ButtonWhen(appearance: _onlyTinted, disabled: false);
  /// Disabled, appearance tinted; any pressed / focused.
  static const ButtonWhen tintedDisabled = ButtonWhen(appearance: _onlyTinted, disabled: true);
  /// Appearance filled; any disabled / pressed / focused.
  static const ButtonWhen filledAnyState = ButtonWhen(appearance: _onlyFilled);
}

/// Regions of `padding`.
abstract final class ButtonPaddingRegions {
  /// Every state.
  static const ButtonWhen anyState = ButtonWhen();
}

/// Regions of `borderRadius`.
abstract final class ButtonBorderRadiusRegions {
  /// Every state.
  static const ButtonWhen anyState = ButtonWhen();
}

/// Regions of `minimumSize`.
abstract final class ButtonMinimumSizeRegions {
  /// Every state.
  static const ButtonWhen anyState = ButtonWhen();
}

/// Regions of `alignment`.
abstract final class ButtonAlignmentRegions {
  /// Every state.
  static const ButtonWhen anyState = ButtonWhen();
}

/// Regions of `pressedOpacity`.
abstract final class ButtonPressedOpacityRegions {
  /// Every state.
  static const ButtonWhen anyState = ButtonWhen();
}

/// Regions of `focusColor`.
abstract final class ButtonFocusColorRegions {
  /// Every state.
  static const ButtonWhen anyState = ButtonWhen();
}

/// Regions of `mouseCursor`.
abstract final class ButtonMouseCursorRegions {
  /// Not disabled; any pressed / focused.
  static const ButtonWhen enabled = ButtonWhen(disabled: false);
  /// Disabled; any pressed / focused.
  static const ButtonWhen disabled = ButtonWhen(disabled: true);
}
