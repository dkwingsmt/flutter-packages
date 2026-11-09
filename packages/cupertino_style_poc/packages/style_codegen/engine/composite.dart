// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sub-field targets for a closed set of composite value types
/// (TextStyle, BorderSide, IconThemeData). Generated style specs write
/// them with the `.parts(...)` constructor of a composite field's source
/// class (`textStyle: .parts(color: ...)`), a [DeriveSource.parts] that
/// `splitSlots` turns into sub entries.
///
/// A field whose [ComponentSpec.composites] entry names a [Composite] merges
/// per property across rules instead of being replaced by the last rule:
///
/// * A whole value (a value or a source in the field's whole slot)
///   contributes every property it sets. What "sets" means is per type
///   (see each class).
/// * A sub-field entry (a `.parts(color: ...)` source; in engine form
///   `sub: {(field, SubProp.color): value | source}`) sets one property.
/// * Each targetable property ([Composite.props]) is a slot that competes
///   under "last rule wins" exactly like a field: the last matching rule
///   that sets it (by whole value or by sub entry) wins. Not setting it
///   keeps the earlier winner, including an earlier derive.
/// * Within one rule the whole value comes before that rule's sub entries.
/// * Properties that are not slots follow the type's own merge
///   ([Composite.merge]) over the whole values in chain order.
library;

import 'package:flutter/painting.dart' show BorderSide, Color, TextStyle;
import 'package:flutter/widgets.dart' show IconThemeData;

import 'engine.dart' show DeriveSource;

/// Targetable properties of the composites. One enum for all types, so a
/// rule writes `(.side, .color)`; [Composite.props] says which apply.
enum SubProp {
  color,
  decorationColor,
  width,
  size;

  /// Paint-only properties. The field x dimension allowance table exists to
  /// keep layout from varying by interaction state, so a sub entry on a
  /// paint property is not restricted by its field's allowance row
  /// ([checkAllowance]); width and size are layout and are. Used only by
  /// that analysis tool (the table is not part of the design).
  bool get isPaint => this == color || this == decorationColor;
}

/// One composite type in the closed set.
sealed class Composite {
  const Composite();

  String get name;

  /// The slots of this type.
  Set<SubProp> get props;

  /// Whether [v] is a value of this type.
  bool accepts(Object v);

  /// Value type of slot [p] (for checks).
  Type propType(SubProp p);

  /// [p] as set by the whole value [v], or null when [v] leaves it unset.
  Object? get(Object v, SubProp p);

  /// [v] merged over [acc] for the non-slot properties.
  Object merge(Object acc, Object v);

  /// Starting value when only sub entries are set.
  Object get empty;

  /// [base] with the slot values applied.
  Object withProps(Object base, Map<SubProp, Object> slots);

  /// Whether [v] (a literal whole value) replaces every property, so no
  /// earlier contribution can survive it. Used for the static shadow check.
  bool replacesAll(Object v);

  /// Every rule-visible property of the type, slots included (slot names
  /// are the [SubProp] names). Flat-parameter conditions can be computed
  /// per property. TextStyle's `inherit` and `debugLabel` are not
  /// properties (the component decides inherit).
  List<String> get properties;

  /// Property [p] of [v], null when unset.
  Object? property(Object v, String p) => _getters[p]!(v);

  /// [v] with only the properties in [props] set (others unset).
  Object only(Object v, Set<String> props);

  Map<String, Object? Function(Object v)> get _getters;

  @override
  String toString() => name;
}

/// TextStyle. Unset = null, for every property. Slots: color,
/// decorationColor.
///
/// `inherit` is not a rule property. Whole values merge per property
/// with `TextStyle.merge` as if every contribution had `inherit: true`, so
/// a later `inherit: false` value does not wipe earlier properties (a rule
/// is always a partial style). The resolution output then fixes `inherit`
/// to [inherit]: `false` by default, i.e. the resolved style is a complete
/// style, consistent with Typography / ThemeData.textTheme (all
/// `inherit: false`), which is what Material's defaults derive from. There
/// is no partial-style (`inherit: true`) output; every component TextStyle
/// field is complete. The global token channel
/// uses [tokenTextStyleComposite] (`inherit: null`: keep the token's own
/// value; a type token is a theme's complete style, not a rule output). A
/// rule that sets
/// `inherit: false` is reported by [checkTextStyleInherit] (debug-time
/// diagnostic, resolution ignores it).
final class TextStyleComposite extends Composite {
  /// Component fields: resolved styles are complete (`inherit: false`).
  const TextStyleComposite() : inherit = false;

  /// Type tokens in the global channel: keep the token's own `inherit`.
  const TextStyleComposite.token() : inherit = null;

  /// The `inherit` value of every resolved style of this field (`false`);
  /// null keeps the first whole value's (token channel).
  final bool? inherit;
  @override
  String get name => inherit == null ? 'TextStyle(token)' : 'TextStyle';
  @override
  Set<SubProp> get props => const <SubProp>{SubProp.color, SubProp.decorationColor};
  @override
  bool accepts(Object v) => v is TextStyle;
  @override
  Type propType(SubProp p) => Color;
  @override
  Object? get(Object v, SubProp p) => switch (p) {
        SubProp.color => (v as TextStyle).color,
        SubProp.decorationColor => (v as TextStyle).decorationColor,
        _ => null,
      };
  @override
  Object merge(Object acc, Object v) {
    final TextStyle t = v as TextStyle;
    return (acc as TextStyle).merge(t.inherit ? t : t.copyWith(inherit: true));
  }

  @override
  Object get empty => const TextStyle();
  @override
  Object withProps(Object base, Map<SubProp, Object> slots) => (base as TextStyle).copyWith(
        inherit: inherit,
        color: slots[SubProp.color] as Color?,
        decorationColor: slots[SubProp.decorationColor] as Color?,
      );
  @override
  bool replacesAll(Object v) => false;

  static final Map<String, Object? Function(Object v)> _ts = <String, Object? Function(Object v)>{
    'color': (Object v) => (v as TextStyle).color,
    'decorationColor': (Object v) => (v as TextStyle).decorationColor,
    'backgroundColor': (Object v) => (v as TextStyle).backgroundColor,
    'fontFamily': (Object v) => (v as TextStyle).fontFamily,
    'fontFamilyFallback': (Object v) => (v as TextStyle).fontFamilyFallback,
    'fontSize': (Object v) => (v as TextStyle).fontSize,
    'fontWeight': (Object v) => (v as TextStyle).fontWeight,
    'fontStyle': (Object v) => (v as TextStyle).fontStyle,
    'letterSpacing': (Object v) => (v as TextStyle).letterSpacing,
    'wordSpacing': (Object v) => (v as TextStyle).wordSpacing,
    'textBaseline': (Object v) => (v as TextStyle).textBaseline,
    'height': (Object v) => (v as TextStyle).height,
    'leadingDistribution': (Object v) => (v as TextStyle).leadingDistribution,
    'locale': (Object v) => (v as TextStyle).locale,
    'foreground': (Object v) => (v as TextStyle).foreground,
    'background': (Object v) => (v as TextStyle).background,
    'shadows': (Object v) => (v as TextStyle).shadows,
    'fontFeatures': (Object v) => (v as TextStyle).fontFeatures,
    'fontVariations': (Object v) => (v as TextStyle).fontVariations,
    'decoration': (Object v) => (v as TextStyle).decoration,
    'decorationStyle': (Object v) => (v as TextStyle).decorationStyle,
    'decorationThickness': (Object v) => (v as TextStyle).decorationThickness,
    'overflow': (Object v) => (v as TextStyle).overflow,
  };
  @override
  Map<String, Object? Function(Object v)> get _getters => _ts;
  @override
  List<String> get properties => _ts.keys.toList();
  @override
  Object only(Object v, Set<String> props) {
    final TextStyle t = v as TextStyle;
    T? k<T>(String p, T? x) => props.contains(p) ? x : null;
    return TextStyle(
      color: k('color', t.color),
      decorationColor: k('decorationColor', t.decorationColor),
      backgroundColor: k('backgroundColor', t.backgroundColor),
      fontFamily: k('fontFamily', t.fontFamily),
      fontFamilyFallback: k('fontFamilyFallback', t.fontFamilyFallback),
      fontSize: k('fontSize', t.fontSize),
      fontWeight: k('fontWeight', t.fontWeight),
      fontStyle: k('fontStyle', t.fontStyle),
      letterSpacing: k('letterSpacing', t.letterSpacing),
      wordSpacing: k('wordSpacing', t.wordSpacing),
      textBaseline: k('textBaseline', t.textBaseline),
      height: k('height', t.height),
      leadingDistribution: k('leadingDistribution', t.leadingDistribution),
      locale: k('locale', t.locale),
      foreground: k('foreground', t.foreground),
      background: k('background', t.background),
      shadows: k('shadows', t.shadows),
      fontFeatures: k('fontFeatures', t.fontFeatures),
      fontVariations: k('fontVariations', t.fontVariations),
      decoration: k('decoration', t.decoration),
      decorationStyle: k('decorationStyle', t.decorationStyle),
      decorationThickness: k('decorationThickness', t.decorationThickness),
      overflow: k('overflow', t.overflow),
    );
  }
}

/// BorderSide, an atomic value with one targetable property. A whole
/// BorderSide sets every property, so it replaces everything before it
/// (rules that want to change only the color write `.parts(color: ...)`,
/// i.e. a sub entry). Slots: color, width.
/// Only sub entries start from `BorderSide()` (BorderSide's own defaults:
/// black, 1.0, solid, strokeAlignInside).
final class BorderSideComposite extends Composite {
  const BorderSideComposite();
  @override
  String get name => 'BorderSide';
  @override
  Set<SubProp> get props => const <SubProp>{SubProp.color, SubProp.width};
  @override
  bool accepts(Object v) => v is BorderSide;
  @override
  Type propType(SubProp p) => p == SubProp.color ? Color : double;
  @override
  Object? get(Object v, SubProp p) => switch (p) {
        SubProp.color => (v as BorderSide).color,
        SubProp.width => (v as BorderSide).width,
        _ => null,
      };
  @override
  Object merge(Object acc, Object v) => v;
  @override
  Object get empty => const BorderSide();
  @override
  Object withProps(Object base, Map<SubProp, Object> slots) => (base as BorderSide).copyWith(
        color: slots[SubProp.color] as Color?,
        width: slots[SubProp.width] as double?,
      );
  @override
  bool replacesAll(Object v) => true;

  static final Map<String, Object? Function(Object v)> _bs = <String, Object? Function(Object v)>{
    'color': (Object v) => (v as BorderSide).color,
    'width': (Object v) => (v as BorderSide).width,
    'style': (Object v) => (v as BorderSide).style,
    'strokeAlign': (Object v) => (v as BorderSide).strokeAlign,
  };
  @override
  Map<String, Object? Function(Object v)> get _getters => _bs;
  @override
  List<String> get properties => _bs.keys.toList();
  @override
  Object only(Object v, Set<String> props) {
    const BorderSide d = BorderSide();
    final BorderSide b = v as BorderSide;
    return BorderSide(
      color: props.contains('color') ? b.color : d.color,
      width: props.contains('width') ? b.width : d.width,
      style: props.contains('style') ? b.style : d.style,
      strokeAlign: props.contains('strokeAlign') ? b.strokeAlign : d.strokeAlign,
    );
  }
}

/// IconThemeData. Unset = null, for every property. Slots: color, size.
/// Non-slot properties use `IconThemeData.merge` (per property).
final class IconThemeComposite extends Composite {
  const IconThemeComposite();
  @override
  String get name => 'IconThemeData';
  @override
  Set<SubProp> get props => const <SubProp>{SubProp.color, SubProp.size};
  @override
  bool accepts(Object v) => v is IconThemeData;
  @override
  Type propType(SubProp p) => p == SubProp.color ? Color : double;
  @override
  Object? get(Object v, SubProp p) => switch (p) {
        SubProp.color => (v as IconThemeData).color,
        SubProp.size => (v as IconThemeData).size,
        _ => null,
      };
  @override
  Object merge(Object acc, Object v) => (acc as IconThemeData).merge(v as IconThemeData);
  @override
  Object get empty => const IconThemeData();
  @override
  Object withProps(Object base, Map<SubProp, Object> slots) => (base as IconThemeData).copyWith(
        color: slots[SubProp.color] as Color?,
        size: slots[SubProp.size] as double?,
      );
  @override
  bool replacesAll(Object v) => false;

  static final Map<String, Object? Function(Object v)> _it = <String, Object? Function(Object v)>{
    'color': (Object v) => (v as IconThemeData).color,
    'size': (Object v) => (v as IconThemeData).size,
    'fill': (Object v) => (v as IconThemeData).fill,
    'weight': (Object v) => (v as IconThemeData).weight,
    'grade': (Object v) => (v as IconThemeData).grade,
    'opticalSize': (Object v) => (v as IconThemeData).opticalSize,
    'opacity': (Object v) => (v as IconThemeData).opacity,
    'shadows': (Object v) => (v as IconThemeData).shadows,
    'applyTextScaling': (Object v) => (v as IconThemeData).applyTextScaling,
  };
  @override
  Map<String, Object? Function(Object v)> get _getters => _it;
  @override
  List<String> get properties => _it.keys.toList();
  @override
  Object only(Object v, Set<String> props) {
    final IconThemeData i = v as IconThemeData;
    T? k<T>(String p, T? x) => props.contains(p) ? x : null;
    return IconThemeData(
      color: k('color', i.color),
      size: k('size', i.size),
      fill: k('fill', i.fill),
      weight: k('weight', i.weight),
      grade: k('grade', i.grade),
      opticalSize: k('opticalSize', i.opticalSize),
      opacity: k('opacity', i.opacity),
      shadows: k('shadows', i.shadows),
      applyTextScaling: k('applyTextScaling', i.applyTextScaling),
    );
  }
}

/// Value equality used to decide whether two resolved default values
/// differ: Colors compare at 8-bit precision (`toARGB32`, like the
/// harness), lists element-wise, everything else with `==`.
bool sameValue(Object? a, Object? b) {
  if (a is Color && b is Color) {
    return a.toARGB32() == b.toARGB32();
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (!sameValue(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

const TextStyleComposite textStyleComposite = TextStyleComposite();

/// Type tokens in the global channel keep their own `inherit`.
const TextStyleComposite tokenTextStyleComposite = TextStyleComposite.token();
const BorderSideComposite borderSideComposite = BorderSideComposite();
const IconThemeComposite iconThemeComposite = IconThemeComposite();
