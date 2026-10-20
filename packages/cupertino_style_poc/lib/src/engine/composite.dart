// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Sub-field targets for a closed set of composite value types
/// (TextStyle, BorderSideStyle, IconThemeData).
///
/// A field whose [ComponentSpec.composites] entry names a [Composite] merges
/// per property across rules instead of being replaced by the last rule:
///
/// * A whole value (`style:` or a whole-field `derive:`) contributes every
///   property it sets. What "sets" means is per type (see each class).
/// * A sub-field entry (`sub: {(field, SubProp.color): value | FieldRef |
///   TokenRef}`) sets one property.
/// * Each targetable property ([Composite.props]) is a slot that competes
///   under "last rule wins" exactly like a field: the last matching rule
///   that sets it (by whole value or by sub entry) wins. Not setting it
///   keeps the earlier winner, including an earlier derive.
/// * Within one rule the whole value comes before that rule's sub entries.
/// * Properties that are not slots follow the type's own merge
///   ([Composite.merge]) over the whole values in chain order.
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart' show BorderSide, BorderStyle, Color, TextStyle;
import 'package:flutter/widgets.dart' show IconThemeData;

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

/// A partial BorderSide for rule values. Every property is nullable and
/// null means unset, so a rule `side: BorderSideStyle(width: 2)` keeps an
/// earlier (or derived) color. The component resolves the merged value to a
/// [BorderSide] ([toBorderSide]); unset properties take BorderSide's own
/// defaults (black, 1.0, solid, strokeAlignInside).
@immutable
class BorderSideStyle {
  const BorderSideStyle({this.color, this.width, this.style, this.strokeAlign});

  /// Every property of [side] set (a complete style).
  BorderSideStyle.from(BorderSide side)
      : color = side.color,
        width = side.width,
        style = side.style,
        strokeAlign = side.strokeAlign;

  final Color? color;
  final double? width;
  final BorderStyle? style;
  final double? strokeAlign;

  /// [other]'s set properties over this one's.
  BorderSideStyle merge(BorderSideStyle? other) => other == null
      ? this
      : BorderSideStyle(
          color: other.color ?? color,
          width: other.width ?? width,
          style: other.style ?? style,
          strokeAlign: other.strokeAlign ?? strokeAlign,
        );

  BorderSideStyle copyWith({Color? color, double? width, BorderStyle? style, double? strokeAlign}) =>
      BorderSideStyle(
        color: color ?? this.color,
        width: width ?? this.width,
        style: style ?? this.style,
        strokeAlign: strokeAlign ?? this.strokeAlign,
      );

  /// Whether every property is set.
  bool get isComplete => color != null && width != null && style != null && strokeAlign != null;

  /// The component's resolution: unset properties take BorderSide's
  /// defaults.
  BorderSide toBorderSide() {
    const BorderSide d = BorderSide();
    return BorderSide(
      color: color ?? d.color,
      width: width ?? d.width,
      style: style ?? d.style,
      strokeAlign: strokeAlign ?? d.strokeAlign,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BorderSideStyle &&
      other.color == color &&
      other.width == width &&
      other.style == style &&
      other.strokeAlign == strokeAlign;

  @override
  int get hashCode => Object.hash(color, width, style, strokeAlign);

  @override
  String toString() => 'BorderSideStyle(${<String>[
        if (color != null) 'color: $color',
        if (width != null) 'width: $width',
        if (style != null) 'style: ${style!.name}',
        if (strokeAlign != null) 'strokeAlign: $strokeAlign',
      ].join(', ')})';
}

/// BorderSideStyle (replaces BorderSide in the closed set). Unset = null
/// for every property; whole values merge per property
/// ([BorderSideStyle.merge]). Slots: color, width. Only sub entries start
/// from `BorderSideStyle()` (nothing set).
final class BorderSideStyleComposite extends Composite {
  const BorderSideStyleComposite();
  @override
  String get name => 'BorderSideStyle';
  @override
  Set<SubProp> get props => const <SubProp>{SubProp.color, SubProp.width};
  @override
  bool accepts(Object v) => v is BorderSideStyle;
  @override
  Type propType(SubProp p) => p == SubProp.color ? Color : double;
  @override
  Object? get(Object v, SubProp p) => switch (p) {
        SubProp.color => (v as BorderSideStyle).color,
        SubProp.width => (v as BorderSideStyle).width,
        _ => null,
      };
  @override
  Object merge(Object acc, Object v) => (acc as BorderSideStyle).merge(v as BorderSideStyle);
  @override
  Object get empty => const BorderSideStyle();
  @override
  Object withProps(Object base, Map<SubProp, Object> slots) => (base as BorderSideStyle).copyWith(
        color: slots[SubProp.color] as Color?,
        width: slots[SubProp.width] as double?,
      );
  @override
  bool replacesAll(Object v) => (v as BorderSideStyle).isComplete;

  static final Map<String, Object? Function(Object v)> _bs = <String, Object? Function(Object v)>{
    'color': (Object v) => (v as BorderSideStyle).color,
    'width': (Object v) => (v as BorderSideStyle).width,
    'style': (Object v) => (v as BorderSideStyle).style,
    'strokeAlign': (Object v) => (v as BorderSideStyle).strokeAlign,
  };
  @override
  Map<String, Object? Function(Object v)> get _getters => _bs;
  @override
  List<String> get properties => _bs.keys.toList();
  @override
  Object only(Object v, Set<String> props) {
    final BorderSideStyle b = v as BorderSideStyle;
    return BorderSideStyle(
      color: props.contains('color') ? b.color : null,
      width: props.contains('width') ? b.width : null,
      style: props.contains('style') ? b.style : null,
      strokeAlign: props.contains('strokeAlign') ? b.strokeAlign : null,
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
const BorderSideStyleComposite borderSideStyleComposite = BorderSideStyleComposite();
const IconThemeComposite iconThemeComposite = IconThemeComposite();

/// What the component does with a resolved field value before using it:
/// a [BorderSideStyle] becomes a [BorderSide] (unset properties take
/// BorderSide's defaults). Other values are used as they are.
Object? componentValue(Object? v) => v is BorderSideStyle ? v.toBorderSide() : v;
