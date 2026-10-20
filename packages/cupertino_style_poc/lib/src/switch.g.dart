// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// SHOULD BE GENERATED. Hand-written in this sample, in the shape a
// generator would emit from the declarations in switch.dart.
// ignore_for_file: library_private_types_in_public_api
part of 'switch.dart';

// ---- dimensions ------------------------------------------------------------

/// The dimensions of [Switch]. `selected` is the switch value.
abstract final class SwitchDims {
  static const BoolDimension disabled = BoolDimension('disabled');
  static const BoolDimension selected = BoolDimension('selected');
  static const BoolDimension pressed = BoolDimension('pressed');
  static const BoolDimension focused = BoolDimension('focused');
  static const BoolDimension hovered = BoolDimension('hovered');

  static const List<Dimension<Object>> all = <Dimension<Object>>[
    disabled, selected, pressed, focused, hovered, //
    EnvDims.brightness, EnvDims.highContrast, EnvDims.interfaceLevel,
  ];
}

// ---- field facade ------------------------------------------------------------

abstract final class SwitchField implements Enum {
  static const List<SwitchField> values = _SwitchField.values;

  static const trackColor = _SwitchField.trackColor;
  static const thumbColor = _SwitchField.thumbColor;
  static const trackOutlineColor = _SwitchField.trackOutlineColor;
  static const trackOutlineWidth = _SwitchField.trackOutlineWidth;
  static const focusColor = _SwitchField.focusColor;
  static const onLabelColor = _SwitchField.onLabelColor;
  static const offLabelColor = _SwitchField.offLabelColor;
  static const thumbImage = _SwitchField.thumbImage;
  static const thumbIcon = _SwitchField.thumbIcon;
  static const thumbIconColor = _SwitchField.thumbIconColor;
  static const thumbIconSize = _SwitchField.thumbIconSize;
  static const mouseCursor = _SwitchField.mouseCursor;
  static const opacity = _SwitchField.opacity;
  static const thumbBackdropColor = _SwitchField.thumbBackdropColor;
}

// ---- When --------------------------------------------------------------------

@immutable
final class SwitchWhen {
  const SwitchWhen({
    this.disabled,
    this.selected,
    this.pressed,
    this.focused,
    this.hovered,
    this.brightness,
    this.highContrast,
    this.interfaceLevel,
  });

  final bool? disabled;
  final bool? selected;
  final bool? pressed;
  final bool? focused;
  final bool? hovered;
  final Set<Brightness>? brightness;
  final bool? highContrast;
  final Set<CupertinoUserInterfaceLevelData>? interfaceLevel;

  Condition toCondition() => Condition(<Dimension<Object>, Object>{
        SwitchDims.disabled: ?disabled,
        SwitchDims.selected: ?selected,
        SwitchDims.pressed: ?pressed,
        SwitchDims.focused: ?focused,
        SwitchDims.hovered: ?hovered,
        EnvDims.brightness: ?brightness,
        EnvDims.highContrast: ?highContrast,
        EnvDims.interfaceLevel: ?interfaceLevel,
      });

  @override
  bool operator ==(Object other) =>
      other is SwitchWhen &&
      other.disabled == disabled &&
      other.selected == selected &&
      other.pressed == pressed &&
      other.focused == focused &&
      other.hovered == hovered &&
      setEquals(other.brightness, brightness) &&
      other.highContrast == highContrast &&
      setEquals(other.interfaceLevel, interfaceLevel);

  @override
  int get hashCode => Object.hash(disabled, selected, pressed, focused, hovered,
      brightness == null ? null : Object.hashAllUnordered(brightness!), highContrast,
      interfaceLevel == null ? null : Object.hashAllUnordered(interfaceLevel!));

  @override
  String toString() => toCondition().toString();
}

// ---- Style -------------------------------------------------------------------

/// Every themeable property of [Switch]. Null = not set.
@immutable
final class SwitchStyle {
  const SwitchStyle({
    this.trackColor,
    this.thumbColor,
    this.trackOutlineColor,
    this.trackOutlineWidth,
    this.focusColor,
    this.onLabelColor,
    this.offLabelColor,
    this.thumbImage,
    this.thumbIcon,
    this.thumbIconColor,
    this.thumbIconSize,
    this.mouseCursor,
    this.opacity,
    this.thumbBackdropColor,
  })  : assert(trackColor is! WidgetStateProperty<Object?>, 'trackColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(thumbColor is! WidgetStateProperty<Object?>, 'thumbColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(trackOutlineColor is! WidgetStateProperty<Object?>, 'trackOutlineColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(focusColor is! WidgetStateProperty<Object?>, 'focusColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(mouseCursor is! WidgetStateProperty<Object?>, 'mouseCursor: a style holds data, not a WidgetStateMouseCursor; write one rule per state');

  final Color? trackColor;

  /// Painted over [thumbBackdropColor] (alpha blend), as before.
  final Color? thumbColor;

  /// Unset = no outline (painted only when both selected ends have one).
  final Color? trackOutlineColor;
  final double? trackOutlineWidth;

  /// Unset = computed by the widget from the selected track color.
  final Color? focusColor;
  final Color? onLabelColor;
  final Color? offLabelColor;
  final ImageProvider? thumbImage;

  /// Was `WidgetStateProperty<Icon?>`. An Icon is a widget; a style holds
  /// data, so the icon is split into [thumbIcon] + [thumbIconColor] +
  /// [thumbIconSize]. Weight / fill / grade / opticalSize / shadows come
  /// from the ambient IconTheme, as they did when the Icon left them null.
  final IconData? thumbIcon;
  final Color? thumbIconColor;
  final double? thumbIconSize;
  final MouseCursor? mouseCursor;

  /// Opacity of the whole switch (0.5 when disabled).
  final double? opacity;

  /// What a translucent thumb is blended against (scaffold background).
  final Color? thumbBackdropColor;

  Style<SwitchField> toStyle() => Style<SwitchField>(<SwitchField, Object>{
        SwitchField.trackColor: ?trackColor,
        SwitchField.thumbColor: ?thumbColor,
        SwitchField.trackOutlineColor: ?trackOutlineColor,
        SwitchField.trackOutlineWidth: ?trackOutlineWidth,
        SwitchField.focusColor: ?focusColor,
        SwitchField.onLabelColor: ?onLabelColor,
        SwitchField.offLabelColor: ?offLabelColor,
        SwitchField.thumbImage: ?thumbImage,
        SwitchField.thumbIcon: ?thumbIcon,
        SwitchField.thumbIconColor: ?thumbIconColor,
        SwitchField.thumbIconSize: ?thumbIconSize,
        SwitchField.mouseCursor: ?mouseCursor,
        SwitchField.opacity: ?opacity,
        SwitchField.thumbBackdropColor: ?thumbBackdropColor,
      });

  static SwitchStyle fromValues(Map<SwitchField, Object> v) => SwitchStyle(
        trackColor: v[SwitchField.trackColor] as Color?,
        thumbColor: v[SwitchField.thumbColor] as Color?,
        trackOutlineColor: v[SwitchField.trackOutlineColor] as Color?,
        trackOutlineWidth: v[SwitchField.trackOutlineWidth] as double?,
        focusColor: v[SwitchField.focusColor] as Color?,
        onLabelColor: v[SwitchField.onLabelColor] as Color?,
        offLabelColor: v[SwitchField.offLabelColor] as Color?,
        thumbImage: v[SwitchField.thumbImage] as ImageProvider?,
        thumbIcon: v[SwitchField.thumbIcon] as IconData?,
        thumbIconColor: v[SwitchField.thumbIconColor] as Color?,
        thumbIconSize: v[SwitchField.thumbIconSize] as double?,
        mouseCursor: v[SwitchField.mouseCursor] as MouseCursor?,
        opacity: v[SwitchField.opacity] as double?,
        thumbBackdropColor: v[SwitchField.thumbBackdropColor] as Color?,
      );

  @override
  bool operator ==(Object other) =>
      other is SwitchStyle &&
      other.trackColor == trackColor &&
      other.thumbColor == thumbColor &&
      other.trackOutlineColor == trackOutlineColor &&
      other.trackOutlineWidth == trackOutlineWidth &&
      other.focusColor == focusColor &&
      other.onLabelColor == onLabelColor &&
      other.offLabelColor == offLabelColor &&
      other.thumbImage == thumbImage &&
      other.thumbIcon == thumbIcon &&
      other.thumbIconColor == thumbIconColor &&
      other.thumbIconSize == thumbIconSize &&
      other.mouseCursor == mouseCursor &&
      other.opacity == opacity &&
      other.thumbBackdropColor == thumbBackdropColor;

  @override
  int get hashCode => Object.hash(trackColor, thumbColor, trackOutlineColor, trackOutlineWidth, focusColor, onLabelColor,
      offLabelColor, thumbImage, thumbIcon, thumbIconColor, thumbIconSize, mouseCursor, opacity, thumbBackdropColor);
}

// ---- Derive ------------------------------------------------------------------

@immutable
final class SwitchDerive {
  const SwitchDerive({this.trackColor, this.thumbColor, this.trackOutlineColor, this.focusColor, this.thumbBackdropColor});

  final DeriveSource? trackColor;
  final DeriveSource? thumbColor;
  final DeriveSource? trackOutlineColor;
  final DeriveSource? focusColor;
  final DeriveSource? thumbBackdropColor;

  Derive<SwitchField> toDerive() => Derive<SwitchField>(<SwitchField, DeriveSource>{
        SwitchField.trackColor: ?trackColor,
        SwitchField.thumbColor: ?thumbColor,
        SwitchField.trackOutlineColor: ?trackOutlineColor,
        SwitchField.focusColor: ?focusColor,
        SwitchField.thumbBackdropColor: ?thumbBackdropColor,
      });

  @override
  bool operator ==(Object other) =>
      other is SwitchDerive &&
      other.trackColor == trackColor &&
      other.thumbColor == thumbColor &&
      other.trackOutlineColor == trackOutlineColor &&
      other.focusColor == focusColor &&
      other.thumbBackdropColor == thumbBackdropColor;

  @override
  int get hashCode => Object.hash(trackColor, thumbColor, trackOutlineColor, focusColor, thumbBackdropColor);
}

// ---- Rule --------------------------------------------------------------------

final class SwitchRule extends ComponentRule<SwitchField> {
  const SwitchRule(SwitchWhen this.when,
      {this.style = const SwitchStyle(), this.derive = const SwitchDerive(), this.label})
      : whens = null;

  const SwitchRule.any(List<SwitchWhen> this.whens,
      {this.style = const SwitchStyle(), this.derive = const SwitchDerive(), this.label})
      : when = null;

  final SwitchWhen? when;
  final List<SwitchWhen>? whens;
  final SwitchStyle style;
  final SwitchDerive derive;
  final String? label;

  @override
  void addTo(RuleChannels channels) => channels.add<SwitchRule>(this);

  static final Expando<RawRule<SwitchField>> _raw = Expando<RawRule<SwitchField>>('raw');

  @override
  RawRule<SwitchField> toRaw() => _raw[this] ??= whens == null
      ? RawRule<SwitchField>(when!.toCondition(), style: style.toStyle(), derive: derive.toDerive(), label: label)
      : RawRule<SwitchField>.any(<Condition>[for (final SwitchWhen w in whens!) w.toCondition()],
          style: style.toStyle(), derive: derive.toDerive(), label: label);

  @override
  bool operator ==(Object other) =>
      other is SwitchRule &&
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
// Rule-region constants of the defaults, one class per field, each region a
// `static const` (usable in const rule lists), named by the region it covers
// (see button.g.dart and test/support/region_names.dart). Environment dims
// are never constrained.

/// Regions of `trackColor`.
abstract final class SwitchTrackColorRegions {
  /// Not selected; any disabled / pressed / focused / hovered.
  static const SwitchWhen unselected = SwitchWhen(selected: false);
  /// Selected; any disabled / pressed / focused / hovered.
  static const SwitchWhen selected = SwitchWhen(selected: true);
}

/// Regions of `thumbColor`.
abstract final class SwitchThumbColorRegions {
  /// Not selected; any disabled / pressed / focused / hovered.
  static const SwitchWhen unselected = SwitchWhen(selected: false);
  /// Selected; any disabled / pressed / focused / hovered.
  static const SwitchWhen selected = SwitchWhen(selected: true);
}

/// Regions of `trackOutlineColor`.
abstract final class SwitchTrackOutlineColorRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `trackOutlineWidth`.
abstract final class SwitchTrackOutlineWidthRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `focusColor`.
abstract final class SwitchFocusColorRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `onLabelColor`.
abstract final class SwitchOnLabelColorRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `offLabelColor`.
abstract final class SwitchOffLabelColorRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `thumbImage`.
abstract final class SwitchThumbImageRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `thumbIcon`.
abstract final class SwitchThumbIconRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `thumbIconColor`.
abstract final class SwitchThumbIconColorRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `thumbIconSize`.
abstract final class SwitchThumbIconSizeRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `thumbBackdropColor`.
abstract final class SwitchThumbBackdropColorRegions {
  /// Every state.
  static const SwitchWhen anyState = SwitchWhen();
}

/// Regions of `mouseCursor`.
abstract final class SwitchMouseCursorRegions {
  /// Not disabled; any selected / pressed / focused / hovered.
  static const SwitchWhen enabled = SwitchWhen(disabled: false);
  /// Disabled; any selected / pressed / focused / hovered.
  static const SwitchWhen disabled = SwitchWhen(disabled: true);
}

/// Regions of `opacity`.
abstract final class SwitchOpacityRegions {
  /// Not disabled; any selected / pressed / focused / hovered.
  static const SwitchWhen enabled = SwitchWhen(disabled: false);
  /// Disabled; any selected / pressed / focused / hovered.
  static const SwitchWhen disabled = SwitchWhen(disabled: true);
}
