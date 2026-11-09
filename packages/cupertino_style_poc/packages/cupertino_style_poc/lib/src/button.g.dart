// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// GENERATED FILE. Do not edit: change the spec and run the generator.
//   spec:      style_codegen/specs/cupertino/button.dart
//   generator: packages/style_codegen (dart run style_codegen:generate)
// ignore_for_file: library_private_types_in_public_api
part of 'button.dart';

// ---- Declared in the spec -------------------------------------------------

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

// ---- Fields ---------------------------------------------------------------

/// The fields of [Button], each typed by its value type. Names a field in
/// a source (`ButtonSource.fromField(.backgroundColor)`) and in a callback
/// (`s.field(.backgroundColor)`); a field of another type, or of another
/// component, is a compile-time error.
enum ButtonField<T extends Object> {
  backgroundColor<Color>(),
  foregroundColor<Color>(),
  focusColor<Color>(),
  padding<EdgeInsetsGeometry>(),
  paddingScaler<PaddingScaler>(),
  borderRadius<BorderRadius>(),
  minimumSize<Size>(),
  alignment<AlignmentGeometry>(),
  textStyle<TextStyle>(),
  iconTheme<IconThemeData>(),
  side<BorderSide>(),
  pressedOpacity<double>(),
  mouseCursor<MouseCursor>(),
}

// ---- Dimensions -----------------------------------------------------------

/// The dimensions of [Button]: its state dimensions, then the environment
/// dimensions of the Cupertino library.
abstract final class ButtonDims {
  static const BoolDimension disabled = BoolDimension('disabled');
  static const BoolDimension pressed = BoolDimension('pressed');
  static const BoolDimension focused = BoolDimension('focused');
  static const Dimension<ButtonAppearance> appearance = Dimension<ButtonAppearance>('appearance', ButtonAppearance.values);
  static const Dimension<ButtonSize> sizeStyle = Dimension<ButtonSize>('sizeStyle', ButtonSize.values);

  static const List<Dimension<Object>> all = <Dimension<Object>>[
    disabled, pressed, focused, appearance, sizeStyle,
    EnvDims.brightness, EnvDims.highContrast, EnvDims.interfaceLevel,
  ];
}

// ---- When -----------------------------------------------------------------

/// A condition on [Button] states: null = unconstrained. Bool dimensions are
/// tri-state; enum dimensions take a positive set.
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
  final Brightness? brightness;
  final bool? highContrast;
  final CupertinoUserInterfaceLevelData? interfaceLevel;

  Condition toCondition() => Condition(<Dimension<Object>, Object>{
        ButtonDims.disabled: ?disabled,
        ButtonDims.pressed: ?pressed,
        ButtonDims.focused: ?focused,
        ButtonDims.appearance: ?appearance,
        ButtonDims.sizeStyle: ?sizeStyle,
        if (brightness case final Brightness v) EnvDims.brightness: <Object>{v},
        EnvDims.highContrast: ?highContrast,
        if (interfaceLevel case final CupertinoUserInterfaceLevelData v) EnvDims.interfaceLevel: <Object>{v},
      });

  @override
  bool operator ==(Object other) =>
      other is ButtonWhen &&
      other.disabled == disabled &&
      other.pressed == pressed &&
      other.focused == focused &&
      setEquals(other.appearance, appearance) &&
      setEquals(other.sizeStyle, sizeStyle) &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.interfaceLevel == interfaceLevel;

  @override
  int get hashCode => Object.hash(disabled, pressed, focused, _setHash(appearance), _setHash(sizeStyle), brightness, highContrast, interfaceLevel);

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

/// The source of one [ButtonStyleSpec] slot whose value type is [T]: a literal
/// ([ButtonSource.value]), another field of the same button ([ButtonSource.fromField]),
/// a Cupertino token ([ButtonSource.fromToken]), an app token
/// ([ButtonSource.fromCustomToken]) or a callback ([ButtonSource.computed]).
///
/// Only constructors: the engine handles the shared [DeriveSource] (its
/// equality included). The parameter types fix the field enum, the token
/// interface and the view type, so a field, token or result of another
/// type is a compile-time error, and dot shorthands work inside:
/// `.fromField(.backgroundColor)`, `.fromToken(.primaryColor)`.
///
/// Color slots take [ButtonColorSource], which adds `.opacity` and `.opaque`;
/// composite slots take [ButtonTextStyleSource], [ButtonIconStyleSource], [ButtonBorderSideSource],
/// which add `.parts`.
/// Constructors are not inherited, so each subclass repeats the plain ones.
base class ButtonSource<T extends Object> extends DeriveSource {
  /// A literal value. Style data, not a WidgetStateProperty.
  const ButtonSource.value(T super.literal)
      : assert(literal is! WidgetStateProperty<Object?>, 'a style holds data, not a WidgetStateProperty; write one rule per state'),
        super.value();

  /// The final value of [field] of the same button in the same state.
  const ButtonSource.fromField(ButtonField<T> super.field) : super.field();

  /// A built-in Cupertino token, in the button's environment.
  const ButtonSource.fromToken(CupertinoToken<T> super.token) : super.token();

  /// Any token that implements the engine's [Token] (an app token group
  /// such as `Brand`), in the button's environment.
  const ButtonSource.fromCustomToken(Token<T> super.token) : super.customToken();

  /// `compute(s)`, where `s` reads the button's other final values and
  /// tokens in the same state ([ButtonView]). Use a top-level or static
  /// function: its tear-off is a constant, so the rule stays const and
  /// equal across rebuilds. An inline closure is a new object on every
  /// build. Must be a pure function of what it reads (results are cached).
  const ButtonSource.computed(T Function(ButtonView s) super.function) : super.compute();

  // For the subclasses.
  const ButtonSource._opacity(super.source, super.opacity) : super.opacity();
  const ButtonSource._opaque(super.source) : super.opaque();
  const ButtonSource._parts(super.layout, super.part0, [super.part1]) : super.parts();
}

/// [ButtonSource] for Color slots, with two transforms that wrap another
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
final class ButtonColorSource extends ButtonSource<Color> {
  const ButtonColorSource.value(super.literal) : super.value();
  const ButtonColorSource.fromField(super.field) : super.fromField();
  const ButtonColorSource.fromToken(super.token) : super.fromToken();
  const ButtonColorSource.fromCustomToken(super.token) : super.fromCustomToken();
  const ButtonColorSource.computed(super.function) : super.computed();
  const ButtonColorSource.opacity(ButtonColorSource super.source, super.opacity) : super._opacity();
  const ButtonColorSource.opaque(ButtonColorSource super.source) : super._opaque();
}

/// [ButtonSource] for the TextStyle slot: a whole TextStyle, or `.parts(...)`, which sets only the given sub-properties. Each part competes under "last rule wins"
/// on its own; the other properties keep what the rules before produced.
final class ButtonTextStyleSource extends ButtonSource<TextStyle> {
  const ButtonTextStyleSource.value(super.literal) : super.value();
  const ButtonTextStyleSource.fromField(super.field) : super.fromField();
  const ButtonTextStyleSource.fromToken(super.token) : super.fromToken();
  const ButtonTextStyleSource.fromCustomToken(super.token) : super.fromCustomToken();
  const ButtonTextStyleSource.computed(super.function) : super.computed();

  /// Only the given sub-properties (at least one).
  const ButtonTextStyleSource.parts({ButtonColorSource? color, ButtonColorSource? decorationColor})
      : super._parts(const <SubProp>[SubProp.color, SubProp.decorationColor], color, decorationColor);
}

/// [ButtonSource] for the icon style slot (the design's `IconStyle` value type, IconThemeData in this prototype): a whole value, or `.parts(...)`. Each part competes under "last rule wins"
/// on its own; the other properties keep what the rules before produced.
final class ButtonIconStyleSource extends ButtonSource<IconThemeData> {
  const ButtonIconStyleSource.value(super.literal) : super.value();
  const ButtonIconStyleSource.fromField(super.field) : super.fromField();
  const ButtonIconStyleSource.fromToken(super.token) : super.fromToken();
  const ButtonIconStyleSource.fromCustomToken(super.token) : super.fromCustomToken();
  const ButtonIconStyleSource.computed(super.function) : super.computed();

  /// Only the given sub-properties (at least one).
  const ButtonIconStyleSource.parts({ButtonColorSource? color})
      : super._parts(const <SubProp>[SubProp.color], color);
}

/// [ButtonSource] for a BorderSide slot: a whole BorderSide (which replaces everything before it), or `.parts(...)`, which changes only those sub-properties of the side the rules before produced. Each part competes under "last rule wins"
/// on its own; the other properties keep what the rules before produced.
final class ButtonBorderSideSource extends ButtonSource<BorderSide> {
  const ButtonBorderSideSource.value(super.literal) : super.value();
  const ButtonBorderSideSource.fromField(super.field) : super.fromField();
  const ButtonBorderSideSource.fromToken(super.token) : super.fromToken();
  const ButtonBorderSideSource.fromCustomToken(super.token) : super.fromCustomToken();
  const ButtonBorderSideSource.computed(super.function) : super.computed();

  /// Only the given sub-properties (at least one).
  const ButtonBorderSideSource.parts({ButtonColorSource? color, ButtonSource<double>? width})
      : super._parts(const <SubProp>[SubProp.color, SubProp.width], color, width);
}

// ---- Callback view --------------------------------------------------------

/// What a [ButtonSource.computed] callback sees: the final values of one
/// button in one state, read lazily ([field]: resolved on demand, derives
/// included, memoized per state), the tokens in its environment ([token],
/// [customToken]) and the state itself. Reading a field whose value is
/// being computed (a cycle) throws a RuleError naming it.
extension type const ButtonView(StyleView _view) {
  /// The final value of [field] in this state, or null when unset.
  T? field<T extends Object>(ButtonField<T> field) => _view.read(field) as T?;

  /// A built-in Cupertino token in this state's environment.
  T token<T extends Object>(CupertinoToken<T> token) => _view.readToken(token) as T;

  /// An app token ([Token]) in this state's environment. Every token has a
  /// default, so an unset one is an error.
  T customToken<T extends Object>(Token<T> token) =>
      _view.readToken(token) as T? ?? (throw RuleError('custom token ${token.name} has no value'));

  bool get disabled => _view.minterm[ButtonDims.disabled] as bool;
  bool get pressed => _view.minterm[ButtonDims.pressed] as bool;
  bool get focused => _view.minterm[ButtonDims.focused] as bool;
  ButtonAppearance get appearance => _view.minterm[ButtonDims.appearance] as ButtonAppearance;
  ButtonSize get sizeStyle => _view.minterm[ButtonDims.sizeStyle] as ButtonSize;
  Brightness get brightness => _view.minterm[EnvDims.brightness] as Brightness;
  bool get highContrast => _view.minterm[EnvDims.highContrast] as bool;
  CupertinoUserInterfaceLevelData get interfaceLevel => _view.minterm[EnvDims.interfaceLevel] as CupertinoUserInterfaceLevelData;

  /// [color] in this state's environment (an environment-dependent color
  /// picks its variant; a plain color is returned as is).
  Color resolveColor(Color color) => _view.resolveEnv(color) as Color;
}

// ---- Style spec -----------------------------------------------------------

/// The payload of a [ButtonRule]: each slot takes a source (value, field,
/// token, custom token, computed; color slots also `.opacity` / `.opaque`;
/// composite slots also `.parts`).
///
/// [ButtonStyle] is the all-values form of the same class (same storage),
/// reachable as `.values(...)`, so a rule's `style:` takes either. Typed
/// getters exist only on [ButtonStyle].
///
/// Equality is per spelling: `ButtonStyle(backgroundColor: x)` and
/// `ButtonStyleSpec(backgroundColor: .value(x))` give the same rule result but are not
/// `==`. The same code compares equal (and const instances are
/// canonicalized), so rebuilding with unchanged rules notifies nothing.
/// `ButtonStyleSpec(...)` and `ButtonStyleSpec.derive(...)` are the same constructor.
@immutable
base class ButtonStyleSpec {
  /// Same as [ButtonStyleSpec.derive].
  const ButtonStyleSpec({
    ButtonColorSource? this._backgroundColor,
    ButtonColorSource? this._foregroundColor,
    ButtonColorSource? this._focusColor,
    ButtonSource<EdgeInsetsGeometry>? this._padding,
    ButtonSource<PaddingScaler>? this._paddingScaler,
    ButtonSource<BorderRadius>? this._borderRadius,
    ButtonSource<Size>? this._minimumSize,
    ButtonSource<AlignmentGeometry>? this._alignment,
    ButtonTextStyleSource? this._textStyle,
    ButtonIconStyleSource? this._iconTheme,
    ButtonBorderSideSource? this._side,
    ButtonSource<double>? this._pressedOpacity,
    ButtonSource<MouseCursor>? this._mouseCursor,
  });

  /// Every slot takes a source: `style: .derive(backgroundColor: .fromToken(...))`.
  const ButtonStyleSpec.derive({
    ButtonColorSource? this._backgroundColor,
    ButtonColorSource? this._foregroundColor,
    ButtonColorSource? this._focusColor,
    ButtonSource<EdgeInsetsGeometry>? this._padding,
    ButtonSource<PaddingScaler>? this._paddingScaler,
    ButtonSource<BorderRadius>? this._borderRadius,
    ButtonSource<Size>? this._minimumSize,
    ButtonSource<AlignmentGeometry>? this._alignment,
    ButtonTextStyleSource? this._textStyle,
    ButtonIconStyleSource? this._iconTheme,
    ButtonBorderSideSource? this._side,
    ButtonSource<double>? this._pressedOpacity,
    ButtonSource<MouseCursor>? this._mouseCursor,
  });

  /// Plain values only: [ButtonStyle], written as `style: .values(...)`.
  const factory ButtonStyleSpec.values({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? focusColor,
    EdgeInsetsGeometry? padding,
    PaddingScaler? paddingScaler,
    BorderRadius? borderRadius,
    Size? minimumSize,
    AlignmentGeometry? alignment,
    TextStyle? textStyle,
    IconThemeData? iconTheme,
    BorderSide? side,
    double? pressedOpacity,
    MouseCursor? mouseCursor,
  }) = ButtonStyle;

  /// For [ButtonStyle]: plain values in the same slots.
  const ButtonStyleSpec._values(
    this._backgroundColor,
    this._foregroundColor,
    this._focusColor,
    this._padding,
    this._paddingScaler,
    this._borderRadius,
    this._minimumSize,
    this._alignment,
    this._textStyle,
    this._iconTheme,
    this._side,
    this._pressedOpacity,
    this._mouseCursor,
  );

  // Each slot holds a plain value (ButtonStyle) or a ButtonSource
  // (ButtonStyleSpec).
  final Object? _backgroundColor;
  final Object? _foregroundColor;
  final Object? _focusColor;
  final Object? _padding;
  final Object? _paddingScaler;
  final Object? _borderRadius;
  final Object? _minimumSize;
  final Object? _alignment;
  final Object? _textStyle;
  final Object? _iconTheme;
  final Object? _side;
  final Object? _pressedOpacity;
  final Object? _mouseCursor;

  /// The engine parts of this payload ([splitSlots]).
  (Style<ButtonField>, Derive<ButtonField>, SubMap<ButtonField>) toEngine() => splitSlots<ButtonField>(
        <ButtonField, Object>{
          ButtonField.backgroundColor: ?_backgroundColor,
          ButtonField.foregroundColor: ?_foregroundColor,
          ButtonField.focusColor: ?_focusColor,
          ButtonField.padding: ?_padding,
          ButtonField.paddingScaler: ?_paddingScaler,
          ButtonField.borderRadius: ?_borderRadius,
          ButtonField.minimumSize: ?_minimumSize,
          ButtonField.alignment: ?_alignment,
          ButtonField.textStyle: ?_textStyle,
          ButtonField.iconTheme: ?_iconTheme,
          ButtonField.side: ?_side,
          ButtonField.pressedOpacity: ?_pressedOpacity,
          ButtonField.mouseCursor: ?_mouseCursor,
        },
      );

  @override
  bool operator ==(Object other) =>
      other is ButtonStyleSpec &&
      other.runtimeType == runtimeType &&
      other._backgroundColor == _backgroundColor &&
      other._foregroundColor == _foregroundColor &&
      other._focusColor == _focusColor &&
      other._padding == _padding &&
      other._paddingScaler == _paddingScaler &&
      other._borderRadius == _borderRadius &&
      other._minimumSize == _minimumSize &&
      other._alignment == _alignment &&
      other._textStyle == _textStyle &&
      other._iconTheme == _iconTheme &&
      other._side == _side &&
      other._pressedOpacity == _pressedOpacity &&
      other._mouseCursor == _mouseCursor;

  @override
  int get hashCode => Object.hash(runtimeType, _backgroundColor, _foregroundColor, _focusColor, _padding, _paddingScaler, _borderRadius, _minimumSize, _alignment, _textStyle, _iconTheme, _side, _pressedOpacity, _mouseCursor);
}

// ---- Style ----------------------------------------------------------------

/// Every themeable property of [Button], as values: the all-values form of
/// [ButtonStyleSpec] (same storage; `style: .values(...)`), and the
/// resolved style. Null = not set by this rule. Values are data:
/// closure-style values (WidgetStateColor, WidgetStateMouseCursor) are
/// rejected in debug; environment-dependent values (a dynamic color) are
/// fine (expanded into one plain value per environment when the chain is
/// built).
final class ButtonStyle extends ButtonStyleSpec {
  const ButtonStyle({
    Color? backgroundColor,
    Color? foregroundColor,
    Color? focusColor,
    EdgeInsetsGeometry? padding,
    PaddingScaler? paddingScaler,
    BorderRadius? borderRadius,
    Size? minimumSize,
    AlignmentGeometry? alignment,
    TextStyle? textStyle,
    IconThemeData? iconTheme,
    BorderSide? side,
    double? pressedOpacity,
    MouseCursor? mouseCursor,
  })  : assert(backgroundColor is! WidgetStateProperty<Object?>, 'backgroundColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(foregroundColor is! WidgetStateProperty<Object?>, 'foregroundColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(focusColor is! WidgetStateProperty<Object?>, 'focusColor: a style holds data, not a WidgetStateColor; write one rule per state'),
        assert(mouseCursor is! WidgetStateProperty<Object?>, 'mouseCursor: a style holds data, not a WidgetStateMouseCursor; write one rule per state'),
        super._values(backgroundColor, foregroundColor, focusColor, padding, paddingScaler, borderRadius, minimumSize, alignment, textStyle, iconTheme, side, pressedOpacity, mouseCursor);

  /// The painted background. Unset = no background.
  Color? get backgroundColor => _backgroundColor as Color?;

  /// Text and icon color (followed by textStyle.color / iconTheme.color
  /// through the default derive).
  Color? get foregroundColor => _foregroundColor as Color?;

  /// The focus ring. Unset = computed by the widget from the resolved
  /// background (or activeBlue), as in the original; the same computation
  /// is available as a callback (`defaultButtonFocusColor`).
  Color? get focusColor => _focusColor as Color?;

  /// The padding at a text scale of 1; the widget lays out
  /// `paddingScaler.apply(padding, ...)`.
  EdgeInsetsGeometry? get padding => _padding as EdgeInsetsGeometry?;

  /// How [padding] follows the text scale (default `.identity()`).
  PaddingScaler? get paddingScaler => _paddingScaler as PaddingScaler?;

  BorderRadius? get borderRadius => _borderRadius as BorderRadius?;
  Size? get minimumSize => _minimumSize as Size?;
  AlignmentGeometry? get alignment => _alignment as AlignmentGeometry?;
  /// Merged per property across rules (composite).
  TextStyle? get textStyle => _textStyle as TextStyle?;

  /// Merged per property across rules (composite). An unset size is
  /// computed by the widget from textStyle.fontSize (x 1.2).
  IconThemeData? get iconTheme => _iconTheme as IconThemeData?;

  /// The outline of the button shape. Unset = none. While focused, the
  /// focus ring is drawn instead. A whole BorderSide replaces the earlier
  /// one; `side: .parts(color: ...)` changes only its color.
  BorderSide? get side => _side as BorderSide?;

  /// The opacity the button fades to while pressed (resolved at the
  /// pressed minterm). 1.0 = no fade.
  double? get pressedOpacity => _pressedOpacity as double?;

  MouseCursor? get mouseCursor => _mouseCursor as MouseCursor?;

  /// Interpolates two resolved styles field by field (design doc 9.2: an
  /// environment transition resolves both ends and lerps them). Colors,
  /// numbers, geometry, TextStyle, IconThemeData and BorderSide
  /// interpolate; other values switch at t = 0.5.
  static ButtonStyle? lerp(ButtonStyle? a, ButtonStyle? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ButtonStyle(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      foregroundColor: Color.lerp(a?.foregroundColor, b?.foregroundColor, t),
      focusColor: Color.lerp(a?.focusColor, b?.focusColor, t),
      padding: EdgeInsetsGeometry.lerp(a?.padding, b?.padding, t),
      paddingScaler: t < 0.5 ? a?.paddingScaler : b?.paddingScaler,
      borderRadius: BorderRadius.lerp(a?.borderRadius, b?.borderRadius, t),
      minimumSize: Size.lerp(a?.minimumSize, b?.minimumSize, t),
      alignment: AlignmentGeometry.lerp(a?.alignment, b?.alignment, t),
      textStyle: TextStyle.lerp(a?.textStyle, b?.textStyle, t),
      iconTheme: IconThemeData.lerp(a?.iconTheme, b?.iconTheme, t),
      side: _lerpBorderSide(a?.side, b?.side, t),
      pressedOpacity: _lerpDouble(a?.pressedOpacity, b?.pressedOpacity, t),
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
    );
  }

  static ButtonStyle fromValues(Map<ButtonField, Object> v) => ButtonStyle(
        backgroundColor: v[ButtonField.backgroundColor] as Color?,
        foregroundColor: v[ButtonField.foregroundColor] as Color?,
        focusColor: v[ButtonField.focusColor] as Color?,
        padding: v[ButtonField.padding] as EdgeInsetsGeometry?,
        paddingScaler: v[ButtonField.paddingScaler] as PaddingScaler?,
        borderRadius: v[ButtonField.borderRadius] as BorderRadius?,
        minimumSize: v[ButtonField.minimumSize] as Size?,
        alignment: v[ButtonField.alignment] as AlignmentGeometry?,
        textStyle: v[ButtonField.textStyle] as TextStyle?,
        iconTheme: v[ButtonField.iconTheme] as IconThemeData?,
        side: v[ButtonField.side] as BorderSide?,
        pressedOpacity: v[ButtonField.pressedOpacity] as double?,
        mouseCursor: v[ButtonField.mouseCursor] as MouseCursor?,
      );
}

// ---- Rule -----------------------------------------------------------------

/// A [Button] rule: condition + one payload, `style:` (a [ButtonStyleSpec]
/// or its all-values form [ButtonStyle]). Goes in StyleTheme / StyleScope
/// rule lists (mixed with other components' rules) and in
/// `Button(states: ...)`. A typed list spread writes the component name once
/// for a group of rules: `...<ButtonRule>[.when(...), .always(...)]`.
///
/// Ways to write one:
///
/// * With a condition: [ButtonRule.when] (the condition's dimensions are
///   named parameters), [ButtonRule.always] (no condition) or
///   [ButtonRule.whenAny] (one of several conditions). Any number of
///   fields. The full-name form `ButtonRule(ButtonWhen(...), style: ...)` is the
///   same rule as `.when(...)` with the same dimensions (and `==` to it).
/// * Per default region: one constructor per field whose library default
///   differs between states. Each named argument is one region of that
///   field, the states where one library default rule (or group of rules
///   with one label) sets it, so a value replaces exactly that default and
///   no other state. Values only; for a derive in one region, write the
///   region's condition with `.when` (listed in each constructor's doc).
///   ([ButtonRule.backgroundColor], [ButtonRule.foregroundColor],
///   [ButtonRule.mouseCursor]). Fields whose default is the same in every
///   state has no region
///   constructor: write `.always(style: ...)`.
final class ButtonRule extends ComponentRule<ButtonField> {
  /// The full-name form of [ButtonRule.when]: the condition as a
  /// [ButtonWhen] object.
  const ButtonRule(ButtonWhen this._when, {required this.style, this.label})
      : whens = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null,
        _r2 = null,
        _r3 = null,
        _r4 = null;

  /// [style] in the states that match every given dimension (null =
  /// unconstrained; bool dimensions are tri-state, enum dimensions take a
  /// set of allowed values).
  const ButtonRule.when({
    this._disabled,
    this._pressed,
    this._focused,
    this._appearance,
    this._sizeStyle,
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
        _r1 = null,
        _r2 = null,
        _r3 = null,
        _r4 = null;

  /// [style] in every state.
  const ButtonRule.always({required this.style, this.label})
      : _when = const ButtonWhen(),
        whens = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null,
        _r2 = null,
        _r3 = null,
        _r4 = null;

  /// Cross-dimension "or": [style] in the states that match any of
  /// [whens] (one engine rule per condition, sharing one position).
  const ButtonRule.whenAny(List<ButtonWhen> this.whens, {required this.style, this.label})
      : _when = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        _field = null,
        _regions = null,
        _r0 = null,
        _r1 = null,
        _r2 = null,
        _r3 = null,
        _r4 = null;

  /// `backgroundColor` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `plainAnyState`: Appearance plain; any disabled / pressed / focused.
  /// * `tintedEnabled`: Not disabled, appearance tinted; any pressed / focused.
  /// * `tintedDisabled`: Disabled, appearance tinted; any pressed / focused.
  /// * `filledEnabled`: Not disabled, appearance filled; any pressed / focused.
  /// * `filledDisabled`: Disabled, appearance filled; any pressed / focused.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// ButtonRule.when(appearance: {ButtonAppearance.plain}, style: .values(backgroundColor: plainAnyState)),
  /// ButtonRule.when(disabled: false, appearance: {ButtonAppearance.tinted}, style: .values(backgroundColor: tintedEnabled)),
  /// ButtonRule.when(disabled: true, appearance: {ButtonAppearance.tinted}, style: .values(backgroundColor: tintedDisabled)),
  /// ButtonRule.when(disabled: false, appearance: {ButtonAppearance.filled}, style: .values(backgroundColor: filledEnabled)),
  /// ButtonRule.when(disabled: true, appearance: {ButtonAppearance.filled}, style: .values(backgroundColor: filledDisabled)),
  /// ```
  const ButtonRule.backgroundColor({
    Color? plainAnyState,
    Color? tintedEnabled,
    Color? tintedDisabled,
    Color? filledEnabled,
    Color? filledDisabled,
    this.label,
  })
      : assert(plainAnyState != null || tintedEnabled != null || tintedDisabled != null || filledEnabled != null || filledDisabled != null, 'ButtonRule.backgroundColor: set at least one region'),
        assert(plainAnyState is! WidgetStateProperty<Object?>, 'ButtonRule.backgroundColor(plainAnyState:): a rule holds data, not a WidgetStateColor'),
        assert(tintedEnabled is! WidgetStateProperty<Object?>, 'ButtonRule.backgroundColor(tintedEnabled:): a rule holds data, not a WidgetStateColor'),
        assert(tintedDisabled is! WidgetStateProperty<Object?>, 'ButtonRule.backgroundColor(tintedDisabled:): a rule holds data, not a WidgetStateColor'),
        assert(filledEnabled is! WidgetStateProperty<Object?>, 'ButtonRule.backgroundColor(filledEnabled:): a rule holds data, not a WidgetStateColor'),
        assert(filledDisabled is! WidgetStateProperty<Object?>, 'ButtonRule.backgroundColor(filledDisabled:): a rule holds data, not a WidgetStateColor'),
        _when = null,
        whens = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const ButtonStyleSpec(),
        _field = ButtonField.backgroundColor,
        _regions = _buttonBackgroundColorRegions,
        _r0 = plainAnyState,
        _r1 = tintedEnabled,
        _r2 = tintedDisabled,
        _r3 = filledEnabled,
        _r4 = filledDisabled;

  /// `foregroundColor` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `plainEnabled`: Not disabled, appearance plain; any pressed / focused.
  /// * `plainDisabled`: Disabled, appearance plain; any pressed / focused.
  /// * `tintedEnabled`: Not disabled, appearance tinted; any pressed / focused.
  /// * `tintedDisabled`: Disabled, appearance tinted; any pressed / focused.
  /// * `filledAnyState`: Appearance filled; any disabled / pressed / focused.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// ButtonRule.when(disabled: false, appearance: {ButtonAppearance.plain}, style: .values(foregroundColor: plainEnabled)),
  /// ButtonRule.when(disabled: true, appearance: {ButtonAppearance.plain}, style: .values(foregroundColor: plainDisabled)),
  /// ButtonRule.when(disabled: false, appearance: {ButtonAppearance.tinted}, style: .values(foregroundColor: tintedEnabled)),
  /// ButtonRule.when(disabled: true, appearance: {ButtonAppearance.tinted}, style: .values(foregroundColor: tintedDisabled)),
  /// ButtonRule.when(appearance: {ButtonAppearance.filled}, style: .values(foregroundColor: filledAnyState)),
  /// ```
  const ButtonRule.foregroundColor({
    Color? plainEnabled,
    Color? plainDisabled,
    Color? tintedEnabled,
    Color? tintedDisabled,
    Color? filledAnyState,
    this.label,
  })
      : assert(plainEnabled != null || plainDisabled != null || tintedEnabled != null || tintedDisabled != null || filledAnyState != null, 'ButtonRule.foregroundColor: set at least one region'),
        assert(plainEnabled is! WidgetStateProperty<Object?>, 'ButtonRule.foregroundColor(plainEnabled:): a rule holds data, not a WidgetStateColor'),
        assert(plainDisabled is! WidgetStateProperty<Object?>, 'ButtonRule.foregroundColor(plainDisabled:): a rule holds data, not a WidgetStateColor'),
        assert(tintedEnabled is! WidgetStateProperty<Object?>, 'ButtonRule.foregroundColor(tintedEnabled:): a rule holds data, not a WidgetStateColor'),
        assert(tintedDisabled is! WidgetStateProperty<Object?>, 'ButtonRule.foregroundColor(tintedDisabled:): a rule holds data, not a WidgetStateColor'),
        assert(filledAnyState is! WidgetStateProperty<Object?>, 'ButtonRule.foregroundColor(filledAnyState:): a rule holds data, not a WidgetStateColor'),
        _when = null,
        whens = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const ButtonStyleSpec(),
        _field = ButtonField.foregroundColor,
        _regions = _buttonForegroundColorRegions,
        _r0 = plainEnabled,
        _r1 = plainDisabled,
        _r2 = tintedEnabled,
        _r3 = tintedDisabled,
        _r4 = filledAnyState;

  /// `mouseCursor` per default region. Each argument sets it in its
  /// region only; an unset argument leaves its region to the rules before.
  /// The regions don't overlap:
  ///
  /// * `enabled`: Not disabled; any pressed / focused.
  /// * `disabled`: Disabled; any pressed / focused.
  ///
  /// Equivalent to one rule per argument that is set (copy one to
  /// write a region by hand, e.g. to add a condition or a derive):
  ///
  /// ```dart
  /// ButtonRule.when(disabled: false, style: .values(mouseCursor: enabled)),
  /// ButtonRule.when(disabled: true, style: .values(mouseCursor: disabled)),
  /// ```
  const ButtonRule.mouseCursor({
    MouseCursor? enabled,
    MouseCursor? disabled,
    this.label,
  })
      : assert(enabled != null || disabled != null, 'ButtonRule.mouseCursor: set at least one region'),
        assert(enabled is! WidgetStateProperty<Object?>, 'ButtonRule.mouseCursor(enabled:): a rule holds data, not a WidgetStateMouseCursor'),
        assert(disabled is! WidgetStateProperty<Object?>, 'ButtonRule.mouseCursor(disabled:): a rule holds data, not a WidgetStateMouseCursor'),
        _when = null,
        whens = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const ButtonStyleSpec(),
        _field = ButtonField.mouseCursor,
        _regions = _buttonMouseCursorRegions,
        _r0 = enabled,
        _r1 = disabled,
        _r2 = null,
        _r3 = null,
        _r4 = null;

  /// A legacy `WidgetStateProperty` flat parameter (e.g. a `resolveWith`
  /// closure): one rule in every state whose value for [field] is
  /// [source]'s, falling through to the rules before it where [source]
  /// returns null. Built by [Button] only; not part of the rule API (a
  /// theme writes rules with conditions instead). The region slots are
  /// reused: [_field] is the field and [_r0] the source.
  const ButtonRule._legacy(ButtonField field, LegacySource source)
      : _when = const ButtonWhen(),
        whens = null,
        _disabled = null,
        _pressed = null,
        _focused = null,
        _appearance = null,
        _sizeStyle = null,
        _brightness = null,
        _highContrast = null,
        _interfaceLevel = null,
        style = const ButtonStyleSpec(),
        label = null,
        _regions = null,
        _r1 = null,
        _r2 = null,
        _r3 = null,
        _r4 = null,
        _field = field,
        _r0 = source;

  /// The condition: the [ButtonWhen] of the full-name form, or the
  /// dimensions of [ButtonRule.when] as one; `ButtonWhen()` for
  /// [ButtonRule.always]. Null for [ButtonRule.whenAny] and region rules.
  ButtonWhen? get when => _regions != null || whens != null
      ? null
      : _when ??
          ButtonWhen(
            disabled: _disabled,
            pressed: _pressed,
            focused: _focused,
            appearance: _appearance,
            sizeStyle: _sizeStyle,
            brightness: _brightness,
            highContrast: _highContrast,
            interfaceLevel: _interfaceLevel,
          );

  final ButtonWhen? _when;

  // The dimensions of ButtonRule.when (a const constructor can't build the
  // ButtonWhen itself).
  final bool? _disabled;
  final bool? _pressed;
  final bool? _focused;
  final Set<ButtonAppearance>? _appearance;
  final Set<ButtonSize>? _sizeStyle;
  final Brightness? _brightness;
  final bool? _highContrast;
  final CupertinoUserInterfaceLevelData? _interfaceLevel;

  /// The conditions of [ButtonRule.whenAny] (null otherwise).
  final List<ButtonWhen>? whens;

  /// Empty for region rules: their values live in the region slots.
  final ButtonStyleSpec style;

  /// Region name of a default rule (`rest`, `disabled`, ...), or a user
  /// label for reports; null elsewhere.
  final String? label;

  // Region rules: the field, its region table and one value slot per
  // region (as many slots as the field with the most regions has).
  final ButtonField? _field;
  final List<(String, ButtonWhen)>? _regions;
  final Object? _r0;
  final Object? _r1;
  final Object? _r2;
  final Object? _r3;
  final Object? _r4;

  @override
  void addTo(RuleChannels channels) => channels.add<ButtonRule>(this);

  static final Expando<RawRule<ButtonField>> _raw = Expando<RawRule<ButtonField>>('raw');
  static final Expando<List<RawRule<ButtonField>>> _raws = Expando<List<RawRule<ButtonField>>>('raws');

  /// The engine rule of a rule written with a condition. A region rule
  /// expands into several: use [toRaws].
  RawRule<ButtonField> toRaw() {
    if (_regions != null) {
      throw StateError('ButtonRule.${_field!.name}(...) is a region rule and expands into one engine rule '
          'per region; use toRaws()');
    }
    if (_r0 case final LegacySource source) {
      return _raw[this] ??= RawRule<ButtonField>(Condition.all,
          derive: Derive<ButtonField>(<ButtonField, DeriveSource>{_field!: source}));
    }
    if (_raw[this] case final RawRule<ButtonField> r) {
      return r;
    }
    final (Style<ButtonField> st, Derive<ButtonField> d, SubMap<ButtonField> sub) = style.toEngine();
    return _raw[this] = whens == null
        ? RawRule<ButtonField>(when!.toCondition(), style: st, derive: d, sub: sub, label: label)
        : RawRule<ButtonField>.any(<Condition>[for (final ButtonWhen w in whens!) w.toCondition()],
            style: st, derive: d, sub: sub, label: label);
  }

  @override
  List<RawRule<ButtonField>> toRaws() => _raws[this] ??= switch (_regions) {
        null => <RawRule<ButtonField>>[toRaw()],
        final List<(String, ButtonWhen)> regions => regionRawRules<ButtonField>(
            _field!,
            <(String, Condition)>[for (final (String n, ButtonWhen w) in regions) (n, w.toCondition())],
            <Object?>[_r0, _r1, _r2, _r3, _r4],
            label: label),
      };

  @override
  bool operator ==(Object other) =>
      other is ButtonRule &&
      other.when == when &&
      listEquals(other.whens, whens) &&
      other.style == style &&
      other.label == label &&
      other._field == _field &&
      identical(other._regions, _regions) &&
      other._r0 == _r0 &&
      other._r1 == _r1 &&
      other._r2 == _r2 &&
      other._r3 == _r3 &&
      other._r4 == _r4;

  @override
  int get hashCode => Object.hash(when, whens == null ? null : Object.hashAll(whens!), style, label, _field,
      _r0, _r1, _r2, _r3, _r4);
}

// ---- Rule regions ---------------------------------------------------------

// The region tables behind the region constructors, computed by the
// generator from the library defaults (design doc 6.1). A region of a
// field is the set of states where one library default rule (or group
// of rules with one label) sets it. Only fields with more than one
// region get a table and a constructor. Environment dimensions are never
// constrained.

const List<(String, ButtonWhen)> _buttonBackgroundColorRegions = <(String, ButtonWhen)>[
  ('plainAnyState', ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.plain})),
  ('tintedEnabled', ButtonWhen(disabled: false, appearance: <ButtonAppearance>{ButtonAppearance.tinted})),
  ('tintedDisabled', ButtonWhen(disabled: true, appearance: <ButtonAppearance>{ButtonAppearance.tinted})),
  ('filledEnabled', ButtonWhen(disabled: false, appearance: <ButtonAppearance>{ButtonAppearance.filled})),
  ('filledDisabled', ButtonWhen(disabled: true, appearance: <ButtonAppearance>{ButtonAppearance.filled})),
];

const List<(String, ButtonWhen)> _buttonForegroundColorRegions = <(String, ButtonWhen)>[
  ('plainEnabled', ButtonWhen(disabled: false, appearance: <ButtonAppearance>{ButtonAppearance.plain})),
  ('plainDisabled', ButtonWhen(disabled: true, appearance: <ButtonAppearance>{ButtonAppearance.plain})),
  ('tintedEnabled', ButtonWhen(disabled: false, appearance: <ButtonAppearance>{ButtonAppearance.tinted})),
  ('tintedDisabled', ButtonWhen(disabled: true, appearance: <ButtonAppearance>{ButtonAppearance.tinted})),
  ('filledAnyState', ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.filled})),
];

const List<(String, ButtonWhen)> _buttonMouseCursorRegions = <(String, ButtonWhen)>[
  ('enabled', ButtonWhen(disabled: false)),
  ('disabled', ButtonWhen(disabled: true)),
];

/// The region table of every field that has a region constructor, in
/// constructor argument order. For tools and tests; not exported by the
/// package library.
const Map<ButtonField, List<(String, ButtonWhen)>> buttonRegionTable = <ButtonField, List<(String, ButtonWhen)>>{
  ButtonField.backgroundColor: _buttonBackgroundColorRegions,
  ButtonField.foregroundColor: _buttonForegroundColorRegions,
  ButtonField.mouseCursor: _buttonMouseCursorRegions,
};

// ---- Library defaults -----------------------------------------------------

/// The library defaults of [Button] (from the spec), as one const rule
/// list. Labels name regions (rules with one label form one region of a
/// field) and show up in provenance (debugSources).
const List<ButtonRule> buttonDefaults = <ButtonRule>[
  .always(label: 'rest', style: .values(pressedOpacity: 0.4, alignment: Alignment.center, paddingScaler: .identity())),
  .when(sizeStyle: <ButtonSize>{ButtonSize.small}, label: 'rest', style: .derive(padding: .value(EdgeInsets.symmetric(vertical: 6, horizontal: 12)), borderRadius: .value(BorderRadius.all(Radius.circular(40))), minimumSize: .value(Size(28, 28)), textStyle: .fromToken(.actionSmallTextStyle))),
  .when(sizeStyle: <ButtonSize>{ButtonSize.medium}, label: 'rest', style: .derive(padding: .value(EdgeInsets.symmetric(vertical: 10, horizontal: 15)), borderRadius: .value(BorderRadius.all(Radius.circular(40))), minimumSize: .value(Size(32, 32)), textStyle: .fromToken(.actionTextStyle))),
  .when(sizeStyle: <ButtonSize>{ButtonSize.large}, label: 'rest', style: .derive(padding: .value(EdgeInsets.symmetric(vertical: 16, horizontal: 20)), borderRadius: .value(BorderRadius.all(Radius.circular(12))), minimumSize: .value(Size(44, 44)), textStyle: .fromToken(.actionTextStyle))),
  .when(disabled: false, label: 'rest', style: .derive(foregroundColor: .fromToken(.primaryColor))),
  .when(disabled: true, label: 'disabled', style: .values(foregroundColor: CupertinoColors.tertiaryLabel)),
  .when(appearance: <ButtonAppearance>{ButtonAppearance.filled}, label: 'rest', style: .derive(foregroundColor: .fromToken(.primaryContrastingColor))),
  .when(disabled: false, appearance: <ButtonAppearance>{ButtonAppearance.tinted}, label: 'rest', style: .derive(backgroundColor: .fromToken(.tintedFill))),
  .when(disabled: false, appearance: <ButtonAppearance>{ButtonAppearance.filled}, label: 'rest', style: .derive(backgroundColor: .opaque(.fromToken(.primaryColor)))),
  .when(disabled: true, appearance: <ButtonAppearance>{ButtonAppearance.tinted, ButtonAppearance.filled}, label: 'disabled', style: .values(backgroundColor: CupertinoColors.tertiarySystemFill)),
  .when(disabled: false, label: 'rest', style: .values(mouseCursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer)),
  .when(disabled: true, label: 'disabled', style: .values(mouseCursor: MouseCursor.defer)),
  .always(label: 'rest', style: .derive(textStyle: .parts(color: .fromField(.foregroundColor)), iconTheme: .parts(color: .fromField(.foregroundColor)))),
];

// ---- Component ------------------------------------------------------------

/// Static description of [Button] (spec + defaults).
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
      ButtonField.side: borderSideComposite,
    },
    impossible: <Condition>[
      Condition(<Dimension<Object>, Object>{ButtonDims.disabled: true, ButtonDims.pressed: true}),
      Condition(<Dimension<Object>, Object>{ButtonDims.disabled: true, ButtonDims.focused: true}),
    ],
  ),
  defaults: <RawRule<ButtonField>>[for (final ButtonRule r in buttonDefaults) r.toRaw()],
);

/// The minterm of a [Button] state.
Minterm buttonMinterm({
  required bool disabled,
  required bool pressed,
  required bool focused,
  required ButtonAppearance appearance,
  required ButtonSize sizeStyle,
  required ResolvedEnvironment env,
}) =>
    Minterm(ButtonDims.all, <Object>[disabled, pressed, focused, appearance, sizeStyle, ...env.values]);
// ---- Reading resolved styles ----------------------------------------------

/// The resolved [ButtonStyle] at any state (design doc 7.6), without pumping
/// gestures: the library defaults, the StyleTheme and StyleScopes visible
/// at [context], then [states] (call-site rules, e.g. a widget's own).
/// Environment dimensions not given come from the StyleTheme / StyleScope
/// environment, then from [context]. Backs `Button.resolveStyle`.
ButtonStyle resolveButtonStyle(
  BuildContext context, {
  bool disabled = false,
  bool pressed = false,
  bool focused = false,
  required ButtonAppearance appearance,
  required ButtonSize sizeStyle,
  Brightness? brightness,
  bool? highContrast,
  CupertinoUserInterfaceLevelData? interfaceLevel,
  List<ButtonRule> states = const <ButtonRule>[],
}) {
  final StyleNode node = StyleTheme.peekNode(context);
  final ResolvedEnvironment env = node.effectiveEnvironment
      .merge(StyleEnvironment(brightness: brightness, highContrast: highContrast, interfaceLevel: interfaceLevel))
      .resolve(context);
  return ButtonStyle.fromValues(StyleResolver<ButtonField>(buttonStyle).resolve(node, states, buttonMinterm(disabled: disabled, pressed: pressed, focused: focused, appearance: appearance, sizeStyle: sizeStyle, env: env)));
}

/// [resolveButtonStyle] without a widget tree (design doc 7.6): [theme] is
/// a StyleTheme rule list, [states] the call-site rules, and the
/// environment is given (every environment dimension).
ButtonStyle resolveButtonStyleFromRules({
  List<Rule> theme = const <Rule>[],
  List<ButtonRule> states = const <ButtonRule>[],
  bool disabled = false,
  bool pressed = false,
  bool focused = false,
  required ButtonAppearance appearance,
  required ButtonSize sizeStyle,
  required Brightness brightness,
  required bool highContrast,
  required CupertinoUserInterfaceLevelData interfaceLevel,
}) {
  final StyleNode node = StyleNode.root(rules: theme);
  final ResolvedEnvironment env = ResolvedEnvironment(brightness: brightness, highContrast: highContrast, interfaceLevel: interfaceLevel);
  return ButtonStyle.fromValues(StyleResolver<ButtonField>(buttonStyle).resolve(node, states, buttonMinterm(disabled: disabled, pressed: pressed, focused: focused, appearance: appearance, sizeStyle: sizeStyle, env: env)));
}
