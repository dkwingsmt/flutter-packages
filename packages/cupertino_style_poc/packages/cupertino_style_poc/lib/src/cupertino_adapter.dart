// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Cupertino adapter: the built-in Cupertino token defaults, the app-side
/// Brand group (sample), the expansion of CupertinoDynamicColors into
/// environment-conditioned rules (and its debug check), and expansion of
/// map-form WidgetStateProperty values into rules.
library;

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoColors, CupertinoDynamicColor, CupertinoThemeData, CupertinoUserInterfaceLevelData;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'engine/engine.dart';
import 'engine/widgets.dart';
import 'style_library.dart';

part 'cupertino_adapter.facade.g.dart';

// ---------------------------------------------------------------------------
// CupertinoDynamicColor: a way of writing eight plain colors at once,
// expanded into environment-conditioned rules at chain build.

/// Picks the variant of [c] for an environment. Same choice as
/// `CupertinoDynamicColor.resolveFrom`.
Color resolveDynamicColor(CupertinoDynamicColor c,
    {required Brightness brightness, required bool highContrast, required CupertinoUserInterfaceLevelData level}) {
  final bool dark = brightness == Brightness.dark;
  final bool elevated = level == CupertinoUserInterfaceLevelData.elevated;
  return switch ((dark, highContrast, elevated)) {
    (false, false, false) => c.color,
    (true, false, false) => c.darkColor,
    (false, true, false) => c.highContrastColor,
    (true, true, false) => c.darkHighContrastColor,
    (false, false, true) => c.elevatedColor,
    (true, false, true) => c.darkElevatedColor,
    (false, true, true) => c.highContrastElevatedColor,
    (true, true, true) => c.darkHighContrastElevatedColor,
  };
}

/// The [EnvSplitter] for Cupertino. The ground truth of a style color is a
/// plain [Color]; a CupertinoDynamicColor is a way of writing one plain
/// color per environment slot (brightness x highContrast x
/// interfaceLevel). When a chain is built, every rule holding one, directly
/// or inside TextStyle (color, decorationColor, backgroundColor),
/// IconThemeData (color) or BorderSide (color), is expanded into
/// environment-conditioned sub-rules with plain colors
/// ([expandEnvValues]); the authored const rule lists are not touched.
///
/// Dynamic colors nested anywhere else (a BoxShadow list, a Gradient, a
/// ShapeBorder side, TextStyle.shadows, ...) can't be expanded;
/// [debugUnresolved] finds them for the debug check
/// ([debugCheckEnvExpandable]).
final class CupertinoEnvSplitter extends EnvSplitter {
  const CupertinoEnvSplitter();

  static final List<Map<Dimension<Object>, Object>> _slots = List<Map<Dimension<Object>, Object>>.unmodifiable(
      <Map<Dimension<Object>, Object>>[
    for (final Brightness b in Brightness.values)
      for (final bool hc in <bool>[false, true])
        for (final CupertinoUserInterfaceLevelData l in CupertinoUserInterfaceLevelData.values)
          Map<Dimension<Object>, Object>.unmodifiable(<Dimension<Object>, Object>{
            EnvDims.brightness: b,
            EnvDims.highContrast: hc,
            EnvDims.interfaceLevel: l,
          }),
  ]);

  @override
  List<Map<Dimension<Object>, Object>> get slots => _slots;

  @override
  bool varies(Object value) => switch (value) {
        CupertinoDynamicColor() => true,
        final TextStyle t =>
          t.color is CupertinoDynamicColor ||
              t.decorationColor is CupertinoDynamicColor ||
              t.backgroundColor is CupertinoDynamicColor,
        final IconThemeData i => i.color is CupertinoDynamicColor,
        final BorderSide b => b.color is CupertinoDynamicColor,
        _ => false,
      };

  @override
  Object at(Object value, Map<Dimension<Object>, Object> slot) {
    final Brightness brightness = slot[EnvDims.brightness]! as Brightness;
    final bool highContrast = slot[EnvDims.highContrast]! as bool;
    final CupertinoUserInterfaceLevelData level = slot[EnvDims.interfaceLevel]! as CupertinoUserInterfaceLevelData;
    Color? r(Color? c) => c is CupertinoDynamicColor
        ? resolveDynamicColor(c, brightness: brightness, highContrast: highContrast, level: level)
        : c;
    return switch (value) {
      final CupertinoDynamicColor c => r(c)!,
      final TextStyle t =>
        t.copyWith(color: r(t.color), decorationColor: r(t.decorationColor), backgroundColor: r(t.backgroundColor)),
      final IconThemeData i => i.copyWith(color: r(i.color)),
      final BorderSide b => b.copyWith(color: r(b.color)),
      _ => value,
    };
  }

  /// [value] in environment [env] (a minterm with the environment
  /// dimensions), e.g. for tests.
  Object resolve(Object value, Minterm env) => varies(value)
      ? at(value, <Dimension<Object>, Object>{for (final Dimension<Object> d in EnvDims.all) d: env[d]})
      : value;

  @override
  String? debugUnresolved(Object value) => switch (value) {
        CupertinoDynamicColor() => null,
        final TextStyle t => _findDynamic(t.shadows, 'TextStyle.shadows'),
        final IconThemeData i => _findDynamic(i.shadows, 'IconThemeData.shadows'),
        BorderSide() => null,
        _ => _findDynamic(value, '${value.runtimeType}'),
      };

  @override
  String get debugResolvedPlaces => 'A CupertinoDynamicColor is expanded per environment only as a field value '
      'itself and in TextStyle color / decorationColor / backgroundColor, IconThemeData.color and '
      'BorderSide.color. Use one of those places, or write environment-conditioned rules '
      '(brightness / highContrast / interfaceLevel) holding plain colors.';

  @override
  String describe(Object value) {
    String name(Color? c) => c is CupertinoDynamicColor ? c.toString().split('(').first : '';
    return switch (value) {
      final CupertinoDynamicColor c => name(c),
      final TextStyle t => 'TextStyle(${<String>[
          if (t.color is CupertinoDynamicColor) 'color: ${name(t.color)}',
          if (t.decorationColor is CupertinoDynamicColor) 'decorationColor: ${name(t.decorationColor)}',
          if (t.backgroundColor is CupertinoDynamicColor) 'backgroundColor: ${name(t.backgroundColor)}',
        ].join(', ')})',
      final IconThemeData i => 'IconThemeData(color: ${name(i.color)})',
      final BorderSide b => 'BorderSide(color: ${name(b.color)})',
      _ => '$value',
    };
  }

  @override
  String slotValueName(Dimension<Object> d, Object v) => switch (v) {
        final Brightness b => b.name,
        final CupertinoUserInterfaceLevelData l => l.name,
        true when d == EnvDims.highContrast => 'high-contrast',
        false when d == EnvDims.highContrast => 'normal-contrast',
        _ => super.slotValueName(d, v),
      };
}

/// Path of the first CupertinoDynamicColor inside [v] (at [path]), or null.
/// Knows the common value types that hold colors; other types are not
/// searched.
String? _findDynamic(Object? v, String path) {
  String? first(List<(Object?, String)> xs) {
    for (final (Object? x, String p) in xs) {
      if (_findDynamic(x, p) case final String found) {
        return found;
      }
    }
    return null;
  }

  return switch (v) {
    null => null,
    CupertinoDynamicColor() => path,
    Color() => null,
    final List<Object?> l => first(<(Object?, String)>[for (int i = 0; i < l.length; i++) (l[i], '$path[$i]')]),
    final Shadow s => _findDynamic(s.color, '$path.color'),
    final BorderSide s => _findDynamic(s.color, '$path.color'),
    final Gradient g => _findDynamic(g.colors, '$path.colors'),
    final Border b => first(<(Object?, String)>[
        (b.top, '$path.top'), (b.right, '$path.right'), (b.bottom, '$path.bottom'), (b.left, '$path.left'), //
      ]),
    final BorderDirectional b => first(<(Object?, String)>[
        (b.top, '$path.top'), (b.start, '$path.start'), (b.end, '$path.end'), (b.bottom, '$path.bottom'), //
      ]),
    final OutlinedBorder o => _findDynamic(o.side, '$path.side'),
    final BoxDecoration d => first(<(Object?, String)>[
        (d.color, '$path.color'), (d.border, '$path.border'), (d.boxShadow, '$path.boxShadow'), //
        (d.gradient, '$path.gradient'),
      ]),
    final ShapeDecoration d => first(<(Object?, String)>[
        (d.color, '$path.color'), (d.shape, '$path.shape'), (d.shadows, '$path.shadows'), //
        (d.gradient, '$path.gradient'),
      ]),
    final TextStyle t => first(<(Object?, String)>[
        (t.color, '$path.color'), (t.decorationColor, '$path.decorationColor'), //
        (t.backgroundColor, '$path.backgroundColor'), (t.shadows, '$path.shadows'),
      ]),
    final IconThemeData i => first(<(Object?, String)>[(i.color, '$path.color'), (i.shadows, '$path.shadows')]),
    _ => null,
  };
}

/// The splitter every Cupertino chain is expanded with.
const CupertinoEnvSplitter cupertinoEnvSplitter = CupertinoEnvSplitter();

/// A dynamic color whose eight variants are [f] of [c]'s variants (a
/// plain color is its own variant everywhere).
Color mapColorVariants(Color c, Color Function(Color variant, Brightness brightness) f, {String? debugLabel}) {
  final CupertinoDynamicColor d = c is CupertinoDynamicColor
      ? c
      : CupertinoDynamicColor(
          color: c,
          darkColor: c,
          highContrastColor: c,
          darkHighContrastColor: c,
          elevatedColor: c,
          darkElevatedColor: c,
          highContrastElevatedColor: c,
          darkHighContrastElevatedColor: c);
  const Brightness l = Brightness.light;
  const Brightness k = Brightness.dark;
  return CupertinoDynamicColor(
    debugLabel: debugLabel,
    color: f(d.color, l),
    darkColor: f(d.darkColor, k),
    highContrastColor: f(d.highContrastColor, l),
    darkHighContrastColor: f(d.darkHighContrastColor, k),
    elevatedColor: f(d.elevatedColor, l),
    darkElevatedColor: f(d.darkElevatedColor, k),
    highContrastElevatedColor: f(d.highContrastElevatedColor, l),
    darkHighContrastElevatedColor: f(d.darkHighContrastElevatedColor, k),
  );
}

/// Debug check used by the generated XStyle constructors: style values are
/// data, so closure-style values (WidgetStateColor, WidgetStateMouseCursor,
/// any WidgetStateProperty) are rejected. CupertinoDynamicColor is
/// accepted (it is expanded per environment when the chain is built).
bool debugIsStyleData(Object? v) => v is! WidgetStateProperty<Object?>;

// ---------------------------------------------------------------------------
// Built-in Cupertino tokens: library defaults. The token interface
// (CupertinoToken), its private enum, the group (cupertinoTokenGroup) and
// CupertinoTokenRule are generated into cupertino_adapter.facade.g.dart.

/// The default CupertinoThemeData, whose values are the library defaults of
/// the built-in tokens.
const CupertinoThemeData _defaultTheme = CupertinoThemeData();

/// The library default of the global channel: the default
/// CupertinoThemeData's values (dynamic colors, expanded per environment).
/// Not const: the values are getters of CupertinoThemeData.
final CupertinoTokenRule cupertinoDefaultTokens = CupertinoTokenRule(
  primaryColor: _defaultTheme.primaryColor,
  primaryContrastingColor: _defaultTheme.primaryContrastingColor,
  barBackgroundColor: _defaultTheme.barBackgroundColor,
  scaffoldBackgroundColor: _defaultTheme.scaffoldBackgroundColor,
  textStyle: _defaultTheme.textTheme.textStyle,
  actionTextStyle: _defaultTheme.textTheme.actionTextStyle,
  actionSmallTextStyle: _defaultTheme.textTheme.actionSmallTextStyle,
);

/// Original constants (cupertino_ui constants.dart): the tinted button
/// fill opacity per brightness.
const double kTintedFillOpacityLight = 0.12; // kCupertinoButtonTintedOpacityLight
const double kTintedFillOpacityDark = 0.26; // kCupertinoButtonTintedOpacityDark

/// The derived library tokens: [CupertinoToken.tintedFill] is primaryColor
/// at the tinted opacity, one token rule per brightness. Token rules may
/// be environment-conditioned (tokens have no regions); component defaults
/// then reference the token as one rule without environment conditions.
const List<TokenRule> cupertinoDefaultTokenRules = <TokenRule>[
  CupertinoTokenRule.derive(
    when: TokenWhen(brightness: Brightness.light),
    tintedFill: .opacity(.fromToken(.primaryColor), kTintedFillOpacityLight),
  ),
  CupertinoTokenRule.derive(
    when: TokenWhen(brightness: Brightness.dark),
    tintedFill: .opacity(.fromToken(.primaryColor), kTintedFillOpacityDark),
  ),
];

/// [cupertinoDefaultTokens] with a label, as rule #0 of every global
/// channel (the label shows up in debug provenance), then the derived
/// tokens ([cupertinoDefaultTokenRules]).
final List<RawRule<Enum>> _cupertinoDefaultsRaw = <RawRule<Enum>>[
  RawRule<Enum>(Condition.all, style: cupertinoDefaultTokens.toRaw().style, label: 'Cupertino defaults'),
  for (final TokenRule r in cupertinoDefaultTokenRules)
    RawRule<Enum>(r.when.toCondition(), derive: r.toRaw().derive, label: 'Cupertino derived tokens'),
];

/// Builds the global channel from the built-in group, the app [groups] and
/// [rules] (library defaults first). Dynamic colors in token values are
/// expanded into environment-conditioned rules (once per authored rule,
/// see [flatten]). Debug: token rules go through [debugCheckEnvExpandable].
Tokens buildTokens(List<TokenGroup> groups, List<TokenRule> rules) {
  final GroupChannelSpec spec = groupChannelSpec(
    'GlobalTokens',
    <TokenGroup>[cupertinoTokenGroup, ...groups],
    dimensions: EnvDims.all,
    composites: const <Type, Composite>{TextStyle: tokenTextStyleComposite},
  );
  final List<RawRule<Enum>> raw = <RawRule<Enum>>[
    ..._cupertinoDefaultsRaw,
    for (final TokenRule r in rules) r.toRaw(),
  ];
  return Tokens(TokenChannel<Enum>(spec, raw, splitter: cupertinoEnvSplitter));
}

// ---------------------------------------------------------------------------
// Token-layer sources: what `token.setFrom(...)` takes.

/// The source of a token in a token rule (`Brand.accent.setFrom(...)`): a
/// literal, a Cupertino token or any other token. Only constructors; the
/// parameter types check the value type against the token's, and dot
/// shorthands work inside: `.fromToken(.primaryColor)`. Color tokens take
/// [CupertinoTokenColorSource], which adds `.opacity` and `.opaque`.
base class CupertinoTokenSource<T extends Object> extends DeriveSource {
  /// A literal value.
  const CupertinoTokenSource.value(T super.literal) : super.value();

  /// A built-in Cupertino token, in the same environment.
  const CupertinoTokenSource.fromToken(CupertinoToken<T> super.token) : super.token();

  /// Any token that implements the engine's [Token] (an app group such as
  /// `Brand`), in the same environment.
  const CupertinoTokenSource.fromCustomToken(Token<T> super.token) : super.customToken();

  const CupertinoTokenSource._opacity(super.source, super.opacity) : super.opacity();
  const CupertinoTokenSource._opaque(super.source) : super.opaque();
}

/// [CupertinoTokenSource] for Color tokens, with the alpha transforms of
/// component color slots: `.opacity(source, x)` multiplies the alpha
/// (`clamp(sourceAlpha * x, 0, 1)`, x finite and >= 0) and `.opaque(source)`
/// sets it to 1.
final class CupertinoTokenColorSource extends CupertinoTokenSource<Color> {
  const CupertinoTokenColorSource.value(super.literal) : super.value();
  const CupertinoTokenColorSource.fromToken(super.token) : super.fromToken();
  const CupertinoTokenColorSource.fromCustomToken(super.token) : super.fromCustomToken();
  const CupertinoTokenColorSource.opacity(CupertinoTokenColorSource super.source, super.opacity) : super._opacity();
  const CupertinoTokenColorSource.opaque(CupertinoTokenColorSource super.source) : super._opaque();
}

/// Sets one token from a source: `Brand.pressedAccent.setFrom(.fromCustomToken(Brand.accent))`.
/// The receiver fixes the source's value type.
extension CupertinoTokenSetFrom<T extends Object> on Token<T> {
  TokenRule setFrom(CupertinoTokenSource<T> source, {TokenWhen when = const TokenWhen()}) =>
      SingleTokenRule.from(this, source, when: when);
}

/// [CupertinoTokenSetFrom] for Color tokens, so the source can be an alpha
/// transform: `Brand.pressedAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.5))`.
extension CupertinoColorTokenSetFrom on Token<Color> {
  TokenRule setFrom(CupertinoTokenColorSource source, {TokenWhen when = const TokenWhen()}) =>
      SingleTokenRule.from(this, source, when: when);
}

// ---------------------------------------------------------------------------
// App-side sample group: Brand (public enum, no facade, written by hand
// the way an app would). Its tokens implement only the engine's Token<T>
// (through GroupTokenMixin), so components take them with
// `.fromCustomToken(Brand.accent)`.

/// A sample app token group. Register it with
/// `StyleTheme(groups: [Brand.group])`, set it with [BrandRule] (presets:
/// [BrandRule.teal], [BrandRule.purple]) and read it with
/// `Brand.accent.of(context)`.
enum Brand<T extends Object> with GroupTokenMixin<T> {
  accent<Color>(),
  onAccent<Color>(),
  pressedAccent<Color>(),
  cornerRadius<double>();

  const Brand({this.lerp});

  @override
  final T? Function(T? a, T? b, double t)? lerp;

  static const TokenGroup group = TokenGroup('Brand', values);
}

/// The rule class of [Brand], written by hand the way an app without code
/// generation would: one typed, optional parameter per token; only the
/// tokens given are set. Const, and `BrandRule(accent: 3)` is a
/// compile-time error. To derive a token from another, use
/// `Brand.x.setFrom(...)`.
final class BrandRule extends TokenValueRule {
  const BrandRule({this.accent, this.onAccent, this.pressedAccent, this.cornerRadius, super.when});

  final Color? accent;
  final Color? onAccent;
  final Color? pressedAccent;
  final double? cornerRadius;

  @override
  Map<Token<Object>, Object> get values => <Token<Object>, Object>{
        Brand.accent: ?accent,
        Brand.onAccent: ?onAccent,
        Brand.pressedAccent: ?pressedAccent,
        Brand.cornerRadius: ?cornerRadius,
      };

  /// Sample preset: teal. Dynamic colors are fine as token values: they
  /// are expanded per environment like any other dynamic color.
  static const List<TokenRule> teal = <TokenRule>[
    BrandRule(accent: brandTealAccent, onAccent: CupertinoColors.white, pressedAccent: brandTealPressedAccent, cornerRadius: 6),
  ];

  /// Sample preset: purple.
  static const List<TokenRule> purple = <TokenRule>[
    BrandRule(
        accent: brandPurpleAccent, onAccent: CupertinoColors.white, pressedAccent: brandPurplePressedAccent, cornerRadius: 18),
  ];
}

/// The accent of [BrandRule.teal].
const CupertinoDynamicColor brandTealAccent = CupertinoDynamicColor.withBrightnessAndContrast(
  color: Color(0xFF00897B),
  darkColor: Color(0xFF4DB6AC),
  highContrastColor: Color(0xFF00574B),
  darkHighContrastColor: Color(0xFF80CBC4),
);

/// The pressed accent of [BrandRule.teal].
const CupertinoDynamicColor brandTealPressedAccent =
    CupertinoDynamicColor.withBrightness(color: Color(0xFF00695C), darkColor: Color(0xFF00897B));

/// The accent of [BrandRule.purple].
const CupertinoDynamicColor brandPurpleAccent = CupertinoDynamicColor.withBrightnessAndContrast(
  color: Color(0xFF7B1FA2),
  darkColor: Color(0xFFBA68C8),
  highContrastColor: Color(0xFF4A0072),
  darkHighContrastColor: Color(0xFFE1BEE7),
);

/// The pressed accent of [BrandRule.purple].
const CupertinoDynamicColor brandPurplePressedAccent =
    CupertinoDynamicColor.withBrightness(color: Color(0xFF4A148C), darkColor: Color(0xFF8E24AA));

// ---------------------------------------------------------------------------
// Map-form WidgetStateProperty -> rules.

/// One cube of a state table: dimension -> required value (absent = any).
typedef StateCube = Map<WidgetState, bool>;

/// A legacy `WidgetStateProperty` flat parameter as one legacy rule value
/// ([LegacySource]): at a minterm the value is
/// `property.resolve(statesOf(minterm))`, where [statesOf] gives the set of
/// widget states the original widget passes for that field (e.g. the
/// switch resolves its track outline with `selected` added or removed for
/// the two ends, and never with `pressed`). A null result means "not set":
/// the field falls through to the rules before it (theme, defaults).
///
/// Nothing is sampled ahead of time (no truth table), so a
/// `resolveWith` closure may read anything; for the same reason values
/// that involve it are re-evaluated on every lookup instead of being
/// cached ([BoundCache]). A dynamic color it returns is resolved at the
/// minterm's environment.
///
/// Equality: [property] by `==` (identity for a closure-based property)
/// and [statesOf] (a top-level function per field, so equal across
/// builds). A property object kept across rebuilds keeps the call-site
/// rule equal; an inline `resolveWith` in `build` makes a new rule every
/// build, like any inline closure.
@immutable
final class WidgetStatePropertyRule extends LegacySource {
  const WidgetStatePropertyRule(this.property, this.statesOf);

  final WidgetStateProperty<Object?> property;
  final Set<WidgetState> Function(Minterm m) statesOf;

  @override
  Object? resolveAt(Minterm m) => property.resolve(statesOf(m));

  @override
  bool operator ==(Object other) =>
      other is WidgetStatePropertyRule && other.property == property && other.statesOf == statesOf;

  @override
  int get hashCode => Object.hash(property, statesOf);

  @override
  String toString() => 'WidgetStatePropertyRule($property)';
}

/// Whether a `WidgetStateProperty` flat parameter can become plain rules
/// by expansion ([expandWidgetStateProperty]): a map-form value or a
/// [WidgetStatePropertyAll]. Everything else (a `resolveWith` closure, a
/// custom subclass) becomes a [WidgetStatePropertyRule].
bool isExpandableWidgetStateProperty(Object property) =>
    property is WidgetStateMapper<Object?> || property is WidgetStatePropertyAll<Object?>;

/// Expands a map-form [property] (`WidgetStateProperty.fromMap`,
/// `WidgetStateColor.fromMap`, ... i.e. a [WidgetStateMapper]) or a
/// [WidgetStatePropertyAll] into (cube, value) pairs over [dims], by
/// evaluating it on every combination (minus [impossible] ones) and
/// merging cubes with equal values. Combinations that resolve to null
/// produce no pair ("not set": earlier rules stay in effect).
///
/// A `resolveWith` closure can't be expanded faithfully (it may read
/// anything), so it is rejected with an [ArgumentError].
List<(StateCube, T)> expandWidgetStateProperty<T extends Object>(
  WidgetStateProperty<T?> property,
  List<WidgetState> dims, {
  bool Function(Set<WidgetState> states)? impossible,
}) {
  if (property is! WidgetStateMapper<T?> && property is! WidgetStatePropertyAll<T?>) {
    throw ArgumentError.value(property, 'property',
        'only map-form WidgetStateProperty values (fromMap / WidgetStatePropertyAll) can become rules; '
        'a resolveWith closure cannot be split into conditions');
  }
  // Evaluate every combination.
  final List<(StateCube, T)> cubes = <(StateCube, T)>[];
  for (int bits = 0; bits < (1 << dims.length); bits++) {
    final Set<WidgetState> states = <WidgetState>{
      for (int i = 0; i < dims.length; i++)
        if (bits & (1 << i) != 0) dims[i],
    };
    if (impossible?.call(states) ?? false) {
      continue;
    }
    final T? v = property.resolve(states);
    if (v != null) {
      cubes.add((<WidgetState, bool>{for (final WidgetState d in dims) d: states.contains(d)}, v));
    }
  }
  // Merge cubes that differ in exactly one dimension and have equal values.
  bool merged = true;
  List<(StateCube, T)> current = cubes;
  while (merged) {
    merged = false;
    final List<(StateCube, T)> next = <(StateCube, T)>[];
    final Set<int> used = <int>{};
    for (int i = 0; i < current.length; i++) {
      if (used.contains(i)) {
        continue;
      }
      for (int j = i + 1; j < current.length; j++) {
        if (used.contains(j) || current[i].$2 != current[j].$2) {
          continue;
        }
        final WidgetState? diff = _singleDiff(current[i].$1, current[j].$1);
        if (diff != null) {
          next.add((Map<WidgetState, bool>.of(current[i].$1)..remove(diff), current[i].$2));
          used
            ..add(i)
            ..add(j);
          merged = true;
          break;
        }
      }
      if (!used.contains(i)) {
        next.add(current[i]);
        used.add(i);
      }
    }
    current = next;
  }
  return current;
}

WidgetState? _singleDiff(StateCube a, StateCube b) {
  if (!setEquals(a.keys.toSet(), b.keys.toSet())) {
    return null;
  }
  WidgetState? diff;
  for (final WidgetState k in a.keys) {
    if (a[k] != b[k]) {
      if (diff != null) {
        return null;
      }
      diff = k;
    }
  }
  return diff;
}
