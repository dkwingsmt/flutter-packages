// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Cupertino adapter: the built-in Cupertino token group, the app-side
/// Brand group (sample), the expansion of CupertinoDynamicColors into
/// environment-conditioned rules (and its debug check), the
/// environment-valued alpha [EnvAlpha], and expansion of map-form
/// WidgetStateProperty values into rules.
library;

import 'dart:ui' show lerpDouble;

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoColors, CupertinoDynamicColor, CupertinoTextThemeData, CupertinoThemeData, CupertinoUserInterfaceLevelData;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'engine/engine.dart';
import 'widgets.dart';

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
/// IconThemeData (color) or BorderSideStyle (color), is expanded into
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
        final BorderSideStyle b => b.color is CupertinoDynamicColor,
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
      final BorderSideStyle b => b.copyWith(color: r(b.color)),
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
        BorderSideStyle() => null,
        _ => _findDynamic(value, '${value.runtimeType}'),
      };

  @override
  String get debugResolvedPlaces => 'A CupertinoDynamicColor is expanded per environment only as a field value '
      'itself and in TextStyle color / decorationColor / backgroundColor, IconThemeData.color and '
      'BorderSideStyle.color. Use one of those places, or write environment-conditioned rules '
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
      final BorderSideStyle b => 'BorderSideStyle(color: ${name(b.color)})',
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

/// An environment-valued alpha for [TokenRef.alpha]:
/// `TokenRef(CupertinoTokens.primaryColor, alpha: EnvAlpha(light: 0.12,
/// dark: 0.26))`. Picked per minterm at the environment part of the
/// minterm, where the token itself is read, so a derive on a color field
/// stays one rule without environment conditions and still follows its
/// source in every environment.
///
/// [light] and [dark] are required. The high-contrast slots fall back to
/// [light] / [dark]; the elevated slots fall back to their base slot (the
/// same fallbacks as `CupertinoDynamicColor.withBrightnessAndContrast`).
@immutable
final class EnvAlpha extends EnvironmentAlpha {
  const EnvAlpha({
    required this.light,
    required this.dark,
    this.highContrast,
    this.darkHighContrast,
    this.elevated,
    this.darkElevated,
    this.highContrastElevated,
    this.darkHighContrastElevated,
  })  : assert(light >= 0.0 && light <= 1.0),
        assert(dark >= 0.0 && dark <= 1.0),
        assert((highContrast ?? 0.0) >= 0.0 && (highContrast ?? 0.0) <= 1.0),
        assert((darkHighContrast ?? 0.0) >= 0.0 && (darkHighContrast ?? 0.0) <= 1.0),
        assert((elevated ?? 0.0) >= 0.0 && (elevated ?? 0.0) <= 1.0),
        assert((darkElevated ?? 0.0) >= 0.0 && (darkElevated ?? 0.0) <= 1.0),
        assert((highContrastElevated ?? 0.0) >= 0.0 && (highContrastElevated ?? 0.0) <= 1.0),
        assert((darkHighContrastElevated ?? 0.0) >= 0.0 && (darkHighContrastElevated ?? 0.0) <= 1.0);

  final double light;
  final double dark;
  final double? highContrast;
  final double? darkHighContrast;
  final double? elevated;
  final double? darkElevated;
  final double? highContrastElevated;
  final double? darkHighContrastElevated;

  /// The alpha for one environment.
  double of({required Brightness brightness, required bool highContrast, required CupertinoUserInterfaceLevelData level}) {
    final bool dark = brightness == Brightness.dark;
    final double hc = (dark ? darkHighContrast : this.highContrast) ?? (dark ? this.dark : light);
    final double base = highContrast ? hc : (dark ? this.dark : light);
    if (level == CupertinoUserInterfaceLevelData.base) {
      return base;
    }
    return switch ((dark, highContrast)) {
          (false, false) => elevated,
          (true, false) => darkElevated,
          (false, true) => highContrastElevated,
          (true, true) => darkHighContrastElevated,
        } ??
        base;
  }

  @override
  double at(Minterm env) => of(
      brightness: env[EnvDims.brightness] as Brightness,
      highContrast: env[EnvDims.highContrast] as bool,
      level: env[EnvDims.interfaceLevel] as CupertinoUserInterfaceLevelData);

  @override
  bool operator ==(Object other) =>
      other is EnvAlpha &&
      other.light == light &&
      other.dark == dark &&
      other.highContrast == highContrast &&
      other.darkHighContrast == darkHighContrast &&
      other.elevated == elevated &&
      other.darkElevated == darkElevated &&
      other.highContrastElevated == highContrastElevated &&
      other.darkHighContrastElevated == darkHighContrastElevated;

  @override
  int get hashCode => Object.hash(light, dark, highContrast, darkHighContrast, elevated, darkElevated,
      highContrastElevated, darkHighContrastElevated);

  @override
  String toString() => 'EnvAlpha(light: $light, dark: $dark'
      '${highContrast == null ? '' : ', highContrast: $highContrast'}'
      '${darkHighContrast == null ? '' : ', darkHighContrast: $darkHighContrast'}'
      '${elevated == null ? '' : ', elevated: $elevated'}'
      '${darkElevated == null ? '' : ', darkElevated: $darkElevated'}'
      '${highContrastElevated == null ? '' : ', highContrastElevated: $highContrastElevated'}'
      '${darkHighContrastElevated == null ? '' : ', darkHighContrastElevated: $darkHighContrastElevated'}'
      ')';
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
    final BorderSideStyle b => _findDynamic(b.color, '$path.color'),
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
// Built-in Cupertino token group (group class: CupertinoThemeData).

/// Tokens of the built-in Cupertino group. The private enum sits behind
/// the generated public facade [CupertinoTokens], so adding a token
/// is not a breaking change. Values are usually CupertinoDynamicColors;
/// the global channel expands them into environment-conditioned rules, so
/// the group needs no brightness/contrast rules of its own.
enum _CupertinoTokens<T extends Object> with GroupTokenMixin<CupertinoThemeData, T> implements CupertinoTokens<T> {
  primaryColor<Color>(_primaryColor),
  primaryContrastingColor<Color>(_primaryContrastingColor),
  barBackgroundColor<Color>(_barBackgroundColor),
  scaffoldBackgroundColor<Color>(_scaffoldBackgroundColor),
  textStyle<TextStyle>(_textStyle),
  actionTextStyle<TextStyle>(_actionTextStyle),
  actionSmallTextStyle<TextStyle>(_actionSmallTextStyle);

  const _CupertinoTokens(this._of);
  final T? Function(CupertinoThemeData) _of;
  @override
  T? of(CupertinoThemeData group) => _of(group);

  static Color _primaryColor(CupertinoThemeData t) => t.primaryColor;
  static Color _primaryContrastingColor(CupertinoThemeData t) => t.primaryContrastingColor;
  static Color _barBackgroundColor(CupertinoThemeData t) => t.barBackgroundColor;
  static Color _scaffoldBackgroundColor(CupertinoThemeData t) => t.scaffoldBackgroundColor;
  static TextStyle _textStyle(CupertinoThemeData t) => t.textTheme.textStyle;
  static TextStyle _actionTextStyle(CupertinoThemeData t) => t.textTheme.actionTextStyle;
  static TextStyle _actionSmallTextStyle(CupertinoThemeData t) => t.textTheme.actionSmallTextStyle;
}

CupertinoThemeData _lerpCupertino(CupertinoThemeData a, CupertinoThemeData b, double t) => CupertinoThemeData(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      primaryColor: Color.lerp(a.primaryColor, b.primaryColor, t),
      primaryContrastingColor: Color.lerp(a.primaryContrastingColor, b.primaryContrastingColor, t),
      barBackgroundColor: Color.lerp(a.barBackgroundColor, b.barBackgroundColor, t),
      scaffoldBackgroundColor: Color.lerp(a.scaffoldBackgroundColor, b.scaffoldBackgroundColor, t),
      textTheme: CupertinoTextThemeData(
        textStyle: TextStyle.lerp(a.textTheme.textStyle, b.textTheme.textStyle, t),
        actionTextStyle: TextStyle.lerp(a.textTheme.actionTextStyle, b.textTheme.actionTextStyle, t),
        actionSmallTextStyle: TextStyle.lerp(a.textTheme.actionSmallTextStyle, b.textTheme.actionSmallTextStyle, t),
      ),
    );

/// The built-in Cupertino group. A whole value read back from tokens takes
/// its brightness from the environment (the brightness dimension).
final TokenGroup<CupertinoThemeData> cupertinoTokenGroup = TokenGroup<CupertinoThemeData>(
  'Cupertino',
  CupertinoTokens.values,
  (GroupFieldReader<CupertinoThemeData> r) => CupertinoThemeData(
    brightness: r.envValue(EnvDims.brightness),
    primaryColor: r(CupertinoTokens.primaryColor),
    primaryContrastingColor: r(CupertinoTokens.primaryContrastingColor),
    barBackgroundColor: r(CupertinoTokens.barBackgroundColor),
    scaffoldBackgroundColor: r(CupertinoTokens.scaffoldBackgroundColor),
    textTheme: CupertinoTextThemeData(
      textStyle: r(CupertinoTokens.textStyle),
      actionTextStyle: r(CupertinoTokens.actionTextStyle),
      actionSmallTextStyle: r(CupertinoTokens.actionSmallTextStyle),
    ),
  ),
  _lerpCupertino,
);

/// The library default of the global channel: the default
/// CupertinoThemeData's values (dynamic colors, expanded per environment).
final TokenRule cupertinoDefaultTokens = TokenRule.group(cupertinoTokenGroup, const CupertinoThemeData());

/// [cupertinoDefaultTokens] with a label, as rule #0 of every global
/// channel (the label shows up in debug provenance).
final RawRule<Enum> _cupertinoDefaultsRaw = RawRule<Enum>(Condition.all,
    style: cupertinoDefaultTokens.toRaw().style, label: 'Cupertino defaults');

/// Builds the global channel from the built-in group, the app [groups] and
/// [rules] (library defaults first). Dynamic colors in token values are
/// expanded into environment-conditioned rules (once per authored rule,
/// see [flatten]). Debug: token rules go through [debugCheckEnvExpandable].
Tokens buildTokens(List<TokenGroup<Object>> groups, List<TokenRule> rules) {
  final GroupChannelSpec spec = groupChannelSpec(
    'GlobalTokens',
    <TokenGroup<Object>>[cupertinoTokenGroup, ...groups],
    dimensions: EnvDims.all,
    composites: const <Type, Composite>{TextStyle: tokenTextStyleComposite},
  );
  final List<RawRule<Enum>> raw = <RawRule<Enum>>[
    _cupertinoDefaultsRaw,
    for (final TokenRule r in rules) r.toRaw(),
  ];
  return Tokens(TokenChannel<Enum>(spec, raw, splitter: cupertinoEnvSplitter));
}

// ---------------------------------------------------------------------------
// App-side sample group: Brand (public enum, no facade, written by hand
// the way an app would).

@immutable
class BrandColors {
  const BrandColors({required this.accent, required this.onAccent, required this.pressedAccent, required this.cornerRadius});

  final Color accent;
  final Color onAccent;
  final Color pressedAccent;
  final double cornerRadius;

  static BrandColors lerp(BrandColors a, BrandColors b, double t) => BrandColors(
        accent: Color.lerp(a.accent, b.accent, t)!,
        onAccent: Color.lerp(a.onAccent, b.onAccent, t)!,
        pressedAccent: Color.lerp(a.pressedAccent, b.pressedAccent, t)!,
        cornerRadius: lerpDouble(a.cornerRadius, b.cornerRadius, t)!,
      );
}

enum Brand<T extends Object> with GroupTokenMixin<BrandColors, T> {
  accent<Color>(_accent),
  onAccent<Color>(_onAccent),
  pressedAccent<Color>(_pressedAccent),
  cornerRadius<double>(_cornerRadius);

  const Brand(this._of);
  final T? Function(BrandColors) _of;
  @override
  T? of(BrandColors group) => _of(group);

  static Color _accent(BrandColors g) => g.accent;
  static Color _onAccent(BrandColors g) => g.onAccent;
  static Color _pressedAccent(BrandColors g) => g.pressedAccent;
  static double _cornerRadius(BrandColors g) => g.cornerRadius;
}

final TokenGroup<BrandColors> brandGroup = TokenGroup<BrandColors>(
  'Brand',
  Brand.values,
  (GroupFieldReader<BrandColors> r) => BrandColors(
    accent: r(Brand.accent)!,
    onAccent: r(Brand.onAccent)!,
    pressedAccent: r(Brand.pressedAccent)!,
    cornerRadius: r(Brand.cornerRadius)!,
  ),
  BrandColors.lerp,
);

/// Sample palettes. Dynamic colors are fine as token values: they are
/// expanded per environment like any other dynamic color.
abstract final class BrandPalettes {
  static const BrandColors teal = BrandColors(
    accent: CupertinoDynamicColor.withBrightnessAndContrast(
      color: Color(0xFF00897B),
      darkColor: Color(0xFF4DB6AC),
      highContrastColor: Color(0xFF00574B),
      darkHighContrastColor: Color(0xFF80CBC4),
    ),
    onAccent: CupertinoColors.white,
    pressedAccent: CupertinoDynamicColor.withBrightness(color: Color(0xFF00695C), darkColor: Color(0xFF00897B)),
    cornerRadius: 6,
  );

  static const BrandColors purple = BrandColors(
    accent: CupertinoDynamicColor.withBrightnessAndContrast(
      color: Color(0xFF7B1FA2),
      darkColor: Color(0xFFBA68C8),
      highContrastColor: Color(0xFF4A0072),
      darkHighContrastColor: Color(0xFFE1BEE7),
    ),
    onAccent: CupertinoColors.white,
    pressedAccent: CupertinoDynamicColor.withBrightness(color: Color(0xFF4A148C), darkColor: Color(0xFF8E24AA)),
    cornerRadius: 18,
  );
}

// ---------------------------------------------------------------------------
// Map-form WidgetStateProperty -> rules.

/// One cube of a state table: dimension -> required value (absent = any).
typedef StateCube = Map<WidgetState, bool>;

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
