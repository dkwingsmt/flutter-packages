// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// GENERATED FILE. Do not edit: change the spec and run the generator.
//   spec:      style_codegen/specs/cupertino/switch.dart
//   generator: packages/style_codegen (dart run style_codegen:generate)
// ignore_for_file: library_private_types_in_public_api
part of 'switch.dart';

// ---- Private helpers of the spec (copied) ---------------------------------

const CupertinoDynamicColor _kOffLabelColor = CupertinoDynamicColor.withBrightnessAndContrast(
  debugLabel: 'offSwitchLabel',
  color: Color.fromARGB(255, 179, 179, 179),
  darkColor: Color.fromARGB(255, 179, 179, 179),
  highContrastColor: Color.fromARGB(255, 255, 255, 255),
  darkHighContrastColor: Color.fromARGB(255, 255, 255, 255),
);

// ---- Fields ---------------------------------------------------------------

/// The fields of [Switch], each typed by its value type. Names a field in
/// a source (`SwitchSource.fromField(.trackColor)`) and in a callback
/// (`s.field(.trackColor)`); a field of another type, or of another
/// component, is a compile-time error.
enum SwitchField<T extends Object> {
  trackColor<Color>(),
  thumbColor<Color>(),
  trackOutlineColor<Color>(),
  trackOutlineWidth<double>(),
  focusColor<Color>(),
  onLabelColor<Color>(),
  offLabelColor<Color>(),
  thumbImage<ImageProvider>(),
  thumbIcon<IconData>(),
  thumbIconColor<Color>(),
  thumbIconSize<double>(),
  mouseCursor<MouseCursor>(),
  opacity<double>(),
  thumbBackdropColor<Color>(),
}

// ---- Dimensions -----------------------------------------------------------

/// The dimensions of [Switch]: its state dimensions, then the environment
/// dimensions of the Cupertino library.
abstract final class SwitchDims {
  static const BoolDimension disabled = BoolDimension('disabled');
  /// The switch value.
  static const BoolDimension selected = BoolDimension('selected');
  static const BoolDimension pressed = BoolDimension('pressed');
  static const BoolDimension focused = BoolDimension('focused');
  static const BoolDimension hovered = BoolDimension('hovered');

  static const List<Dimension<Object>> all = <Dimension<Object>>[
    disabled, selected, pressed, focused, hovered,
    EnvDims.brightness, EnvDims.highContrast, EnvDims.interfaceLevel,
  ];
}

// ---- When -----------------------------------------------------------------

/// A condition on [Switch] states: null = unconstrained. Bool dimensions are
/// tri-state; enum dimensions take a positive set.
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
  final Brightness? brightness;
  final bool? highContrast;
  final CupertinoUserInterfaceLevelData? interfaceLevel;

  Condition toCondition() => Condition(<Dimension<Object>, Object>{
        SwitchDims.disabled: ?disabled,
        SwitchDims.selected: ?selected,
        SwitchDims.pressed: ?pressed,
        SwitchDims.focused: ?focused,
        SwitchDims.hovered: ?hovered,
        if (brightness case final Brightness v) EnvDims.brightness: <Object>{v},
        EnvDims.highContrast: ?highContrast,
        if (interfaceLevel case final CupertinoUserInterfaceLevelData v) EnvDims.interfaceLevel: <Object>{v},
      });

  @override
  bool operator ==(Object other) =>
      other is SwitchWhen &&
      other.disabled == disabled &&
      other.selected == selected &&
      other.pressed == pressed &&
      other.focused == focused &&
      other.hovered == hovered &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.interfaceLevel == interfaceLevel;

  @override
  int get hashCode => Object.hash(disabled, selected, pressed, focused, hovered, brightness, highContrast, interfaceLevel);

  @override
  String toString() => toCondition().toString();
}

// ignore: unused_element
int? _setHash(Set<Object>? s) => s == null ? null : Object.hashAllUnordered(s);

// ignore: unused_element
double? _lerpDouble(double? a, double? b, double t) =>
    a == null && b == null ? null : (a ?? 0) + ((b ?? 0) - (a ?? 0)) * t;

// ignore: unused_element
BorderSide? _lerpBorderSide(BorderSide? a, BorderSide? b, double t) =>
    a == null || b == null ? (t < 0.5 ? a : b) : BorderSide.lerp(a, b, t);

// ---- Sources --------------------------------------------------------------

/// The source of one [SwitchStyleSpec] slot whose value type is [T]: a literal
/// ([SwitchSource.value]), another field of the same switch ([SwitchSource.fromField]),
/// a Cupertino token ([SwitchSource.fromToken]), an app token
/// ([SwitchSource.fromCustomToken]) or a callback ([SwitchSource.computed]).
///
/// Only constructors: the engine handles the shared [DeriveSource] (its
/// equality included). The parameter types fix the field enum, the token
/// interface and the view type, so a field, token or result of another
/// type is a compile-time error, and dot shorthands work inside:
/// `.fromField(.trackColor)`, `.fromToken(.primaryColor)`.
///
/// Color slots take [SwitchColorSource], which adds `.opacity` and `.opaque`.
/// Constructors are not inherited, so each subclass repeats the plain ones.
base class SwitchSource<T extends Object> extends DeriveSource {
  /// A literal value. Style data, not a WidgetStateProperty.
  const SwitchSource.value(T super.literal)
      : assert(literal is! WidgetStateProperty<Object?>, 'a style holds data, not a WidgetStateProperty; write one rule per state'),
        super.value();

  /// The final value of [field] of the same switch in the same state.
  const SwitchSource.fromField(SwitchField<T> super.field) : super.field();

  /// A built-in Cupertino token, in the switch's environment.
  const SwitchSource.fromToken(CupertinoToken<T> super.token) : super.token();

  /// Any token that implements the engine's [Token] (an app token group
  /// such as `Brand`), in the switch's environment.
  const SwitchSource.fromCustomToken(Token<T> super.token) : super.customToken();

  /// `compute(s)`, where `s` reads the switch's other final values and
  /// tokens in the same state ([SwitchView]). Use a top-level or static
  /// function: its tear-off is a constant, so the rule stays const and
  /// equal across rebuilds. An inline closure is a new object on every
  /// build. Must be a pure function of what it reads (results are cached).
  const SwitchSource.computed(T Function(SwitchView s) super.function) : super.compute();

  // For the subclasses.
  const SwitchSource._opacity(super.source, super.opacity) : super.opacity();
  const SwitchSource._opaque(super.source) : super.opaque();
}

/// [SwitchSource] for Color slots, with two transforms that wrap another
/// color source (a field, a token, a literal, a callback, or another
/// transform):
///
/// * `.opacity(source, x)`: the result's alpha is `clamp(sourceAlpha * x,
///   0, 1)`. `x` must be finite and >= 0; above 1 raises a translucent
///   source's alpha. A fully transparent source stays transparent.
/// * `.opaque(source)`: alpha 1, the source's color channels (a fully
///   transparent source becomes opaque too).
///
/// `.opacity(.opaque(x), 0.5)` is x at 50%. `.opacity(.value(c), 0.5)` is
/// the const way to write a translucent dynamic color.
final class SwitchColorSource extends SwitchSource<Color> {
  const SwitchColorSource.value(super.literal) : super.value();
  const SwitchColorSource.fromField(super.field) : super.fromField();
  const SwitchColorSource.fromToken(super.token) : super.fromToken();
  const SwitchColorSource.fromCustomToken(super.token) : super.fromCustomToken();
  const SwitchColorSource.computed(super.function) : super.computed();
  const SwitchColorSource.opacity(SwitchColorSource super.source, super.opacity) : super._opacity();
  const SwitchColorSource.opaque(SwitchColorSource super.source) : super._opaque();
}

// ---- Callback view --------------------------------------------------------

/// What a [SwitchSource.computed] callback sees: the final values of one
/// switch in one state, read lazily ([field]: resolved on demand, derives
/// included, memoized per state), the tokens in its environment ([token],
/// [customToken]) and the state itself. Reading a field whose value is
/// being computed (a cycle) throws a RuleError naming it.
extension type const SwitchView(StyleView _view) {
  /// The final value of [field] in this state, or null when unset.
  T? field<T extends Object>(SwitchField<T> field) => _view.read(field) as T?;

  /// A built-in Cupertino token in this state's environment.
  T token<T extends Object>(CupertinoToken<T> token) => _view.readToken(token) as T;

  /// An app token ([Token]) in this state's environment. Every token has a
  /// default, so an unset one is an error.
  T customToken<T extends Object>(Token<T> token) =>
      _view.readToken(token) as T? ?? (throw RuleError('custom token ${token.name} has no value'));

  bool get disabled => _view.minterm[SwitchDims.disabled] as bool;
  bool get selected => _view.minterm[SwitchDims.selected] as bool;
  bool get pressed => _view.minterm[SwitchDims.pressed] as bool;
  bool get focused => _view.minterm[SwitchDims.focused] as bool;
  bool get hovered => _view.minterm[SwitchDims.hovered] as bool;
  Brightness get brightness => _view.minterm[EnvDims.brightness] as Brightness;
  bool get highContrast => _view.minterm[EnvDims.highContrast] as bool;
  CupertinoUserInterfaceLevelData get interfaceLevel => _view.minterm[EnvDims.interfaceLevel] as CupertinoUserInterfaceLevelData;

  /// [color] in this state's environment (an environment-dependent color
  /// picks its variant; a plain color is returned as is).
  Color resolveColor(Color color) => _view.resolveEnv(color) as Color;
}

// ---- Style spec -----------------------------------------------------------

/// The payload of a [SwitchRule]: each slot takes a source (value, field,
/// token, custom token, computed; color slots also `.opacity` / `.opaque`;
/// composite slots also `.parts`).
///
/// [SwitchStyle] is the all-values form of the same class (same storage),
/// reachable as `.values(...)`, so a rule's `style:` takes either. Typed
/// getters exist only on [SwitchStyle].
///
/// Equality is per spelling: `SwitchStyle(trackColor: x)` and
/// `SwitchStyleSpec(trackColor: .value(x))` give the same rule result but are not
/// `==`. The same code compares equal (and const instances are
/// canonicalized), so rebuilding with unchanged rules notifies nothing.
/// `SwitchStyleSpec(...)` and `SwitchStyleSpec.derive(...)` are the same constructor.
@immutable
base class SwitchStyleSpec {
  /// Same as [SwitchStyleSpec.derive].
  const SwitchStyleSpec({
    SwitchColorSource? this._trackColor,
    SwitchColorSource? this._thumbColor,
    SwitchColorSource? this._trackOutlineColor,
    SwitchSource<double>? this._trackOutlineWidth,
    SwitchColorSource? this._focusColor,
    SwitchColorSource? this._onLabelColor,
    SwitchColorSource? this._offLabelColor,
    SwitchSource<ImageProvider>? this._thumbImage,
    SwitchSource<IconData>? this._thumbIcon,
    SwitchColorSource? this._thumbIconColor,
    SwitchSource<double>? this._thumbIconSize,
    SwitchSource<MouseCursor>? this._mouseCursor,
    SwitchSource<double>? this._opacity,
    SwitchColorSource? this._thumbBackdropColor,
  });

  /// Every slot takes a source: `style: .derive(trackColor: .fromToken(...))`.
  const SwitchStyleSpec.derive({
    SwitchColorSource? this._trackColor,
    SwitchColorSource? this._thumbColor,
    SwitchColorSource? this._trackOutlineColor,
    SwitchSource<double>? this._trackOutlineWidth,
    SwitchColorSource? this._focusColor,
    SwitchColorSource? this._onLabelColor,
    SwitchColorSource? this._offLabelColor,
    SwitchSource<ImageProvider>? this._thumbImage,
    SwitchSource<IconData>? this._thumbIcon,
    SwitchColorSource? this._thumbIconColor,
    SwitchSource<double>? this._thumbIconSize,
    SwitchSource<MouseCursor>? this._mouseCursor,
    SwitchSource<double>? this._opacity,
    SwitchColorSource? this._thumbBackdropColor,
  });

  /// Plain values only: [SwitchStyle], written as `style: .values(...)`.
  const factory SwitchStyleSpec.values({
    Color? trackColor,
    Color? thumbColor,
    Color? trackOutlineColor,
    double? trackOutlineWidth,
    Color? focusColor,
    Color? onLabelColor,
    Color? offLabelColor,
    ImageProvider? thumbImage,
    IconData? thumbIcon,
    Color? thumbIconColor,
    double? thumbIconSize,
    MouseCursor? mouseCursor,
    double? opacity,
    Color? thumbBackdropColor,
  }) = SwitchStyle;

  /// For [SwitchStyle]: plain values in the same slots.
  const SwitchStyleSpec._values(
    this._trackColor,
    this._thumbColor,
    this._trackOutlineColor,
    this._trackOutlineWidth,
    this._focusColor,
    this._onLabelColor,
    this._offLabelColor,
    this._thumbImage,
    this._thumbIcon,
    this._thumbIconColor,
    this._thumbIconSize,
    this._mouseCursor,
    this._opacity,
    this._thumbBackdropColor,
  );

  // Each slot holds a plain value (SwitchStyle) or a SwitchSource
  // (SwitchStyleSpec).
  final Object? _trackColor;
  final Object? _thumbColor;
  final Object? _trackOutlineColor;
  final Object? _trackOutlineWidth;
  final Object? _focusColor;
  final Object? _onLabelColor;
  final Object? _offLabelColor;
  final Object? _thumbImage;
  final Object? _thumbIcon;
  final Object? _thumbIconColor;
  final Object? _thumbIconSize;
  final Object? _mouseCursor;
  final Object? _opacity;
  final Object? _thumbBackdropColor;

  /// The engine parts of this payload ([splitSlots]).
  (Style<SwitchField>, Derive<SwitchField>, SubMap<SwitchField>) toEngine() => splitSlots<SwitchField>(
        <SwitchField, Object>{
          SwitchField.trackColor: ?_trackColor,
          SwitchField.thumbColor: ?_thumbColor,
          SwitchField.trackOutlineColor: ?_trackOutlineColor,
          SwitchField.trackOutlineWidth: ?_trackOutlineWidth,
          SwitchField.focusColor: ?_focusColor,
          SwitchField.onLabelColor: ?_onLabelColor,
          SwitchField.offLabelColor: ?_offLabelColor,
          SwitchField.thumbImage: ?_thumbImage,
          SwitchField.thumbIcon: ?_thumbIcon,
          SwitchField.thumbIconColor: ?_thumbIconColor,
          SwitchField.thumbIconSize: ?_thumbIconSize,
          SwitchField.mouseCursor: ?_mouseCursor,
          SwitchField.opacity: ?_opacity,
          SwitchField.thumbBackdropColor: ?_thumbBackdropColor,
        },
      );

  @override
  bool operator ==(Object other) =>
      other is SwitchStyleSpec &&
      other.runtimeType == runtimeType &&
      other._trackColor == _trackColor &&
      other._thumbColor == _thumbColor &&
      other._trackOutlineColor == _trackOutlineColor &&
      other._trackOutlineWidth == _trackOutlineWidth &&
      other._focusColor == _focusColor &&
      other._onLabelColor == _onLabelColor &&
      other._offLabelColor == _offLabelColor &&
      other._thumbImage == _thumbImage &&
      other._thumbIcon == _thumbIcon &&
      other._thumbIconColor == _thumbIconColor &&
      other._thumbIconSize == _thumbIconSize &&
      other._mouseCursor == _mouseCursor &&
      other._opacity == _opacity &&
      other._thumbBackdropColor == _thumbBackdropColor;

  @override
  int get hashCode => Object.hash(runtimeType, _trackColor, _thumbColor, _trackOutlineColor, _trackOutlineWidth, _focusColor, _onLabelColor, _offLabelColor, _thumbImage, _thumbIcon, _thumbIconColor, _thumbIconSize, _mouseCursor, _opacity, _thumbBackdropColor);
}

// ---- Style ----------------------------------------------------------------

/// Every themeable property of [Switch], as values: the all-values form of
/// [SwitchStyleSpec] (same storage; `style: .values(...)`), and the
/// resolved style. Null = not set by this rule. Values are data:
/// closure-style values (WidgetStateColor, WidgetStateMouseCursor) are
/// rejected in debug; environment-dependent values (a dynamic color) are
/// fine (expanded into one plain value per environment when the chain is
/// built).
final class SwitchStyle extends SwitchStyleSpec {
  const SwitchStyle({
    Color? trackColor,
    Color? thumbColor,
    Color? trackOutlineColor,
    double? trackOutlineWidth,
    Color? focusColor,
    Color? onLabelColor,
    Color? offLabelColor,
    ImageProvider? thumbImage,
    IconData? thumbIcon,
    Color? thumbIconColor,
    double? thumbIconSize,
    MouseCursor? mouseCursor,
    double? opacity,
    Color? thumbBackdropColor,
  })  : assert(trackColor is! WidgetStateProperty<Object?>, 'trackColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(thumbColor is! WidgetStateProperty<Object?>, 'thumbColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(trackOutlineColor is! WidgetStateProperty<Object?>, 'trackOutlineColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(focusColor is! WidgetStateProperty<Object?>, 'focusColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(onLabelColor is! WidgetStateProperty<Object?>, 'onLabelColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(offLabelColor is! WidgetStateProperty<Object?>, 'offLabelColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(thumbIconColor is! WidgetStateProperty<Object?>, 'thumbIconColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(mouseCursor is! WidgetStateProperty<Object?>, 'mouseCursor: a style holds data, not a WidgetStateMouseCursor; write one rule per state'),
        assert(thumbBackdropColor is! WidgetStateProperty<Object?>, 'thumbBackdropColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        super._values(trackColor, thumbColor, trackOutlineColor, trackOutlineWidth, focusColor, onLabelColor, offLabelColor, thumbImage, thumbIcon, thumbIconColor, thumbIconSize, mouseCursor, opacity, thumbBackdropColor);

  Color? get trackColor => _trackColor as Color?;
  /// Painted over [thumbBackdropColor] (alpha blend), as before.
  Color? get thumbColor => _thumbColor as Color?;

  Color? get trackOutlineColor => _trackOutlineColor as Color?;
  double? get trackOutlineWidth => _trackOutlineWidth as double?;
  Color? get focusColor => _focusColor as Color?;
  Color? get onLabelColor => _onLabelColor as Color?;
  Color? get offLabelColor => _offLabelColor as Color?;
  ImageProvider? get thumbImage => _thumbImage as ImageProvider?;
  IconData? get thumbIcon => _thumbIcon as IconData?;
  Color? get thumbIconColor => _thumbIconColor as Color?;
  double? get thumbIconSize => _thumbIconSize as double?;
  MouseCursor? get mouseCursor => _mouseCursor as MouseCursor?;
  /// Opacity of the whole switch (0.5 when disabled).
  double? get opacity => _opacity as double?;

  /// What a translucent thumb is blended against (scaffold background).
  Color? get thumbBackdropColor => _thumbBackdropColor as Color?;

  /// Interpolates two resolved styles field by field (design doc 9.2: an
  /// environment transition resolves both ends and lerps them). Colors,
  /// numbers, geometry, TextStyle, IconThemeData and BorderSide
  /// interpolate; other values switch at t = 0.5.
  static SwitchStyle? lerp(SwitchStyle? a, SwitchStyle? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return SwitchStyle(
      trackColor: Color.lerp(a?.trackColor, b?.trackColor, t),
      thumbColor: Color.lerp(a?.thumbColor, b?.thumbColor, t),
      trackOutlineColor: Color.lerp(a?.trackOutlineColor, b?.trackOutlineColor, t),
      trackOutlineWidth: _lerpDouble(a?.trackOutlineWidth, b?.trackOutlineWidth, t),
      focusColor: Color.lerp(a?.focusColor, b?.focusColor, t),
      onLabelColor: Color.lerp(a?.onLabelColor, b?.onLabelColor, t),
      offLabelColor: Color.lerp(a?.offLabelColor, b?.offLabelColor, t),
      thumbImage: t < 0.5 ? a?.thumbImage : b?.thumbImage,
      thumbIcon: t < 0.5 ? a?.thumbIcon : b?.thumbIcon,
      thumbIconColor: Color.lerp(a?.thumbIconColor, b?.thumbIconColor, t),
      thumbIconSize: _lerpDouble(a?.thumbIconSize, b?.thumbIconSize, t),
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      opacity: _lerpDouble(a?.opacity, b?.opacity, t),
      thumbBackdropColor: Color.lerp(a?.thumbBackdropColor, b?.thumbBackdropColor, t),
    );
  }

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
}

// ---- Rule -----------------------------------------------------------------

/// A [Switch] rule: condition + one payload, `style:` (a [SwitchStyleSpec]
/// or its all-values form [SwitchStyle]). Goes in StyleTheme / StyleScope
/// rule lists (mixed with other components' rules) and in
/// `Switch(rules: ...)`. A typed list spread writes the component name once
/// for a group of rules: `...<SwitchRule>[.when(...), .always(...)]`.
///
/// Ways to write one:
///
/// * With a condition: [SwitchRule.when] (the condition's dimensions are
///   named parameters), [SwitchRule.always] (no condition) or
///   [SwitchRule.whenAny] (one of several conditions). Any number of
///   fields. The full-name form `SwitchRule(SwitchWhen(...), style: ...)` is the
///   same rule as `.when(...)` with the same dimensions (and `==` to it).
/// * Per default region: one constructor per field whose library default
///   differs between states. Each named argument is one region of that
///   field, the states where one library default rule (or group of rules
///   with one label) sets it, so a value replaces exactly that default and
///   no other state. Values only; for a derive in one region, write the
///   region's condition with `.when` (listed in each constructor's doc).
///   ([SwitchRule.trackColor], [SwitchRule.thumbColor],
///   [SwitchRule.mouseCursor], [SwitchRule.opacity]). Fields whose default
///   is the same in every state has no region
///   constructor: write `.always(style: ...)`.
final class SwitchRule extends ComponentRule<SwitchField> {
  /// The full-name form of [SwitchRule.when]: the condition as a
  /// [SwitchWhen] object.
  const SwitchRule(SwitchWhen this._when, {required this.style, this.label})
      : whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null;

  /// [style] in the states that match every given dimension (null =
  /// unconstrained; bool dimensions are tri-state, enum dimensions take a
  /// set of allowed values).
  const SwitchRule.when({
    this._disabled,
    this._selected,
    this._pressed,
    this._focused,
    this._hovered,
    this._brightness,
    this._highContrast,
    this._interfaceLevel,
    required this.style,
    this.label,
  })
      : _when = null,
        whens = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null;

  /// [style] in every state.
  const SwitchRule.always({required this.style, this.label})
      : _when = const SwitchWhen(),
        whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null;

  /// Cross-dimension "or": [style] in the states that match any of
  /// [whens] (one engine rule per condition, sharing one position).
  const SwitchRule.whenAny(List<SwitchWhen> this.whens, {required this.style, this.label})
      : _when = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null;

  /// `trackColor` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `unselected`: Not selected; any disabled / pressed / focused / hovered.
  /// * `selected`: Selected; any disabled / pressed / focused / hovered.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// SwitchRule.when(selected: false, style: .values(trackColor: unselected)),
  /// SwitchRule.when(selected: true, style: .values(trackColor: selected)),
  /// ```
  const SwitchRule.trackColor({
    Color? unselected,
    Color? selected,
    this.label,
  })
      : assert(unselected != null || selected != null, 'SwitchRule.trackColor: set at least one region'),
        assert(unselected is! WidgetStateProperty<Object?>, 'SwitchRule.trackColor(unselected:): a rule holds data, not a WidgetStateColor'),
        assert(selected is! WidgetStateProperty<Object?>, 'SwitchRule.trackColor(selected:): a rule holds data, not a WidgetStateColor'),
        _when = null,
        whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const SwitchStyleSpec(),
        _field = SwitchField.trackColor,
        _regions = _switchTrackColorRegions,
        _r0 = unselected,
        _r1 = selected;

  /// `thumbColor` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `unselected`: Not selected; any disabled / pressed / focused / hovered.
  /// * `selected`: Selected; any disabled / pressed / focused / hovered.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// SwitchRule.when(selected: false, style: .values(thumbColor: unselected)),
  /// SwitchRule.when(selected: true, style: .values(thumbColor: selected)),
  /// ```
  const SwitchRule.thumbColor({
    Color? unselected,
    Color? selected,
    this.label,
  })
      : assert(unselected != null || selected != null, 'SwitchRule.thumbColor: set at least one region'),
        assert(unselected is! WidgetStateProperty<Object?>, 'SwitchRule.thumbColor(unselected:): a rule holds data, not a WidgetStateColor'),
        assert(selected is! WidgetStateProperty<Object?>, 'SwitchRule.thumbColor(selected:): a rule holds data, not a WidgetStateColor'),
        _when = null,
        whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const SwitchStyleSpec(),
        _field = SwitchField.thumbColor,
        _regions = _switchThumbColorRegions,
        _r0 = unselected,
        _r1 = selected;

  /// `mouseCursor` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `enabled`: Not disabled; any selected / pressed / focused / hovered.
  /// * `disabled`: Disabled; any selected / pressed / focused / hovered.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// SwitchRule.when(disabled: false, style: .values(mouseCursor: enabled)),
  /// SwitchRule.when(disabled: true, style: .values(mouseCursor: disabled)),
  /// ```
  const SwitchRule.mouseCursor({
    MouseCursor? enabled,
    MouseCursor? disabled,
    this.label,
  })
      : assert(enabled != null || disabled != null, 'SwitchRule.mouseCursor: set at least one region'),
        assert(enabled is! WidgetStateProperty<Object?>, 'SwitchRule.mouseCursor(enabled:): a rule holds data, not a WidgetStateMouseCursor'),
        assert(disabled is! WidgetStateProperty<Object?>, 'SwitchRule.mouseCursor(disabled:): a rule holds data, not a WidgetStateMouseCursor'),
        _when = null,
        whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const SwitchStyleSpec(),
        _field = SwitchField.mouseCursor,
        _regions = _switchMouseCursorRegions,
        _r0 = enabled,
        _r1 = disabled;

  /// `opacity` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `enabled`: Not disabled; any selected / pressed / focused / hovered.
  /// * `disabled`: Disabled; any selected / pressed / focused / hovered.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// SwitchRule.when(disabled: false, style: .values(opacity: enabled)),
  /// SwitchRule.when(disabled: true, style: .values(opacity: disabled)),
  /// ```
  const SwitchRule.opacity({
    double? enabled,
    double? disabled,
    this.label,
  })
      : assert(enabled != null || disabled != null, 'SwitchRule.opacity: set at least one region'),
        _when = null,
        whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const SwitchStyleSpec(),
        _field = SwitchField.opacity,
        _regions = _switchOpacityRegions,
        _r0 = enabled,
        _r1 = disabled;

  /// A legacy `WidgetStateProperty` flat parameter (e.g. a `resolveWith`
  /// closure): one rule in every state whose value for [field] is
  /// [source]'s, falling through to the rules before it where [source]
  /// returns null. Built by [Switch] only; not part of the rule API (a
  /// theme writes rules with conditions instead). The region slots are
  /// reused: [_field] is the field and [_r0] the source.
  const SwitchRule._legacy(SwitchField field, LegacySource source)
      : _when = const SwitchWhen(),
        whens = null,
        _disabled = null,
        _selected = null,
        _pressed = null,
        _focused = null,
        _hovered = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const SwitchStyleSpec(),
        label = null,
        _regions = null,
        _r1 = null,
        _field = field,
        _r0 = source;

  /// The condition: the [SwitchWhen] of the full-name form, or the
  /// dimensions of [SwitchRule.when] as one; `SwitchWhen()` for
  /// [SwitchRule.always]. Null for [SwitchRule.whenAny] and region rules.
  SwitchWhen? get when => _regions != null || whens != null
      ? null
      : _when ??
          SwitchWhen(
            disabled: _disabled,
            selected: _selected,
            pressed: _pressed,
            focused: _focused,
            hovered: _hovered,
            brightness: _brightness,
            highContrast: _highContrast,
            interfaceLevel: _interfaceLevel,
          );

  final SwitchWhen? _when;

  // The dimensions of SwitchRule.when (a const constructor can't build the
  // SwitchWhen itself).
  final bool? _disabled;
  final bool? _selected;
  final bool? _pressed;
  final bool? _focused;
  final bool? _hovered;
  final Brightness? _brightness;
  final bool? _highContrast;
  final CupertinoUserInterfaceLevelData? _interfaceLevel;

  /// The conditions of [SwitchRule.whenAny] (null otherwise).
  final List<SwitchWhen>? whens;

  /// Empty for region rules: their values live in the region slots.
  final SwitchStyleSpec style;

  /// Region name of a default rule (`rest`, `disabled`, ...), or a user
  /// label for reports; null elsewhere.
  final String? label;

  // Region rules: the field, its region table and one value slot per
  // region (as many slots as the field with the most regions has).
  final SwitchField? _field;
  final List<(String, SwitchWhen)>? _regions;
  final Object? _r0;
  final Object? _r1;

  @override
  void addTo(RuleChannels channels) => channels.add<SwitchRule>(this);

  static final Expando<RawRule<SwitchField>> _raw = Expando<RawRule<SwitchField>>('raw');
  static final Expando<List<RawRule<SwitchField>>> _raws = Expando<List<RawRule<SwitchField>>>('raws');

  /// The engine rule of a rule written with a condition. A region rule
  /// expands into several: use [toRaws].
  RawRule<SwitchField> toRaw() {
    if (_regions != null) {
      throw StateError('SwitchRule.${_field!.name}(...) is a region rule and expands into one engine rule '
          'per region; use toRaws()');
    }
    if (_r0 case final LegacySource source) {
      return _raw[this] ??= RawRule<SwitchField>(Condition.all,
          derive: Derive<SwitchField>(<SwitchField, DeriveSource>{_field!: source}));
    }
    if (_raw[this] case final RawRule<SwitchField> r) {
      return r;
    }
    final (Style<SwitchField> st, Derive<SwitchField> d, SubMap<SwitchField> sub) = style.toEngine();
    return _raw[this] = whens == null
        ? RawRule<SwitchField>(when!.toCondition(), style: st, derive: d, sub: sub, label: label)
        : RawRule<SwitchField>.any(<Condition>[for (final SwitchWhen w in whens!) w.toCondition()],
            style: st, derive: d, sub: sub, label: label);
  }

  @override
  List<RawRule<SwitchField>> toRaws() => _raws[this] ??= switch (_regions) {
        null => <RawRule<SwitchField>>[toRaw()],
        final List<(String, SwitchWhen)> regions => regionRawRules<SwitchField>(
            _field!,
            <(String, Condition)>[for (final (String n, SwitchWhen w) in regions) (n, w.toCondition())],
            <Object?>[_r0, _r1],
            label: label),
      };

  @override
  bool operator ==(Object other) =>
      other is SwitchRule &&
      other.when == when &&
      listEquals(other.whens, whens) &&
      other.style == style &&
      other.label == label &&
      other._field == _field &&
      identical(other._regions, _regions) &&
      other._r0 == _r0 &&
      other._r1 == _r1;

  @override
  int get hashCode => Object.hash(when, whens == null ? null : Object.hashAll(whens!), style, label, _field,
      _r0, _r1);
}

// ---- Rule regions ---------------------------------------------------------

// The region tables behind the region constructors, computed by the
// generator from the library defaults (design doc 6.1). A region of a
// field is the set of states where one library default rule (or group
// of rules with one label) sets it. Only fields with more than one
// region get a table and a constructor. Environment dimensions are never
// constrained.

const List<(String, SwitchWhen)> _switchTrackColorRegions = <(String, SwitchWhen)>[
  ('unselected', SwitchWhen(selected: false)),
  ('selected', SwitchWhen(selected: true)),
];

const List<(String, SwitchWhen)> _switchThumbColorRegions = <(String, SwitchWhen)>[
  ('unselected', SwitchWhen(selected: false)),
  ('selected', SwitchWhen(selected: true)),
];

const List<(String, SwitchWhen)> _switchMouseCursorRegions = <(String, SwitchWhen)>[
  ('enabled', SwitchWhen(disabled: false)),
  ('disabled', SwitchWhen(disabled: true)),
];

const List<(String, SwitchWhen)> _switchOpacityRegions = <(String, SwitchWhen)>[
  ('enabled', SwitchWhen(disabled: false)),
  ('disabled', SwitchWhen(disabled: true)),
];

/// The region table of every field that has a region constructor, in
/// constructor argument order. For tools and tests; not exported by the
/// package library.
const Map<SwitchField, List<(String, SwitchWhen)>> switchRegionTable = <SwitchField, List<(String, SwitchWhen)>>{
  SwitchField.trackColor: _switchTrackColorRegions,
  SwitchField.thumbColor: _switchThumbColorRegions,
  SwitchField.mouseCursor: _switchMouseCursorRegions,
  SwitchField.opacity: _switchOpacityRegions,
};

// ---- Library defaults -----------------------------------------------------

/// The library defaults of [Switch] (from the spec), as one const rule
/// list. Labels name regions (rules with one label form one region of a
/// field) and show up in provenance (debugSources).
const List<SwitchRule> switchDefaults = <SwitchRule>[
  .when(selected: false, label: 'rest', style: .values(trackColor: CupertinoColors.secondarySystemFill, thumbColor: CupertinoColors.white)),
  .when(selected: true, label: 'selected', style: .values(trackColor: CupertinoColors.systemGreen, thumbColor: CupertinoColors.white)),
  .always(label: 'rest', style: .derive(trackOutlineWidth: .value(2.0), onLabelColor: .value(CupertinoColors.white), offLabelColor: .value(_kOffLabelColor), thumbIconColor: .value(CupertinoColors.black), thumbIconSize: .value(16.0), opacity: .value(1.0), thumbBackdropColor: .fromToken(.scaffoldBackgroundColor))),
  .when(disabled: false, label: 'rest', style: .values(mouseCursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer)),
  .when(disabled: true, label: 'disabled', style: .values(mouseCursor: MouseCursor.defer, opacity: 0.5)),
];

// ---- Component ------------------------------------------------------------

/// Static description of [Switch] (spec + defaults).
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

/// The minterm of a [Switch] state.
Minterm switchMinterm({
  required bool disabled,
  required bool selected,
  required bool pressed,
  required bool focused,
  required bool hovered,
  required ResolvedEnvironment env,
}) =>
    Minterm(SwitchDims.all, <Object>[disabled, selected, pressed, focused, hovered, ...env.values]);
// ---- Reading resolved styles ----------------------------------------------

/// The resolved [SwitchStyle] at any state (design doc 7.6), without pumping
/// gestures: the library defaults, the StyleTheme and StyleScopes visible
/// at [context], then [rules] (call-site rules, e.g. a widget's own).
/// Environment dimensions not given come from the StyleTheme / StyleScope
/// environment, then from [context]. Backs `Switch.resolveStyle`.
SwitchStyle resolveSwitchStyle(
  BuildContext context, {
  bool disabled = false,
  bool selected = false,
  bool pressed = false,
  bool focused = false,
  bool hovered = false,
  Brightness? brightness,
  bool? highContrast,
  CupertinoUserInterfaceLevelData? interfaceLevel,
  List<SwitchRule> rules = const <SwitchRule>[],
}) {
  final StyleNode node = StyleTheme.peekNode(context);
  final ResolvedEnvironment env = node.effectiveEnvironment
      .merge(StyleEnvironment(brightness: brightness, highContrast: highContrast, interfaceLevel: interfaceLevel))
      .resolve(context);
  return SwitchStyle.fromValues(StyleResolver<SwitchField>(switchStyle).resolve(node, rules, switchMinterm(disabled: disabled, selected: selected, pressed: pressed, focused: focused, hovered: hovered, env: env)));
}

/// [resolveSwitchStyle] without a widget tree (design doc 7.6): [theme] is
/// a StyleTheme rule list, [rules] the call-site rules, and the
/// environment is given (every environment dimension).
SwitchStyle resolveSwitchStyleFromRules({
  List<Rule> theme = const <Rule>[],
  List<SwitchRule> rules = const <SwitchRule>[],
  bool disabled = false,
  bool selected = false,
  bool pressed = false,
  bool focused = false,
  bool hovered = false,
  required Brightness brightness,
  required bool highContrast,
  required CupertinoUserInterfaceLevelData interfaceLevel,
}) {
  final StyleNode node = StyleNode.root(rules: theme);
  final ResolvedEnvironment env = ResolvedEnvironment(brightness: brightness, highContrast: highContrast, interfaceLevel: interfaceLevel);
  return SwitchStyle.fromValues(StyleResolver<SwitchField>(switchStyle).resolve(node, rules, switchMinterm(disabled: disabled, selected: selected, pressed: pressed, focused: focused, hovered: hovered, env: env)));
}
