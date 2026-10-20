// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Generic, untyped engine for the order-only state/rule model: rules with
/// conditions over a component's state dimensions, resolved by "last
/// matching rule wins".
///
/// * A [Dimension] has a finite domain. Bool dimensions have domain
///   `{false, true}`; enum dimensions list their values.
/// * A [Condition] maps some dimensions to a non-empty set of allowed values.
///   Unconstrained dimensions are absent. Only positive sets.
/// * A [RawRule] has a condition and a (partial) [Style]. Rule lists are
///   flat (no nesting, like plain CSS); the order in the list is the only
///   order. There is no shared base condition: each flat call-site
///   parameter gets its own condition from the library defaults.
/// * [RawRule.any] expands into several rules that share one source position.
/// * Resolution is order-only: for a minterm, each field takes the value of
///   the last matching rule that sets it. No specificity.
/// * A rule may also set fields by [Derive]:
///   target field <- [FieldRef] (same component, identity) or [TokenRef]
///   (a global token, optionally with one alpha operator). A derive
///   competes with values under "last rule wins"; derived values are
///   evaluated after the whole chain, in topological order of the derive
///   graph.
/// * Every rule building block has a const constructor ([When], [RawRule],
///   [Style], [Derive], [FieldRef], [TokenRef]), so a default rule list can
///   be a top-level `const`. Checks that a const constructor can't do
///   happen in [flatten] / [chain] / [checkDerive].
/// * There is ONE global token channel ([TokenChannel], wrapped by
///   [Tokens]) holding every token (color, type, config); its dimensions
///   are environment dimensions only. Components reference only their own
///   fields ([FieldRef]) and the global channel ([TokenRef]); any other
///   cross-channel reference is a [RuleError] at chain build. Inside the
///   global channel a [TokenRef] (or [FieldRef]) to another token is an
///   internal reference, evaluated in topological order; cycles are a
///   [RuleError] at chain build.
/// * Fields listed in [ComponentSpec.composites] (TextStyle,
///   BorderSideStyle, IconThemeData) merge per property across rules, and a rule may target
///   one property with `sub: {(field, SubProp.color): value | source}`.
///   See composite.dart for the per-type semantics.
/// * Resolution has two stages: [resolveSymbolic] picks winners and folds
///   references into a [SymbolicStyle] whose token reads stay unbound (it
///   never reads a token value); [SymbolicStyle.bind] substitutes tokens.
///   [resolve] is the two in a row.
/// * A dimension computed from a resolved field (two-pass resolve, e.g.
///   Switch hasThumbIcon <- thumbIcon) is declared in
///   [ComponentSpec.derivedDimensions]; [checkDerivedDimensions] (run by
///   [chain] when given the spec) rejects rule sets in which such a field
///   depends on its own dimension.
/// * The field x dimension allowance table ([ComponentSpec.mayVaryBy],
///   [checkAllowance]) is not part of the design. It stays as an optional
///   analysis tool; no correctness check depends on it.
/// * Environment-dependent values (a dynamic color) are a way of writing
///   one plain value per environment slot. With an [EnvSplitter], [chain]
///   expands every rule holding one into environment-conditioned sub-rules
///   with plain values at the authored rule's position ([expandEnvValues],
///   cached per authored rule). After that the engine sees no
///   environment-dependent value; environment dimensions are ordinary
///   dimensions. The one environment-valued thing left is an
///   [EnvironmentAlpha] on a [TokenRef], picked per minterm like the token.
library;

import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show TextStyle;

import 'package:flutter/foundation.dart';

import 'composite.dart';
import 'groups.dart';

export 'composite.dart';
export 'groups.dart';

/// A dimension of a component's state space.
///
/// [environment] marks dimensions whose value comes from the environment
/// (brightness, contrast, StyleVariant), not from the component. Only
/// environment dimensions may appear on a token channel.
@immutable
class Dimension<T extends Object> {
  const Dimension(this.name, this.domain, {this.environment = false});

  final String name;
  final List<T> domain;
  final bool environment;

  bool get isBool => T == bool;

  @override
  String toString() => name;
}

/// A bool dimension: domain `{false, true}`.
class BoolDimension extends Dimension<bool> {
  const BoolDimension(String name, {super.environment})
      : super(name, const <bool>[false, true]);
}

/// Thrown for authoring errors (empty intersection, unknown dimension...).
/// In a real implementation these would be debug-mode asserts.
class RuleError extends Error {
  RuleError(this.message);
  final String message;
  @override
  String toString() => 'RuleError: $message';
}

/// A conjunction over dimensions; within one dimension a set of allowed
/// values (disjunction). Absent dimension = unconstrained.
@immutable
class Condition {
  /// [constraints] values are either a `bool` (for bool dimensions) or a
  /// non-empty `Set` of domain values. Validated eagerly; use [When] for a
  /// const condition (validated on first use, i.e. in [flatten]).
  factory Condition([Map<Dimension<Object>, Object> constraints = const {}]) =>
      Condition._(_normalize(constraints));

  const Condition._(Map<Dimension<Object>, Set<Object>> this._normalized)
      : _raw = null;

  const Condition._raw(Map<Dimension<Object>, Object> this._raw)
      : _normalized = null;

  /// The unconstrained condition (`When()`).
  static const Condition all = Condition._(<Dimension<Object>, Set<Object>>{});

  final Map<Dimension<Object>, Set<Object>>? _normalized;
  final Map<Dimension<Object>, Object>? _raw;

  static final Expando<Map<Dimension<Object>, Set<Object>>> _cache =
      Expando<Map<Dimension<Object>, Set<Object>>>('When.constraints');

  static Map<Dimension<Object>, Set<Object>> _normalize(
      Map<Dimension<Object>, Object> constraints) {
    final Map<Dimension<Object>, Set<Object>> normalized = {};
    constraints.forEach((Dimension<Object> dim, Object value) {
      final Set<Object> set;
      if (value is Set) {
        set = Set<Object>.of(value.cast<Object>());
      } else if (value is bool && dim.isBool) {
        set = <Object>{value};
      } else {
        throw RuleError(
            'Condition on "${dim.name}": expected a bool or a Set, got $value');
      }
      if (set.isEmpty) {
        throw RuleError('Condition on "${dim.name}": empty value set');
      }
      for (final Object v in set) {
        if (!dim.domain.contains(v)) {
          throw RuleError('Condition on "${dim.name}": $v not in domain');
        }
      }
      normalized[dim] = Set<Object>.unmodifiable(set);
    });
    return Map.unmodifiable(normalized);
  }

  /// Normalized constraints: dimension -> non-empty allowed set. For a
  /// [When], computed (and validated) on first access.
  Map<Dimension<Object>, Set<Object>> get constraints =>
      _normalized ?? (_cache[this] ??= _normalize(_raw!));

  /// Whether this condition constrains [dim] to a strict subset of its domain.
  bool constrains(Dimension<Object> dim) {
    final Set<Object>? s = constraints[dim];
    return s != null && s.length < dim.domain.length;
  }

  bool matches(Minterm m) {
    for (final MapEntry<Dimension<Object>, Set<Object>> e
        in constraints.entries) {
      if (!e.value.contains(m[e.key])) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() {
    if (constraints.isEmpty) {
      return 'When()';
    }
    final String body = constraints.entries.map((e) {
      final Set<Object> s = e.value;
      if (e.key.isBool && s.length == 1) {
        return '${e.key.name}: ${s.single}';
      }
      return '${e.key.name}: {${s.map(_valueName).join(', ')}}';
    }).join(', ');
    return 'When($body)';
  }
}

/// A const condition: `When({hovered: true, look: {Look.text}})`. Same
/// meaning as [Condition.new]; validation is deferred to first use (a const
/// constructor can't normalize or throw), which is [flatten].
class When extends Condition {
  const When([super.constraints = const <Dimension<Object>, Object>{}])
      : super._raw();
}

String _valueName(Object? v) => v is Enum ? v.name : '$v';

/// A partial assignment field -> value. Absent = not set. Values are never
/// null.
@immutable
class Style<F extends Enum> {
  const Style([this.values = const {}]);

  final Map<F, Object> values;

  bool get isEmpty => values.isEmpty;

  @override
  String toString() => values.toString();
}

/// Source of a derived field value. Exactly two kinds: [FieldRef] and [TokenRef].
@immutable
sealed class DeriveSource {
  const DeriveSource();
}

/// Same-component reference, identity only: the target takes the final
/// resolved value of [field] at the same minterm. No operators.
class FieldRef<F extends Enum> extends DeriveSource {
  const FieldRef(this.field);
  final F field;

  @override
  bool operator ==(Object other) => other is FieldRef<F> && other.field == field;
  @override
  int get hashCode => field.hashCode;
  @override
  String toString() => '.${field.name}';
}

/// Token reference: field [token] of the token channel whose field enum is
/// [T], resolved at the environment part of the referrer's minterm.
///
/// [alpha] is the only operator. It replaces the alpha of a [Color] token
/// with 8-bit rounding, exactly like `Color.withOpacity(alpha)` in Flutter
/// 3.47.5; see [applyAlpha]. It is either a plain `double` or an
/// [EnvironmentAlpha] (one alpha per environment, picked at the environment
/// part of the minterm being bound, like the token itself), so a derive on
/// a color field stays one rule without environment conditions.
///
/// The design sketch writes `.tokens(ColorRole.onSurface).alpha(0.38)`; a
/// method call is not a const expression, so the const form is
/// `TokenRef(Cs.onSurface, alpha: 0.38)`.
///
/// [token] is an enum value that is a field of the global channel (a
/// group token, see groups.dart: the enum value itself is also a
/// [TokenRef] with no alpha, so rules write `Cs.primary` directly and
/// `TokenRef(Cs.primary, alpha: 0.38)` for the alpha form).
/// Equality is by token and alpha only.
///
/// The constructor requires [alpha]. A reference without alpha is the
/// token itself (an enum value mixing in [TokenMixin] / [GroupTokenMixin]),
/// so there is exactly one spelling for it and `TokenRef(x) == x` (true one
/// way only, enum == is identity) can no longer be written.
class TokenRef<T extends Enum> extends DeriveSource {
  const TokenRef(this.token, {required Object this.alpha})
      : assert(alpha is EnvironmentAlpha || (alpha is double && alpha >= 0.0 && alpha <= 1.0),
            'alpha must be a double in [0, 1] or an EnvironmentAlpha');
  final T token;

  /// Null (the token itself), a `double`, or an [EnvironmentAlpha].
  final Object? alpha;

  /// The channel key: the token field enum type.
  Type get channel => T;

  @override
  bool operator ==(Object other) =>
      other is TokenRef && other.token == token && other.alpha == alpha;
  @override
  int get hashCode => Object.hash(token, alpha);
  @override
  String toString() => '$token${alpha == null ? '' : '.alpha($alpha)'}';
}

/// The canonical alpha operator: replace the alpha channel with
/// `round(255 * opacity) / 255` and re-quantize r, g, b to 8 bits, which is
/// what `Color.withOpacity` does in Flutter 3.47.5 (painting.dart:
/// `withAlpha((255.0 * opacity).round())` -> `Color.fromARGB`). Bit-identical
/// to `withOpacity` for every input color. Not identical to
/// `withValues(alpha: opacity)`, which stores the float alpha as-is.
Color applyAlpha(Color c, double opacity) => c.withAlpha((255.0 * opacity).round());

/// An alpha operator whose value depends on the environment (e.g. 0.12 in
/// light mode, 0.26 in dark mode). Used as [TokenRef.alpha] and resolved
/// per minterm at the environment part of the minterm ([at]), where the
/// token is read too, so one derive rule covers every environment. Must be
/// const-constructible and implement `==` (rules are compared
/// element-wise).
abstract class EnvironmentAlpha {
  const EnvironmentAlpha();

  /// The alpha at [env], a global-channel minterm (environment dimensions
  /// only). In `[0, 1]`.
  double at(Minterm env);
}

/// The plain alpha of a [TokenRef.alpha] value at [env].
double alphaAt(Object alpha, Minterm env) => switch (alpha) {
      final double a => a,
      final EnvironmentAlpha a => a.at(env),
      _ => throw RuleError('alpha $alpha is neither a double nor an EnvironmentAlpha'),
    };

/// target field -> source, for one rule.
@immutable
class Derive<F extends Enum> {
  const Derive([this.values = const {}]);

  final Map<F, DeriveSource> values;

  bool get isEmpty => values.isEmpty;

  @override
  String toString() => 'derive$values';
}

/// Sub-field entries of one rule: `(field, prop) -> value`, where the
/// value is a literal or a [DeriveSource] ([FieldRef] / [TokenRef]).
typedef SubMap<F extends Enum> = Map<(F, SubProp), Object>;

/// A rule as written: condition + style + derive + sub. [label]
/// is an optional human-readable name used in reports. A field may appear
/// in [style] or in [derive], not both ([flatten] throws). [sub] targets
/// single properties of composite fields; within one rule a field's
/// whole value is applied before that rule's sub entries for the field.
@immutable
class RawRule<F extends Enum> {
  const RawRule(Condition this._when,
      {this.style = const Style(),
      this.derive = const Derive(),
      this.sub = const {},
      this.label})
      : _whens = null;

  /// Cross-dimension "or": expands into one rule per condition. The expanded
  /// rules share one source position and the same style (same-level OR).
  /// An empty list is rejected by [flatten].
  const RawRule.any(List<Condition> this._whens,
      {this.style = const Style(),
      this.derive = const Derive(),
      this.sub = const {},
      this.label})
      : _when = null;

  final Condition? _when;
  final List<Condition>? _whens;
  final Style<F> style;
  final Derive<F> derive;
  final SubMap<F> sub;
  final String? label;

  List<Condition> get whens => _whens ?? <Condition>[_when!];
}

/// A rule-region constant that needs several cubes (an "any"). Use it
/// with [RawRule.any]: `RawRule.any(region.whens, ...)`, or mix it with single
/// [Condition] constants through [regionWhens].
@immutable
class AnyWhen {
  const AnyWhen(this.whens);
  final List<Condition> whens;

  @override
  String toString() => 'AnyWhen($whens)';
}

/// The conditions of region constants (each a [Condition] or an
/// [AnyWhen]) as one list for [RawRule.any]: a designer's "any of these
/// regions".
List<Condition> regionWhens(Iterable<Object> regions) => <Condition>[
      for (final Object r in regions)
        ...switch (r) {
          final Condition c => <Condition>[c],
          final AnyWhen a => a.whens,
          _ => throw RuleError('not a region constant: $r'),
        },
    ];

/// One rule after flattening (and environment expansion, see
/// [expandEnvValues]).
@immutable
class FlatRule<F extends Enum> {
  const FlatRule({
    required this.index,
    required this.position,
    required this.condition,
    required this.style,
    this.derive = const Derive(),
    this.sub = const {},
    required this.label,
    required this.source,
    required this.provider,
    this.indexInProvider = 0,
    this.envSlots,
  });

  /// Index in the flattened chain.
  final int index;

  /// Source position. Rules expanded from one [RawRule.any] or from one
  /// environment-dependent value share a position.
  final int position;
  final Condition condition;
  final Style<F> style;
  final Derive<F> derive;
  final SubMap<F> sub;

  /// Path-like label, e.g. `p0#3.1` or the user label.
  final String label;

  /// The authored rule. Sub-rules expanded from it point here too.
  final RawRule<F> source;

  /// Index of the provider in the chain this rule came from.
  final int provider;

  /// Index of the authored rule in its provider's list.
  final int indexInProvider;

  /// For a sub-rule expanded from environment-dependent values: field ->
  /// which value was split and which slot this sub-rule holds, e.g.
  /// `systemBlue dark normal-contrast slot`. Null for a rule that was not
  /// expanded.
  final Map<F, String>? envSlots;

  /// Whether this rule was expanded from an environment-dependent value.
  bool get isExpanded => envSlots != null;

  /// Debug description of the authored rule: index in its provider's list,
  /// label and provider, e.g. `rule #3 "rest" (defaults)`. [providerName]
  /// names provider indices. With [field], a sub-rule also names the
  /// split value and its slot: `rule #1 (theme), systemBlue dark
  /// normal-contrast slot`.
  String describeSource([String Function(int provider)? providerName, F? field]) {
    final String? userLabel = source.label;
    final StringBuffer b = StringBuffer('rule #$indexInProvider');
    if (userLabel != null) {
      b.write(' "$userLabel"');
    }
    b.write(' (${providerName?.call(provider) ?? 'provider $provider'})');
    if (envSlots?[field] case final String slot) {
      b.write(', $slot');
    }
    return b.toString();
  }

  bool get isEmpty => style.isEmpty && derive.isEmpty && sub.isEmpty;

  /// Fields this rule sets, by value, by derive, or by a sub entry (each
  /// field once).
  Iterable<F> get setFields => <F>{
        ...style.values.keys,
        ...derive.values.keys,
        for (final (F, SubProp) k in sub.keys) k.$1,
      };

  /// Every (target field, source) pair of this rule: whole derives and sub
  /// entries whose value is a [DeriveSource].
  Iterable<(F, DeriveSource)> get sources sync* {
    for (final MapEntry<F, DeriveSource> e in derive.values.entries) {
      yield (e.key, e.value);
    }
    for (final MapEntry<(F, SubProp), Object> e in sub.entries) {
      final Object v = e.value;
      if (v is DeriveSource) {
        yield (e.key.$1, v);
      }
    }
  }

  @override
  String toString() => '[$index @$position $label] $condition $style'
      '${derive.isEmpty ? '' : ' $derive'}${sub.isEmpty ? '' : ' sub$sub'}';
}

/// A full assignment of every dimension of a component.
@immutable
class Minterm {
  Minterm(this.dimensions, List<Object> values)
      : values = List<Object>.unmodifiable(values) {
    assert(dimensions.length == values.length);
  }

  final List<Dimension<Object>> dimensions;
  final List<Object> values;

  Object operator [](Dimension<Object> dim) {
    final int i = dimensions.indexOf(dim);
    if (i < 0) {
      throw RuleError('Dimension "${dim.name}" not part of this component');
    }
    return values[i];
  }

  T get<T extends Object>(Dimension<T> dim) => this[dim] as T;

  @override
  bool operator ==(Object other) =>
      other is Minterm && listEquals(other.values, values);

  @override
  int get hashCode => Object.hashAll(values);

  @override
  String toString() {
    final List<String> parts = <String>[];
    for (int i = 0; i < dimensions.length; i++) {
      final Dimension<Object> d = dimensions[i];
      final Object v = values[i];
      if (d.isBool) {
        if (v == true) {
          parts.add(d.name);
        }
      } else {
        parts.add('${d.name}=${_valueName(v)}');
      }
    }
    return '{${parts.join(', ')}}';
  }
}

/// A dimension that flat call-site parameters may exclude: a state the
/// widget passes through (disabled, a semantic state such as selected /
/// value / error / selection, or an interaction state). [resting] is the
/// set of values under which a flat parameter still applies when the
/// field's defaults vary by this dimension (`{false}` for bool states,
/// `{unchecked}` for Checkbox value, `{none, unselected}` for IconButton
/// selection). [interaction] marks hovered / focused / pressed / dragged,
/// which flat parameters leave out of the eligible set unless asked (not
/// eligible by default).
@immutable
class StateDim {
  const StateDim(this.resting, {this.interaction = false});

  /// Bool state with resting value false.
  const StateDim.off({this.interaction = false}) : resting = const <Object>{false};

  final Set<Object> resting;
  final bool interaction;
}

/// Component description: fields, dimensions, derived dimensions, and the
/// (analysis-only) field x dimension allowance table.
class ComponentSpec<F extends Enum> {
  ComponentSpec({
    required this.name,
    required this.fields,
    required this.dimensions,
    Map<F, Set<Dimension<Object>>>? mayVaryBy,
    Map<F, Type>? fieldTypes,
    Map<F, Composite>? composites,
    Map<Dimension<Object>, F>? derivedDimensions,
    Map<Dimension<Object>, StateDim>? stateDimensions,
    List<Condition>? impossible,
  })  : mayVaryBy = mayVaryBy ?? const {},
        impossible = impossible ?? const <Condition>[],
        fieldTypes = fieldTypes ?? const {},
        composites = composites ?? const {},
        derivedDimensions = derivedDimensions ?? const {},
        stateDimensions = stateDimensions ?? const {};

  final String name;
  final List<F> fields;
  final List<Dimension<Object>> dimensions;

  /// ANALYSIS ONLY: not part of the design. For each
  /// field, the dimensions it may vary by. A field absent from the map may
  /// vary by every dimension. Read only by [checkAllowance].
  final Map<F, Set<Dimension<Object>>> mayVaryBy;

  /// Dimensions whose value the component computes from a resolved
  /// field of its own (two-pass resolve): dimension -> source field. E.g.
  /// Switch hasThumbIcon <- thumbIcon, IconButton expressive size <- sizeVariant,
  /// Slider variant <- year2023. Checked by [checkDerivedDimensions].
  final Map<Dimension<Object>, F> derivedDimensions;

  /// The state dimensions a flat call-site parameter may exclude, with
  /// their resting values (see [StateDim]).
  /// Appearance, environment, content and derived dimensions are never
  /// listed: a flat parameter applies to the instance's appearance, and
  /// environment/content are not states.
  final Map<Dimension<Object>, StateDim> stateDimensions;

  /// Combinations the widget never produces (e.g. disabled together
  /// with hovered / focused / pressed), as cubes: a minterm matching any of
  /// them is impossible. Region conditions treat impossible minterms as
  /// don't-cares; [debugCheckPossible] is the widget-side assertion.
  final List<Condition> impossible;

  /// Whether [m] matches one of the [impossible] cubes.
  bool isImpossible(Minterm m) => impossible.any((Condition c) => c.matches(m));

  /// Stand-in for the widget's debug assertion that the state tuple it
  /// resolves is possible. Throws a [RuleError] naming the matching cube.
  /// Returns true so it can sit inside an `assert(...)`.
  bool debugCheckPossible(Minterm m) {
    for (final Condition c in impossible) {
      if (c.matches(m)) {
        throw RuleError('$name: impossible state $m (declared impossible: $c)');
      }
    }
    return true;
  }

  /// Optional value type per field. When both ends of a derive edge
  /// have a type, [checkDerive] requires them to be equal (identity derive).
  final Map<F, Type> fieldTypes;

  /// Composite fields (per-property merge, sub-field targets). Fields
  /// not listed here keep whole-value "last rule wins".
  final Map<F, Composite> composites;

  /// The dimensions [field] may vary by (all dims when unrestricted).
  Set<Dimension<Object>> varyBy(F field) =>
      mayVaryBy[field] ?? dimensions.toSet();

  /// All minterms in lexicographic order of [dimensions] domains.
  List<Minterm> minterms() {
    List<List<Object>> acc = <List<Object>>[<Object>[]];
    for (final Dimension<Object> d in dimensions) {
      acc = <List<Object>>[
        for (final List<Object> prefix in acc)
          for (final Object v in d.domain) <Object>[...prefix, v],
      ];
    }
    return <Minterm>[for (final List<Object> v in acc) Minterm(dimensions, v)];
  }
}

/// Flattens one provider's (flat) rule list: one [FlatRule] per rule, or
/// per condition of a [RawRule.any] (the expansions share one position).
///
/// With [splitter], every rule holding an environment-dependent value is
/// replaced by its environment-conditioned sub-rules ([expandEnvValues]),
/// at the same position. The expansion of an authored rule is computed
/// once and cached on the rule, so a const default list, a theme or scope
/// list and the global token rules are expanded once, not on every chain
/// build. [providerName] names the provider in debug messages.
///
/// With [splitter], the flattened list itself is cached per rule list
/// object as well (keyed by the other arguments), so a const default list
/// at the head of every chain yields the same [FlatRule] objects on every
/// chain build.
List<FlatRule<F>> flatten<F extends Enum>(List<RawRule<F>> rules,
    {int provider = 0, int firstIndex = 0, int firstPosition = 0, EnvSplitter? splitter, String? providerName}) {
  if (splitter == null) {
    return _flatten(rules, provider, firstIndex, firstPosition, null, providerName);
  }
  final Object? cached = _flatLists[rules];
  if (cached is _FlatList<F> &&
      identical(cached.splitter, splitter) &&
      cached.provider == provider &&
      cached.firstIndex == firstIndex &&
      cached.firstPosition == firstPosition &&
      cached.providerName == providerName) {
    return cached.rules;
  }
  final List<FlatRule<F>> out =
      List<FlatRule<F>>.unmodifiable(_flatten(rules, provider, firstIndex, firstPosition, splitter, providerName));
  _flatLists[rules] = _FlatList<F>(out, splitter, provider, firstIndex, firstPosition, providerName);
  return out;
}

final Expando<Object> _flatLists = Expando<Object>('flatList');

class _FlatList<F extends Enum> {
  _FlatList(this.rules, this.splitter, this.provider, this.firstIndex, this.firstPosition, this.providerName);
  final List<FlatRule<F>> rules;
  final EnvSplitter splitter;
  final int provider;
  final int firstIndex;
  final int firstPosition;
  final String? providerName;
}

List<FlatRule<F>> _flatten<F extends Enum>(List<RawRule<F>> rules, int provider, int firstIndex, int firstPosition,
    EnvSplitter? splitter, String? providerName) {
  final List<FlatRule<F>> out = <FlatRule<F>>[];
  for (int i = 0; i < rules.length; i++) {
    final RawRule<F> rule = rules[i];
    final String label = rule.label ?? 'p$provider#$i';
    final List<Condition> whens = rule.whens;
    final List<List<EnvPiece<F>>?>? expanded;
    if (splitter == null) {
      _validate(rule, label);
      expanded = null;
    } else {
      expanded = _expansionOf(rule, splitter, label,
          () => 'rule #$i${rule.label == null ? '' : ' "${rule.label}"'} (${providerName ?? 'provider $provider'})');
    }
    for (int k = 0; k < whens.length; k++) {
      final Condition cond = whens[k];
      final String where = whens.length > 1 ? '$label/any$k' : label;
      final List<EnvPiece<F>>? pieces = expanded?[k];
      if (pieces == null) {
        out.add(FlatRule<F>(
          index: firstIndex + out.length,
          position: firstPosition + i,
          condition: cond,
          style: rule.style,
          derive: rule.derive,
          sub: rule.sub,
          label: where,
          source: rule,
          provider: provider,
          indexInProvider: i,
        ));
        continue;
      }
      for (final EnvPiece<F> p in pieces) {
        out.add(FlatRule<F>(
          index: firstIndex + out.length,
          position: firstPosition + i,
          condition: p.condition,
          style: p.style,
          derive: p.derive,
          sub: p.sub,
          label: where,
          source: rule,
          provider: provider,
          indexInProvider: i,
          envSlots: p.slots,
        ));
      }
    }
  }
  return out;
}

/// Checks [rule] (conditions, derive sources) and, with [splitter], its
/// environment expansion per condition (null where nothing varies).
/// Cached per rule and splitter; a rule that fails a check throws every
/// time.
List<List<EnvPiece<F>>?>? _expansionOf<F extends Enum>(
    RawRule<F> rule, EnvSplitter splitter, String label, String Function() where) {
  final Object? cached = _expansions[rule];
  if (cached is _Expansion<F> && identical(cached.splitter, splitter)) {
    return cached.pieces;
  }
  _validate(rule, label);
  assert(debugCheckEnvExpandable(rule, splitter, where()));
  final List<Condition> whens = rule.whens;
  final List<List<EnvPiece<F>>?> pieces = <List<EnvPiece<F>>?>[
    for (final Condition c in whens) expandEnvValues(rule, c, splitter),
  ];
  final List<List<EnvPiece<F>>?>? result = pieces.every((List<EnvPiece<F>>? p) => p == null) ? null : pieces;
  _expansions[rule] = _Expansion<F>(splitter, result);
  return result;
}

final Expando<Object> _expansions = Expando<Object>('envExpansion');

class _Expansion<F extends Enum> {
  _Expansion(this.splitter, this.pieces);
  final EnvSplitter splitter;
  final List<List<EnvPiece<F>>?>? pieces;
}

void _validate<F extends Enum>(RawRule<F> rule, String label) {
  final List<Condition> whens = rule.whens;
  if (whens.isEmpty) {
    throw RuleError('$label: RawRule.any with no conditions');
  }
  _checkRuleDerive(rule, label);
  for (int k = 0; k < whens.length; k++) {
    // Validates a const When now.
    try {
      whens[k].constraints;
    } on RuleError catch (e) {
      throw RuleError('${whens.length > 1 ? '$label/any$k' : label}: ${e.message}');
    }
  }
}

void _checkRuleDerive<F extends Enum>(RawRule<F> rule, String label) {
  void checkSource(String target, DeriveSource src) {
    if (src is FieldRef && src.field is! F) {
      throw RuleError('$label: $target <- $src: '
          'field reference to another component (${src.field.runtimeType}); '
          'components may reference only their own fields and the global '
          'token channel');
    }
  }

  rule.style.values.forEach((F f, Object v) {
    if (v is TokenRef) {
      throw RuleError('$label: ${f.name}: token reference $v used as a literal '
          'value in style; put it in derive (or sub)');
    }
  });
  for (final MapEntry<F, DeriveSource> e in rule.derive.values.entries) {
    if (rule.style.values.containsKey(e.key)) {
      throw RuleError('$label: ${e.key.name} is set in both style and derive');
    }
    checkSource(e.key.name, e.value);
  }
  for (final MapEntry<(F, SubProp), Object> e in rule.sub.entries) {
    final Object v = e.value;
    if (v is DeriveSource) {
      checkSource('${e.key.$1.name}.${e.key.$2.name}', v);
    }
  }
}

/// Environment-dependent values (e.g. a CupertinoDynamicColor, or a
/// TextStyle holding one) are only a way of writing several plain values at
/// once, one per environment slot. When a chain is built, [flatten]
/// replaces every rule holding one by environment-conditioned sub-rules
/// with plain values ([expandEnvValues]); after that the engine never sees
/// an environment-dependent value, and the environment dimensions are
/// ordinary dimensions.
abstract class EnvSplitter {
  const EnvSplitter();

  /// Every environment slot, as environment dimension -> value (one entry
  /// per combination, every slot over the same dimensions).
  List<Map<Dimension<Object>, Object>> get slots;

  /// Whether [value] differs per environment (and so must be expanded).
  bool varies(Object value);

  /// The plain value of [value] in [slot]. Only called when [varies] is
  /// true.
  Object at(Object value, Map<Dimension<Object>, Object> slot);

  /// Debug: where [value] nests an environment-dependent value that [at]
  /// doesn't reach (e.g. `TextStyle.shadows[0].color`), or null.
  String? debugUnresolved(Object value) => null;

  /// Debug: the places [at] handles, for error messages.
  String get debugResolvedPlaces => '';

  /// Debug: short name of a varying [value], e.g. `systemBlue`.
  String describe(Object value) => '$value';

  /// Debug: name of value [v] of environment dimension [d] in a slot
  /// description, e.g. `dark`.
  String slotValueName(Dimension<Object> d, Object v) => '${d.name}=${_valueName(v)}';

  /// Debug: which slot of [value] [slot] is, e.g. `systemBlue dark
  /// normal-contrast slot`. Names only the dimensions that change [value]
  /// at [slot].
  String describeSlot(Object value, Map<Dimension<Object>, Object> slot) {
    final Object here = at(value, slot);
    final List<String> parts = <String>[
      for (final MapEntry<Dimension<Object>, Object> e in slot.entries)
        if (slots.any((Map<Dimension<Object>, Object> s) =>
            s[e.key] != e.value &&
            slot.keys.every((Dimension<Object> d) => d == e.key || s[d] == slot[d]) &&
            at(value, s) != here))
          slotValueName(e.key, e.value),
    ];
    return '${describe(value)} ${parts.isEmpty ? 'every-environment' : parts.join(' ')} slot';
  }
}

/// One environment-conditioned sub-rule of an authored rule (see
/// [expandEnvValues]).
@immutable
class EnvPiece<F extends Enum> {
  const EnvPiece(this.condition, this.style, this.sub, this.slots, {this.derive = const Derive()});

  /// The authored condition intersected with the slot cube (for the derive
  /// part: the authored condition).
  final Condition condition;

  /// The authored style and literal sub entries with each
  /// environment-dependent value replaced by its plain value in the slot
  /// (for the derive part: empty style, the derive sub entries).
  final Style<F> style;
  final SubMap<F> sub;

  /// The authored derive (derive part only).
  final Derive<F> derive;

  /// Field -> split value and slot, for debug output (null for the derive
  /// part).
  final Map<F, String>? slots;
}

/// Expands the environment-dependent values of [rule] under condition
/// [when] (one condition of the rule): returns null when no style value or
/// literal sub entry varies; otherwise one sub-rule per group of slots in
/// which every varying value has the same plain value:
///
/// * only slots inside [when] are kept (a dark-only rule takes the dark
///   slots of a dynamic color);
/// * slots with equal values are merged into cubes (a color whose elevated
///   variants equal its base ones gives sub-rules without an interfaceLevel
///   condition);
/// * condition = [when] and the cube.
///
/// Derives (whole and sub entries) are not copied into the sub-rules: they
/// go into one last piece under [when] as written, so a derive stays one
/// rule without environment conditions and is evaluated per minterm (each
/// environment takes its source's value in the same environment). Within
/// one rule a field is set by value or by derive, not both, and a whole
/// value applies before the rule's sub entries, so putting the derive part
/// after the value sub-rules keeps the rule's meaning. All pieces keep the
/// authored rule's position (see [flatten]), so ordering semantics don't
/// change.
List<EnvPiece<F>>? expandEnvValues<F extends Enum>(RawRule<F> rule, Condition when, EnvSplitter splitter) {
  final List<F> styleKeys = <F>[
    for (final MapEntry<F, Object> e in rule.style.values.entries)
      if (splitter.varies(e.value)) e.key,
  ];
  final List<(F, SubProp)> subKeys = <(F, SubProp)>[
    for (final MapEntry<(F, SubProp), Object> e in rule.sub.entries)
      if (e.value is! DeriveSource && splitter.varies(e.value)) e.key,
  ];
  if (styleKeys.isEmpty && subKeys.isEmpty) {
    return null;
  }
  final Map<Dimension<Object>, Set<Object>> cond = when.constraints;
  final List<Map<Dimension<Object>, Object>> slots = splitter.slots;
  // Slots inside the condition, grouped by their plain values.
  final List<(List<Object>, List<int>)> groups = <(List<Object>, List<int>)>[];
  for (int k = 0; k < slots.length; k++) {
    final bool inside = slots[k].entries.every(
        (MapEntry<Dimension<Object>, Object> e) => cond[e.key]?.contains(e.value) ?? true);
    if (!inside) {
      continue;
    }
    final List<Object> values = <Object>[
      for (final F f in styleKeys) splitter.at(rule.style.values[f]!, slots[k]),
      for (final (F, SubProp) s in subKeys) splitter.at(rule.sub[s]!, slots[k]),
    ];
    final int g = groups.indexWhere(((List<Object>, List<int>) x) => listEquals(x.$1, values));
    if (g < 0) {
      groups.add((values, <int>[k]));
    } else {
      groups[g].$2.add(k);
    }
  }
  final List<EnvPiece<F>> out = <EnvPiece<F>>[];
  final SubMap<F> literalSub = <(F, SubProp), Object>{
    for (final MapEntry<(F, SubProp), Object> e in rule.sub.entries)
      if (e.value is! DeriveSource) e.key: e.value,
  };
  final SubMap<F> deriveSub = <(F, SubProp), Object>{
    for (final MapEntry<(F, SubProp), Object> e in rule.sub.entries)
      if (e.value is DeriveSource) e.key: e.value,
  };
  for (final (List<Object> values, List<int> ks) in groups) {
    final Map<F, Object> style = Map<F, Object>.of(rule.style.values);
    final SubMap<F> sub = Map<(F, SubProp), Object>.of(literalSub);
    for (int i = 0; i < styleKeys.length; i++) {
      style[styleKeys[i]] = values[i];
    }
    for (int i = 0; i < subKeys.length; i++) {
      sub[subKeys[i]] = values[styleKeys.length + i];
    }
    for (final Map<Dimension<Object>, Set<Object>> cube in _mergeSlots(<Map<Dimension<Object>, Set<Object>>>[
      for (final int k in ks)
        <Dimension<Object>, Set<Object>>{
          for (final MapEntry<Dimension<Object>, Object> e in slots[k].entries) e.key: <Object>{e.value},
        },
    ])) {
      final Map<Dimension<Object>, Set<Object>> combined = Map<Dimension<Object>, Set<Object>>.of(cond);
      cube.forEach((Dimension<Object> d, Set<Object> s) {
        combined[d] = cond[d]?.intersection(s) ?? s;
      });
      // A representative slot of the cube, for the debug description.
      final Map<Dimension<Object>, Object> rep = slots[ks.firstWhere((int k) =>
          cube.entries.every((MapEntry<Dimension<Object>, Set<Object>> e) => e.value.contains(slots[k][e.key])))];
      out.add(EnvPiece<F>(
        Condition(combined),
        Style<F>(style),
        sub,
        <F, String>{
          for (final F f in styleKeys) f: splitter.describeSlot(rule.style.values[f]!, rep),
          for (final (F, SubProp) s in subKeys) s.$1: splitter.describeSlot(rule.sub[s]!, rep),
        },
      ));
    }
  }
  if (!rule.derive.isEmpty || deriveSub.isNotEmpty) {
    out.add(EnvPiece<F>(when, Style<F>(), deriveSub, null, derive: rule.derive));
  }
  return out;
}

/// Merges slot cubes (dimension -> value set, same dimensions) that differ
/// in exactly one dimension, until none do; then drops dimensions whose
/// set is the whole domain.
List<Map<Dimension<Object>, Set<Object>>> _mergeSlots(List<Map<Dimension<Object>, Set<Object>>> cubes) {
  List<Map<Dimension<Object>, Set<Object>>> current = cubes;
  bool merged = true;
  while (merged) {
    merged = false;
    final List<Map<Dimension<Object>, Set<Object>>> next = <Map<Dimension<Object>, Set<Object>>>[];
    final Set<int> used = <int>{};
    for (int i = 0; i < current.length; i++) {
      if (used.contains(i)) {
        continue;
      }
      for (int j = i + 1; j < current.length; j++) {
        if (used.contains(j)) {
          continue;
        }
        Dimension<Object>? diff;
        bool one = true;
        for (final Dimension<Object> d in current[i].keys) {
          if (!setEquals(current[i][d], current[j][d])) {
            if (diff != null) {
              one = false;
              break;
            }
            diff = d;
          }
        }
        if (one && diff != null) {
          next.add(Map<Dimension<Object>, Set<Object>>.of(current[i])
            ..[diff] = <Object>{...current[i][diff]!, ...current[j][diff]!});
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
  return <Map<Dimension<Object>, Set<Object>>>[
    for (final Map<Dimension<Object>, Set<Object>> c in current)
      <Dimension<Object>, Set<Object>>{
        for (final MapEntry<Dimension<Object>, Set<Object>> e in c.entries)
          if (e.value.length < e.key.domain.length) e.key: e.value,
      },
  ];
}

/// Debug check of one authored [rule] against [splitter], run when the
/// rule is first expanded. [where] names the rule (`rule #1 (theme)`).
/// Throws an [AssertionError] naming the rule and the field when a value
/// nests an environment-dependent value where [splitter] doesn't reach it
/// ([EnvSplitter.debugUnresolved]), which would otherwise render one fixed
/// variant in every environment. Environment-conditioned rules may hold
/// environment-dependent values: expansion keeps only the slots inside the
/// condition. Returns true so it can sit inside an `assert`.
bool debugCheckEnvExpandable<F extends Enum>(RawRule<F> rule, EnvSplitter splitter, String where) {
  void check(String field, Object v) {
    if (v is DeriveSource) {
      return;
    }
    final String? nested = splitter.debugUnresolved(v);
    if (nested != null) {
      throw AssertionError('$where: $field holds an environment-dependent value at $nested, '
          'where it is not expanded per environment (it would render one fixed variant everywhere). '
          '${splitter.debugResolvedPlaces}');
    }
  }

  rule.style.values.forEach((F f, Object v) => check(f.name, v));
  rule.sub.forEach(((F, SubProp) k, Object v) => check('${k.$1.name}.${k.$2.name}', v));
  return true;
}

/// Concatenates providers in order (defaults, StyleTheme, scopes, call site).
/// Also checks the derive graph of the whole chain for cycles
/// ([deriveOrder]), statically over all derive entries regardless of their
/// conditions.
///
/// With [global] (the global token channel's spec), every [TokenRef]
/// must name one of its tokens; anything else is a cross-channel reference
/// and throws. [selfTokens] is for the global channel's own chain: a
/// [TokenRef] there is an internal reference and part of the cycle check.
///
/// With [spec], also checks that every condition uses only the spec's
/// dimensions ([checkDimensions]) and that no derived dimension depends on
/// itself ([checkDerivedDimensions]); the first cycle throws a [RuleError].
/// This is where a framework would run it (debug, at chain build), next to
/// the derive cycle check.
///
/// A group token of a group the global channel doesn't provide throws
/// with the group's name.
///
/// With [splitter], environment-dependent values are expanded into
/// environment-conditioned sub-rules ([flatten], [expandEnvValues]) before
/// the checks; [providerNames] name the providers in debug messages.
List<FlatRule<F>> chain<F extends Enum>(List<List<RawRule<F>>> providers,
    {ComponentSpec<Enum>? global,
    bool selfTokens = false,
    ComponentSpec<F>? spec,
    EnvSplitter? splitter,
    List<String>? providerNames}) {
  final List<FlatRule<F>> out = <FlatRule<F>>[];
  int position = 0;
  for (int p = 0; p < providers.length; p++) {
    final List<FlatRule<F>> flat = flatten(providers[p],
        provider: p,
        firstIndex: out.length,
        firstPosition: position,
        splitter: splitter,
        providerName: providerNames?[p]);
    if (flat.isNotEmpty) {
      position = flat.last.position + 1;
    }
    out.addAll(flat);
  }
  if (global != null) {
    final Set<Enum> tokens = global.fields.toSet();
    for (final FlatRule<F> r in out) {
      for (final (F target, DeriveSource src) in r.sources) {
        if (src is! TokenRef || tokens.contains(src.token)) {
          continue;
        }
        if (src.token case final GroupToken<Object, Object> g) {
          throw RuleError('${r.label}: ${target.name} <- $src: group '
              '${g.group} is not provided by the global channel '
              '${global.name}');
        }
        throw RuleError('${r.label}: ${target.name} <- $src: '
            '${src.token} is not a token of '
            'the global channel ${global.name}; components may reference '
            'only their own fields and the global channel');
      }
    }
  }
  deriveOrder(out, selfTokens: selfTokens);
  if (spec != null) {
    checkDimensions(spec, out);
    final List<DerivedDimensionCycle<F>> cycles = checkDerivedDimensions(spec, out);
    if (cycles.isNotEmpty) {
      throw RuleError(cycles.first.toString());
    }
  }
  return out;
}

/// Static topological order of the field-reference graph formed by every
/// derive entry (whole and sub) in [rules] (target after its source). Only
/// targets of derives appear. Throws [RuleError] on a cycle. With
/// [selfTokens] (the global channel), [TokenRef]s are edges too.
List<F> deriveOrder<F extends Enum>(List<FlatRule<F>> rules,
    {bool selfTokens = false}) {
  final Map<F, Set<F>> edges = <F, Set<F>>{}; // target -> field sources
  for (final FlatRule<F> r in rules) {
    for (final (F target, DeriveSource src) in r.sources) {
      final Set<F> s = edges.putIfAbsent(target, () => <F>{});
      if (src is FieldRef) {
        s.add(src.field as F);
      } else if (selfTokens && src is TokenRef && src.token is F) {
        s.add(src.token as F);
      }
    }
  }
  final List<F> order = <F>[];
  final Set<F> done = <F>{};
  final List<F> stack = <F>[];
  void visit(F f) {
    if (done.contains(f)) {
      return;
    }
    final int i = stack.indexOf(f);
    if (i >= 0) {
      final String cycle =
          <F>[...stack.sublist(i), f].map((F x) => x.name).join(' <- ');
      throw RuleError('derive cycle: $cycle');
    }
    stack.add(f);
    for (final F s in edges[f] ?? const <Never>{}) {
      visit(s);
    }
    stack.removeLast();
    done.add(f);
    if (edges.containsKey(f)) {
      order.add(f);
    }
  }

  edges.keys.toList().forEach(visit);
  return order;
}

/// The global token channel: one component whose dimensions are all
/// environment dimensions and whose fields are every token (any number of
/// token enums, e.g. a `ComponentSpec` of `Enum` with the fields
/// `[...Cs.values, ...Tt.values, ...]`). Its rules may reference other tokens of
/// the same channel ([TokenRef] with optional alpha, or [FieldRef]),
/// including sub-field targets of composite tokens (a type token's color
/// <- onSurface). Referencing components resolve it at the environment part
/// of their own minterm.
///
/// With [splitter], environment-dependent token values (dynamic colors)
/// are expanded into environment-conditioned rules when the channel is
/// built ([expandEnvValues], cached per authored rule), so the channel
/// only holds plain values and an internal reference with alpha applies
/// the alpha to each slot's plain color.
class TokenChannel<T extends Enum> {
  TokenChannel(this.spec, List<RawRule<T>> rules, {EnvSplitter? splitter, String providerName = 'global'})
      : flat = chain<T>(<List<RawRule<T>>>[rules],
            global: spec, selfTokens: true, splitter: splitter, providerNames: <String>[providerName]),
        _fieldSet = spec.fields.toSet() {
    for (final Dimension<Object> d in spec.dimensions) {
      if (!d.environment) {
        throw RuleError('token channel ${spec.name}: dimension "${d.name}" '
            'is not an environment dimension');
      }
    }
    checkDimensions(spec, flat); // throws on foreign dimensions
    checkDerive(spec, flat, selfTokens: true);
  }

  final ComponentSpec<T> spec;
  final List<FlatRule<T>> flat;
  final Set<Enum> _fieldSet;
  final Map<Minterm, Resolved<T>> _cache = <Minterm, Resolved<T>>{};

  /// Whether [token] is a token of this channel.
  bool has(Enum token) => _fieldSet.contains(token);

  /// The channel minterm for [referrer]: each channel dimension takes
  /// the referrer's value when the referrer has that dimension, otherwise
  /// the value from [env] (the theme's environment: brightness, contrast).
  Minterm project(Minterm referrer, Map<Dimension<Object>, Object> env) {
    if (spec.dimensions.isEmpty) {
      return _empty;
    }
    return Minterm(spec.dimensions, <Object>[
      for (final Dimension<Object> d in spec.dimensions)
        if (referrer.dimensions.contains(d))
          referrer[d]
        else
          env[d] ??
              (throw RuleError('token channel ${spec.name} varies by '
                  '"${d.name}", which neither the referrer nor the theme '
                  'environment provides')),
    ]);
  }

  late final Minterm _empty = Minterm(const <Dimension<Object>>[], const <Object>[]);

  /// Resolves the channel at the environment part of [referrer] (completed
  /// from [env], see [project]) and returns [token]'s value (null when
  /// unset). Cached per channel minterm.
  Object? read(Enum token, Minterm referrer,
      [Map<Dimension<Object>, Object> env = const <Dimension<Object>, Object>{}]) {
    // Components normally have none of the environment dims, so the
    // channel minterm is the theme env's: cache that resolution per env
    // map (identity) instead of projecting and hashing on every read.
    bool fromEnv = true;
    for (final Dimension<Object> d in spec.dimensions) {
      if (referrer.dimensions.contains(d)) {
        fromEnv = false;
        break;
      }
    }
    if (fromEnv) {
      return (_envOnly[env] ??= resolved(project(referrer, env))).values[token as T];
    }
    return resolved(project(referrer, env)).values[token as T];
  }

  final Map<Map<Dimension<Object>, Object>, Resolved<T>> _envOnly =
      Map<Map<Dimension<Object>, Object>, Resolved<T>>.identity();

  /// The resolved channel at channel minterm [m].
  Resolved<T> resolved(Minterm m) =>
      _cache[m] ??= resolve<T>(flat, m, spec.fields, composites: spec.composites, selfTokens: true);
}

/// The global token channel as seen by components (exactly one).
///
/// [env] supplies the environment dimensions of the channel that the
/// referring component's minterm doesn't have (brightness, highContrast).
/// [Tokens.lerp] is a theme animation frame between two global channels.
class Tokens {
  Tokens(this.global, {this.env = const <Dimension<Object>, Object>{}}) : _lerp = null;

  Tokens._(this.global, this.env, this._lerp);

  /// A frame of a theme animation from [a] to [b]: every group is
  /// resolved in both at the same environment minterm and lerped with the
  /// group's own lerp; a token reads its field of the lerped group value.
  /// Internal references were already evaluated inside [a] and [b] (final
  /// values are lerped, like ThemeData.lerp). The groups come from the
  /// channels' specs ([GroupChannelSpec], see [lerpGroupsOf]); no list.
  /// The frame's [env] is [a]'s below t = 0.5 and [b]'s from there on (the
  /// discrete switch ThemeData.lerp / ColorScheme.lerp make for brightness).
  factory Tokens.lerp(Tokens a, Tokens b, double t) =>
      Tokens._(a.global, t < 0.5 ? a.env : b.env, GroupLerp(a, b, t, lerpGroupsOf(a, b)));

  final TokenChannel<Enum> global;
  final Map<Dimension<Object>, Object> env;
  final GroupLerp? _lerp;

  /// The global channel minterm for a referrer minterm [m].
  Minterm envMinterm(Minterm m) => global.project(m, env);

  /// Value of [ref] at the environment part of [m], with the alpha operator
  /// applied (an [EnvironmentAlpha] is picked at the same environment).
  /// Null when the token is unset. [RuleError] if [ref] doesn't name a
  /// global token.
  Object? read(TokenRef<Enum> ref, Minterm m) {
    final Object? v = _raw(ref, m);
    final Object? alpha = ref.alpha;
    if (alpha == null || v == null) {
      return v;
    }
    if (v is! Color) {
      throw RuleError('$ref: alpha applied to a non-Color token ($v)');
    }
    return applyAlpha(v, alphaAt(alpha, alpha is double ? noReferrer : envMinterm(m)));
  }

  Object? _raw(TokenRef<Enum> ref, Minterm m) {
    final GroupLerp? l = _lerp;
    final Enum token = ref.token;
    if (!global.has(token)) {
      throw RuleError('$ref is not a token of the global channel '
          '${global.spec.name}');
    }
    if (l != null) {
      return l.read(token, m);
    }
    return global.read(token, m, env);
  }
}

/// Result of resolving one minterm.
class Resolved<F extends Enum> {
  Resolved(this.values, this.winners,
      [this.contributors = const <Never, Never>{}]);

  final Map<F, Object> values;

  /// Which flat rule supplied each field (for a derived field: the rule
  /// whose derive won, not the rule that set the source). For a composite
  /// field: the last rule that contributed to it.
  final Map<F, FlatRule<F>> winners;

  /// For composite fields, every rule whose contribution may survive
  /// into the merged value (static approximation, see [resolveSymbolic]).
  final Map<F, List<FlatRule<F>>> contributors;
}

// ---------------------------------------------------------------------------
// Symbolic values (unbound token reads).

/// A field's value with token reads left unbound.
sealed class SymVal {
  const SymVal();
}

/// A literal value.
final class LitVal extends SymVal {
  const LitVal(this.value);
  final Object value;
  @override
  String toString() => 'lit($value)';
}

/// A read of a global token (with its alpha), bound later.
final class TokVal extends SymVal {
  const TokVal(this.ref);
  final TokenRef<Enum> ref;
  @override
  String toString() => 'tok($ref)';
}

/// Alpha applied to another symbolic value (internal global-channel
/// reference with an [EnvironmentAlpha], picked per minterm).
final class AlphaVal extends SymVal {
  const AlphaVal(this.inner, this.alpha);
  final SymVal inner;

  /// A `double` or an [EnvironmentAlpha].
  final Object alpha;
  @override
  String toString() => 'alpha($inner, $alpha)';
}

/// A [FieldRef] kept as a node ([resolveSymbolic] with `keepRefs`):
/// the value of [field], whose own symbolic value is [inner]. Evaluates to
/// [inner]. Only used by the expression-based "varies by" comparison
/// (flat_params.dart), which must tell "derived from fg" apart from a
/// literal that happens to equal fg's value.
final class RefVal extends SymVal {
  const RefVal(this.field, this.inner);
  final Enum field;
  final SymVal inner;
  @override
  String toString() => 'ref(.${field.name}: $inner)';
}

/// A composite field: contributions in chain order; `prop == null` is a
/// whole value, otherwise a sub entry.
final class FoldVal extends SymVal {
  const FoldVal(this.composite, this.parts);
  final Composite composite;
  final List<(SubProp?, SymVal)> parts;
  @override
  String toString() => 'fold($composite, $parts)';
}

/// Evaluates [v]; null = unset. An [EnvironmentAlpha] is picked at the
/// environment part of [m] (or at [m] itself without [tokens]: the global
/// channel resolving itself).
Object? evalSym(SymVal v, Tokens? tokens, Minterm m) {
  switch (v) {
    case LitVal():
      return v.value;
    case TokVal():
      if (tokens == null) {
        throw RuleError('${v.ref}: no token channel given');
      }
      return tokens.read(v.ref, m);
    case AlphaVal():
      final Object? x = evalSym(v.inner, tokens, m);
      if (x == null) {
        return null;
      }
      if (x is! Color) {
        throw RuleError('alpha(${v.alpha}) applied to a non-Color value ($x)');
      }
      return applyAlpha(x, alphaAt(v.alpha, tokens == null ? m : tokens.envMinterm(m)));
    case RefVal():
      return evalSym(v.inner, tokens, m);
    case FoldVal():
      return foldComposite(v.composite, <(SubProp?, Object?)>[
        for (final (SubProp? p, SymVal s) in v.parts) (p, evalSym(s, tokens, m)),
      ]);
  }
}

/// Folds evaluated contributions (chain order) of one composite field.
/// Unset (null) contributions are skipped. Null if nothing is set.
Object? foldComposite(Composite c, List<(SubProp?, Object?)> parts) {
  Object? acc;
  final Map<SubProp, Object> slots = <SubProp, Object>{};
  for (final (SubProp? p, Object? v) in parts) {
    if (v == null) {
      continue;
    }
    if (p == null) {
      if (!c.accepts(v)) {
        throw RuleError('$c field: whole value $v is not a ${c.name}');
      }
      acc = acc == null ? v : c.merge(acc, v);
      for (final SubProp q in c.props) {
        final Object? x = c.get(v, q);
        if (x != null) {
          slots[q] = x;
        }
      }
    } else {
      final Type t = c.propType(p);
      if ((t == Color && v is! Color) || (t == double && v is! double)) {
        throw RuleError('${c.name}.${p.name}: expected $t, got $v');
      }
      slots[p] = v;
    }
  }
  if (acc == null && slots.isEmpty) {
    return null;
  }
  return c.withProps(acc ?? c.empty, slots);
}

/// Result of resolving one minterm with token reads left unbound.
class SymbolicStyle<F extends Enum> {
  SymbolicStyle(this.symbols, this.winners, this.contributors)
      : _literal = symbols.values.every((SymVal s) => s is LitVal)
            ? <F, Object>{
                for (final MapEntry<F, SymVal> e in symbols.entries)
                  e.key: (e.value as LitVal).value,
              }
            : null;

  /// Field -> symbolic value. Fields that end up unset are absent.
  final Map<F, SymVal> symbols;

  /// Same as [Resolved.winners].
  final Map<F, FlatRule<F>> winners;

  /// Same as [Resolved.contributors].
  final Map<F, List<FlatRule<F>>> contributors;

  final Map<F, Object>? _literal;

  /// Fields whose value is a literal (no token read).
  Map<F, Object> get literals => <F, Object>{
        for (final MapEntry<F, SymVal> e in symbols.entries)
          if (e.value case LitVal(:final Object value)) e.key: value,
      };

  /// Fields whose value is a plain token read.
  Map<F, TokenRef<Enum>> get tokenRefs => <F, TokenRef<Enum>>{
        for (final MapEntry<F, SymVal> e in symbols.entries)
          if (e.value case TokVal(:final TokenRef<Enum> ref)) e.key: ref,
      };

  /// The resolved values for [tokens] at [m].
  ///
  /// Fast path: when every field is a literal, the same precomputed map is
  /// returned on every call.
  Map<F, Object> bind(Tokens? tokens, Minterm m) {
    final Map<F, Object>? lit = _literal;
    if (lit != null) {
      return lit;
    }
    final Map<F, Object> out = <F, Object>{};
    symbols.forEach((F f, SymVal s) {
      final Object? v = evalSym(s, tokens, m);
      if (v != null) {
        out[f] = v;
      }
    });
    return out;
  }
}

/// One contribution to a composite field found in phase 1.
class _Part<F extends Enum> {
  _Part(this.rule, this.prop, this.value);
  final FlatRule<F> rule;
  final SubProp? prop;

  /// A literal or a [DeriveSource].
  final Object value;
}

/// Phase 1 + reference folding, without reading any token value.
///
/// * Non-composite field: the last matching rule that sets it (value or
///   derive) wins.
/// * Composite field: every matching contribution (whole value, whole
///   derive, sub entry) is kept in chain order, back to the last literal
///   whole value that replaces everything (a complete BorderSideStyle). [foldComposite]
///   merges them at bind time, because whether a token-derived whole value
///   sets a slot (e.g. a type token with or without color) is only known
///   then.
/// * References: a [FieldRef] is replaced by the source's symbolic value; a
///   [TokenRef] becomes a [TokVal], or with [selfTokens] (the global
///   channel) the referenced token's symbolic value plus alpha.
/// * Contributors (shadow check): a sub entry survives unless a later sub
///   entry or literal whole value sets the same slot; a whole value
///   survives unless a later literal replaces everything. Token-derived
///   whole values are assumed to set no slot (conservative).
/// * With [keepRefs], a [FieldRef] becomes a [RefVal] wrapping the
///   source's symbolic value instead of the bare source value (same
///   result when bound; only the structure differs).
/// * A plain alpha on an internal reference is folded into a literal Color
///   right away; an [EnvironmentAlpha] stays an [AlphaVal] and is picked
///   per minterm at bind time.
SymbolicStyle<F> resolveSymbolic<F extends Enum>(
    List<FlatRule<F>> rules, Minterm m, List<F> fields,
    {Map<F, Composite> composites = const {},
    bool selfTokens = false,
    bool keepRefs = false}) {
  final Map<F, FlatRule<F>> winners = <F, FlatRule<F>>{};
  final Map<F, Object> entries = <F, Object>{}; // non-composite: lit or src
  final Map<F, List<_Part<F>>> parts = <F, List<_Part<F>>>{}; // reversed
  final Set<F> closed = <F>{};
  final int total = fields.length;

  void addPart(F f, Composite c, FlatRule<F> r, SubProp? p, Object v) {
    if (closed.contains(f)) {
      return;
    }
    winners.putIfAbsent(f, () => r);
    parts.putIfAbsent(f, () => <_Part<F>>[]).add(_Part<F>(r, p, v));
    if (p == null && v is! DeriveSource && c.replacesAll(v)) {
      closed.add(f);
    }
  }

  for (int i = rules.length - 1; i >= 0 && closed.length < total; i--) {
    final FlatRule<F> r = rules[i];
    if (r.isEmpty || !r.condition.matches(m)) {
      continue;
    }
    // Reverse order within the rule: sub entries, then the whole value.
    r.sub.forEach(((F, SubProp) k, Object v) {
      final Composite? c = composites[k.$1];
      if (c == null) {
        throw RuleError('${r.label}: sub entry ${k.$1.name}.${k.$2.name} on '
            'a field that is not composite');
      }
      if (!c.props.contains(k.$2)) {
        throw RuleError('${r.label}: ${c.name} has no sub-field ${k.$2.name}');
      }
      addPart(k.$1, c, r, k.$2, v);
    });
    void whole(F f, Object v) {
      final Composite? c = composites[f];
      if (c != null) {
        addPart(f, c, r, null, v);
      } else if (!closed.contains(f)) {
        winners[f] = r;
        entries[f] = v;
        closed.add(f);
      }
    }

    r.style.values.forEach(whole);
    r.derive.values.forEach(whole);
  }

  final Map<F, SymVal?> out = <F, SymVal?>{};
  final Set<F> visiting = <F>{};

  late final SymVal? Function(F f) sym;
  SymVal? toSym(Object x) {
    switch (x) {
      case FieldRef():
        final SymVal? src = sym(x.field as F);
        return keepRefs && src != null ? RefVal(x.field, src) : src;
      case TokenRef():
        if (!selfTokens) {
          return TokVal(x);
        }
        if (x.token is! F) {
          // A reference to a whole group can't be an internal reference.
          throw RuleError('$x: internal reference to a token that is not a '
              'field of this channel');
        }
        final SymVal? base = sym(x.token as F);
        final Object? a = x.alpha;
        if (base == null || a == null) {
          return base;
        }
        if (base case LitVal(:final Object value) when a is double) {
          if (value is! Color) {
            throw RuleError('$x: alpha applied to a non-Color token ($value)');
          }
          return LitVal(applyAlpha(value, a));
        }
        return AlphaVal(base, a);
      default:
        return LitVal(x);
    }
  }

  sym = (F f) {
    if (out.containsKey(f)) {
      return out[f];
    }
    if (!visiting.add(f)) {
      throw RuleError('derive cycle through ${f.name} at $m');
    }
    final SymVal? result;
    final List<_Part<F>>? ps = parts[f];
    if (ps != null) {
      final Composite c = composites[f]!;
      final List<(SubProp?, SymVal)> folded = <(SubProp?, SymVal)>[
        for (final _Part<F> p in ps.reversed)
          if (toSym(p.value) case final SymVal s) (p.prop, s),
      ];
      if (folded.isEmpty) {
        result = null;
      } else if (folded.every(((SubProp?, SymVal) e) => e.$2 is LitVal)) {
        final Object? v = foldComposite(c, <(SubProp?, Object?)>[
          for (final (SubProp? p, SymVal s) in folded) (p, (s as LitVal).value),
        ]);
        result = v == null ? null : LitVal(v);
      } else {
        result = FoldVal(c, folded);
      }
    } else if (entries.containsKey(f)) {
      result = toSym(entries[f]!);
    } else {
      result = null;
    }
    visiting.remove(f);
    out[f] = result;
    return result;
  };

  final Map<F, SymVal> symbols = <F, SymVal>{};
  for (final F f in <F>{...entries.keys, ...parts.keys}) {
    final SymVal? s = sym(f);
    if (s != null) {
      symbols[f] = s;
    }
  }

  final Map<F, List<FlatRule<F>>> contributors = <F, List<FlatRule<F>>>{};
  parts.forEach((F f, List<_Part<F>> ps) {
    final Composite c = composites[f]!;
    final Set<SubProp> taken = <SubProp>{};
    final List<FlatRule<F>> alive = <FlatRule<F>>[];
    for (final _Part<F> p in ps) {
      // ps is in reverse chain order: later contributions first.
      final SubProp? prop = p.prop;
      if (prop != null) {
        if (taken.add(prop)) {
          alive.add(p.rule);
        }
      } else {
        alive.add(p.rule);
        if (p.value is! DeriveSource) {
          for (final SubProp q in c.props) {
            if (c.get(p.value, q) != null) {
              taken.add(q);
            }
          }
        }
      }
    }
    contributors[f] = alive;
  });

  return SymbolicStyle<F>(symbols, winners, contributors);
}

/// Order-only resolution: [resolveSymbolic], then bind the token reads.
/// A derive whose source is unset leaves the target unset; a token that
/// reads null leaves the target unset.
Resolved<F> resolve<F extends Enum>(
    List<FlatRule<F>> rules, Minterm m, List<F> fields,
    {Tokens? tokens,
    Map<F, Composite> composites = const {},
    bool selfTokens = false}) {
  final SymbolicStyle<F> s = resolveSymbolic(rules, m, fields, composites: composites, selfTokens: selfTokens);
  return Resolved<F>(s.bind(tokens, m), s.winners, s.contributors);
}

/// A derive on a color field written under an environment condition.
class EnvConditionedColorDerive<F extends Enum> {
  EnvConditionedColorDerive(this.rule, this.target, this.source, this.dimensions);
  final FlatRule<F> rule;

  /// `backgroundColor` or `textStyle.color`.
  final String target;
  final DeriveSource source;
  final List<Dimension<Object>> dimensions;

  @override
  String toString() => '${rule.label}: $target <- $source under ${rule.condition}, which constrains '
      '${dimensions.map((Dimension<Object> d) => d.name).join(', ')}; derives on color fields are written as one '
      'rule without environment conditions (use an EnvironmentAlpha for a per-environment alpha)';
}

/// Spec check for library defaults (run by a test, like the region
/// freshness checks): a derive on a color field (whole field whose
/// [ComponentSpec.fieldTypes] entry is [Color], or a color sub-property of
/// a composite) is written as a group, one rule without environment
/// conditions, so each environment takes the source's value in the same
/// environment. Returns every derive whose rule constrains an environment
/// dimension. User rules are not restricted.
List<EnvConditionedColorDerive<F>> findEnvConditionedColorDerives<F extends Enum>(
    ComponentSpec<F> spec, List<FlatRule<F>> rules) {
  final List<EnvConditionedColorDerive<F>> out = <EnvConditionedColorDerive<F>>[];
  for (final FlatRule<F> r in rules) {
    final List<Dimension<Object>> env = <Dimension<Object>>[
      for (final Dimension<Object> d in r.condition.constraints.keys)
        if (d.environment && r.condition.constrains(d)) d,
    ];
    if (env.isEmpty) {
      continue;
    }
    r.derive.values.forEach((F f, DeriveSource src) {
      if (spec.fieldTypes[f] == Color) {
        out.add(EnvConditionedColorDerive<F>(r, f.name, src, env));
      }
    });
    r.sub.forEach(((F, SubProp) k, Object v) {
      if (v is DeriveSource && spec.composites[k.$1]?.propType(k.$2) == Color) {
        out.add(EnvConditionedColorDerive<F>(r, '${k.$1.name}.${k.$2.name}', v, env));
      }
    });
  }
  return out;
}

/// Static derive checks for one component chain, throwing [RuleError]:
/// * every [TokenRef] names a token of the global channel in [tokens], and
///   that channel's dimensions are a subset of [spec]'s dimensions (with
///   [selfTokens], i.e. for the global channel itself, a [TokenRef] must
///   name one of [spec]'s own fields);
/// * when [ComponentSpec.fieldTypes] gives both types, a [FieldRef] links
///   fields of the same value type, and a [TokenRef] without alpha links a
///   token and a target of the same type (with alpha: the target is Color);
/// * Sub entries target composite fields and one of their sub-fields;
///   the value (or the source's type, when known) has the sub-field's type;
///   whole literal values of a composite field have the composite's type.
void checkDerive<F extends Enum>(ComponentSpec<F> spec, List<FlatRule<F>> rules,
    {Tokens? tokens, bool selfTokens = false}) {
  final Set<Enum> own = spec.fields.toSet();
  Type? sourceType(FlatRule<F> r, String target, DeriveSource src) {
    switch (src) {
      case FieldRef():
        return spec.fieldTypes[src.field as F];
      case TokenRef():
        if (selfTokens) {
          if (!own.contains(src.token)) {
            throw RuleError('${r.label}: $target <- $src: not a token of '
                '${spec.name}');
          }
          return src.alpha != null ? Color : spec.fieldTypes[src.token as F];
        }
        if (tokens == null) {
          throw RuleError('${r.label}: $target <- $src: no token channel given');
        }
        final TokenChannel<Enum> c = tokens.global;
        final Enum token = src.token;
        if (!c.has(token)) {
          throw RuleError('${r.label}: $target <- $src: not a token of the '
              'global channel ${c.spec.name}');
        }
        for (final Dimension<Object> d in c.spec.dimensions) {
          // Environment dims the component lacks come from the theme.
          if (!spec.dimensions.contains(d) && !tokens.env.containsKey(d)) {
            throw RuleError('${r.label}: $target <- $src: channel '
                '${c.spec.name} varies by "${d.name}", which is not a '
                'dimension of ${spec.name}');
          }
        }
        return src.alpha != null ? Color : c.spec.fieldTypes[token];
    }
  }

  for (final FlatRule<F> r in rules) {
    r.derive.values.forEach((F target, DeriveSource src) {
      final Type? tt = spec.fieldTypes[target];
      final Type? st = sourceType(r, target.name, src);
      if (tt != null && st != null && tt != st) {
        throw RuleError('${r.label}: ${target.name} ($tt) <- $src ($st): '
            'type mismatch');
      }
    });
    r.style.values.forEach((F f, Object v) {
      final Composite? c = spec.composites[f];
      if (c != null && !c.accepts(v)) {
        throw RuleError('${r.label}: ${f.name} is a ${c.name} field, got $v');
      }
    });
    r.sub.forEach(((F, SubProp) k, Object v) {
      final String target = '${k.$1.name}.${k.$2.name}';
      final Composite? c = spec.composites[k.$1];
      if (c == null) {
        throw RuleError('${r.label}: sub entry $target on a field that is '
            'not composite');
      }
      if (!c.props.contains(k.$2)) {
        throw RuleError('${r.label}: ${c.name} has no sub-field ${k.$2.name}');
      }
      final Type tt = c.propType(k.$2);
      if (v is DeriveSource) {
        final Type? st = sourceType(r, target, v);
        if (st != null && st != tt) {
          throw RuleError('${r.label}: $target ($tt) <- $v ($st): type mismatch');
        }
      } else if ((tt == Color && v is! Color) || (tt == double && v is! double)) {
        throw RuleError('${r.label}: $target expects $tt, got $v');
      }
    });
  }
}

/// minterm -> resolved style, for every minterm of [spec]. Runs
/// [checkDerive] first when any rule derives or has sub entries.
Map<Minterm, Resolved<F>> resolveTable<F extends Enum>(
    ComponentSpec<F> spec, List<FlatRule<F>> rules,
    {Tokens? tokens}) {
  if (rules.any((FlatRule<F> r) => !r.derive.isEmpty || r.sub.isNotEmpty) ||
      spec.composites.isNotEmpty) {
    checkDerive(spec, rules, tokens: tokens);
  }
  return <Minterm, Resolved<F>>{
    for (final Minterm m in spec.minterms())
      m: resolve(rules, m, spec.fields,
          tokens: tokens, composites: spec.composites),
  };
}

/// Two tables are semantically equal when every minterm resolves to the same
/// values.
bool tablesEqual<F extends Enum>(
    Map<Minterm, Resolved<F>> a, Map<Minterm, Resolved<F>> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<Minterm, Resolved<F>> e in a.entries) {
    final Resolved<F>? other = b[e.key];
    if (other == null || !mapEquals(other.values, e.value.values)) {
      return false;
    }
  }
  return true;
}

/// A rule sets [field] under a condition constraining [dimension], which the
/// field may not vary by. Or the rule derives [field] from [via], which
/// may vary by [dimension] while [field] may not.
class AllowanceViolation<F extends Enum> {
  AllowanceViolation(this.rule, this.field, this.dimension, {this.via});
  final FlatRule<F> rule;
  final F field;
  final Dimension<Object> dimension;
  final DeriveSource? via;
  @override
  String toString() => via == null
      ? '${rule.label}: ${field.name} set under ${rule.condition}, '
          'but ${field.name} may not vary by ${dimension.name}'
      : '${rule.label}: ${field.name} <- $via, which may vary by '
          '${dimension.name}, but ${field.name} may not';
}

/// ANALYSIS ONLY: the field x dimension allowance table is not a framework
/// rule and the framework keeps no field classification. This check stays
/// in the engine as an optional analysis tool ("which
/// defaults vary a layout-box field by interaction?"); no correctness test
/// depends on it. Derived dimensions have their own check
/// ([checkDerivedDimensions]).
///
/// Field x dimension check. Derives and sub entries count as value-setting
/// for their field, except sub entries on paint properties
/// ([SubProp.isPaint]), which are unrestricted. In addition a derived target (whole or sub) must be
/// allowed to vary by every dimension its source may vary by: for a
/// [FieldRef], the source's allowance row; for a [TokenRef], the global
/// channel's (environment) dimensions, looked up in [tokens] (skipped when
/// [tokens] is null).
List<AllowanceViolation<F>> checkAllowance<F extends Enum>(
    ComponentSpec<F> spec, List<FlatRule<F>> rules,
    {Tokens? tokens}) {
  checkDimensions(spec, rules);
  final List<AllowanceViolation<F>> out = <AllowanceViolation<F>>[];
  for (final FlatRule<F> r in rules) {
    // Sub entries on paint properties (color, decorationColor) are not
    // restricted by the field's row; sub entries on layout properties and
    // whole values are.
    final Set<F> restricted = <F>{
      ...r.style.values.keys,
      ...r.derive.values.keys,
      for (final (F, SubProp) k in r.sub.keys)
        if (!k.$2.isPaint) k.$1,
    };
    for (final F f in restricted) {
      final Set<Dimension<Object>>? allowed = spec.mayVaryBy[f];
      if (allowed == null) {
        continue;
      }
      for (final Dimension<Object> d in r.condition.constraints.keys) {
        if (r.condition.constrains(d) && !allowed.contains(d)) {
          out.add(AllowanceViolation<F>(r, f, d));
        }
      }
    }
    final List<(F, DeriveSource)> checked = <(F, DeriveSource)>[
      ...r.derive.values.entries.map((MapEntry<F, DeriveSource> e) => (e.key, e.value)),
      for (final MapEntry<(F, SubProp), Object> e in r.sub.entries)
        if (e.value is DeriveSource && !e.key.$2.isPaint) (e.key.$1, e.value as DeriveSource),
    ];
    for (final (F f, DeriveSource src) in checked) {
      final Set<Dimension<Object>>? allowed = spec.mayVaryBy[f];
      if (allowed == null) {
        continue;
      }
      final Iterable<Dimension<Object>> srcDims = switch (src) {
        FieldRef() => spec.varyBy(src.field as F),
        TokenRef() => tokens == null
            ? const <Dimension<Object>>[]
            : tokens.global.spec.dimensions.where(spec.dimensions.contains),
      };
      for (final Dimension<Object> d in srcDims) {
        if (!allowed.contains(d)) {
          out.add(AllowanceViolation<F>(r, f, d, via: src));
        }
      }
    }
  }
  return out;
}

/// Throws a [RuleError] when a rule's condition uses a dimension that is not
/// one of [spec]'s dimensions. (Separate from [checkAllowance], since this
/// one is a correctness check.)
void checkDimensions<F extends Enum>(ComponentSpec<F> spec, List<FlatRule<F>> rules) {
  for (final FlatRule<F> r in rules) {
    for (final Dimension<Object> d in r.condition.constraints.keys) {
      if (!spec.dimensions.contains(d)) {
        throw RuleError('${r.label}: dimension "${d.name}" '
            'is not a dimension of ${spec.name}');
      }
    }
  }
}

/// A dependency cycle through at least one derived dimension.
///
/// [path] lists nodes of the dependency graph, each depending on the next,
/// and returns to its first node: a derived [Dimension] depends on its
/// source field; a field depends on the fields it is derived from
/// ([FieldRef], whole or sub entry) and on every derived dimension that a
/// rule setting it (value, derive or sub entry) constrains. [rules] are the
/// rules behind the field -> dimension edges of the cycle.
class DerivedDimensionCycle<F extends Enum> {
  DerivedDimensionCycle(this.path, this.rules);
  final List<Object> path;
  final List<FlatRule<F>> rules;

  /// The (field, dimension) edges of the cycle: some rule sets the field
  /// under a condition constraining the dimension.
  List<(F, Dimension<Object>)> get edges => <(F, Dimension<Object>)>[
        for (int i = 0; i + 1 < path.length; i++)
          if (path[i] is F && path[i + 1] is Dimension<Object>) (path[i] as F, path[i + 1] as Dimension<Object>),
      ];

  @override
  String toString() {
    String name(Object n) => n is Dimension<Object> ? 'dim ${n.name}' : (n as Enum).name;
    return 'derived dimension cycle: ${path.map(name).join(' <- ')}; '
        'rules: ${rules.map((FlatRule<F> r) => '${r.label} ${r.condition}').join(', ')}';
  }
}

/// Dedicated acyclicity check for derived dimensions
/// ([ComponentSpec.derivedDimensions]). A derived dimension D <- field S is
/// computed after S is resolved, so S's resolved value must not depend on D;
/// no rule may set S (or a field S is derived from, transitively) under a
/// condition that constrains D (strict subset of its domain). With several
/// derived dimensions the same holds through chains (S set under E,
/// E <- T, T set under D, D <- S): the check looks for any cycle in
/// the dependency graph described at [DerivedDimensionCycle]. An acyclic
/// graph gives a resolution order (multi-pass when derived dims depend on
/// each other). Static: conditions only, no minterm enumeration.
///
/// Reports one cycle per back edge found by a depth-first search from each
/// derived dimension, with every rule that creates one of its field ->
/// dimension edges (so every offending rule of a direct S-under-D case is
/// listed). Unlike [checkAllowance] it uses no field classification: it only
/// needs the declared dimension -> field map.
List<DerivedDimensionCycle<F>> checkDerivedDimensions<F extends Enum>(
    ComponentSpec<F> spec, List<FlatRule<F>> rules) {
  final Map<Dimension<Object>, F> derived = spec.derivedDimensions;
  if (derived.isEmpty) {
    return <DerivedDimensionCycle<F>>[];
  }
  derived.forEach((Dimension<Object> d, F f) {
    if (!spec.dimensions.contains(d)) {
      throw RuleError('${spec.name}: derived dimension "${d.name}" is not a dimension of the component');
    }
    if (!spec.fields.contains(f)) {
      throw RuleError('${spec.name}: derived dimension "${d.name}" <- ${f.name}: not a field of the component');
    }
  });
  // field -> fields it is derived from; field -> derived dim -> rules.
  final Map<F, Set<F>> fieldDeps = <F, Set<F>>{};
  final Map<F, Map<Dimension<Object>, List<FlatRule<F>>>> dimDeps = <F, Map<Dimension<Object>, List<FlatRule<F>>>>{};
  for (final FlatRule<F> r in rules) {
    for (final (F target, DeriveSource src) in r.sources) {
      if (src is FieldRef && src.field is F) {
        fieldDeps.putIfAbsent(target, () => <F>{}).add(src.field as F);
      }
    }
    final List<Dimension<Object>> constrained = <Dimension<Object>>[
      for (final Dimension<Object> d in derived.keys)
        if (r.condition.constrains(d)) d,
    ];
    if (constrained.isEmpty) {
      continue;
    }
    for (final F f in r.setFields) {
      final Map<Dimension<Object>, List<FlatRule<F>>> m =
          dimDeps.putIfAbsent(f, () => <Dimension<Object>, List<FlatRule<F>>>{});
      for (final Dimension<Object> d in constrained) {
        m.putIfAbsent(d, () => <FlatRule<F>>[]).add(r);
      }
    }
  }
  Iterable<Object> deps(Object n) sync* {
    if (n is Dimension<Object>) {
      yield derived[n]!;
    } else {
      yield* fieldDeps[n] ?? const <Never>{};
      yield* dimDeps[n]?.keys ?? const <Never>[];
    }
  }

  String key(Object n) => n is Dimension<Object> ? 'dim:${n.name}' : (n as Enum).name;
  final List<DerivedDimensionCycle<F>> out = <DerivedDimensionCycle<F>>[];
  final Set<String> seen = <String>{};
  final Set<Object> done = <Object>{};
  final List<Object> stack = <Object>[];
  void visit(Object n) {
    if (done.contains(n)) {
      return;
    }
    final int i = stack.indexOf(n);
    if (i >= 0) {
      final List<Object> path = <Object>[...stack.sublist(i), n];
      final List<FlatRule<F>> rs = <FlatRule<F>>[];
      for (int k = 0; k + 1 < path.length; k++) {
        final Object a = path[k];
        final Object b = path[k + 1];
        if (a is F && b is Dimension<Object>) {
          rs.addAll(dimDeps[a]![b]!);
        }
      }
      // Canonical key: the cycle's nodes rotated to start at the smallest.
      final List<String> names = <String>[for (final Object x in path.skip(1)) key(x)];
      int start = 0;
      for (int k = 1; k < names.length; k++) {
        if (names[k].compareTo(names[start]) < 0) {
          start = k;
        }
      }
      if (seen.add(<String>[...names.sublist(start), ...names.sublist(0, start)].join(','))) {
        out.add(DerivedDimensionCycle<F>(path, rs));
      }
      return;
    }
    stack.add(n);
    for (final Object s in deps(n).toList()) {
      visit(s);
    }
    stack.removeLast();
    done.add(n);
  }

  derived.keys.forEach(visit);
  return out;
}

/// RawRule [rule] sets [field], but on every minterm it matches a later rule
/// also sets [field], so it never takes effect.
class ShadowedRule<F extends Enum> {
  ShadowedRule(this.rule, this.field);
  final FlatRule<F> rule;
  final F field;
  @override
  String toString() => '${rule.label}: ${field.name} never wins '
      '(${rule.condition})';
}

/// A rule/field pair is shadowed iff it wins that field on no minterm. Since
/// a rule's condition is never empty, this is equivalent to "on every minterm
/// it matches, a later matching rule sets the field". Derives count as
/// setting the field. For a composite field, "wins" means "is among the
/// contributors" ([Resolved.contributors]).
List<ShadowedRule<F>> findShadowed<F extends Enum>(
    ComponentSpec<F> spec, List<FlatRule<F>> rules,
    [Map<Minterm, Resolved<F>>? table, Tokens? tokens]) {
  table ??= resolveTable(spec, rules, tokens: tokens);
  final Set<(int, F)> wins = <(int, F)>{};
  for (final Resolved<F> r in table.values) {
    r.winners.forEach((F f, FlatRule<F> rule) => wins.add((rule.index, f)));
    r.contributors.forEach((F f, List<FlatRule<F>> rs) {
      for (final FlatRule<F> rule in rs) {
        wins.add((rule.index, f));
      }
    });
  }
  return <ShadowedRule<F>>[
    for (final FlatRule<F> r in rules)
      for (final F f in r.setFields)
        if (!wins.contains((r.index, f))) ShadowedRule<F>(r, f),
  ];
}

/// A rule sets a literal TextStyle with `inherit: false` on a composite
/// TextStyle field. Resolution ignores `inherit` in rules (it merges per
/// property and the component fixes the output's `inherit`), so the flag
/// has no effect; the author probably expected it to replace the earlier
/// properties.
class TextStyleInheritDiagnostic<F extends Enum> {
  TextStyleInheritDiagnostic(this.rule, this.field);
  final FlatRule<F> rule;
  final F field;
  @override
  String toString() => '${rule.label}: ${field.name} sets TextStyle(inherit: '
      'false); rules merge TextStyle per property and ignore inherit '
      '(the component decides the resolved inherit)';
}

/// Debug-time check (like [checkAllowance]): every rule that sets a
/// literal `TextStyle(inherit: false, ...)` on a composite TextStyle field.
/// One entry per source position and field. Token-derived values are not
/// reported: a type token is a theme's complete style.
List<TextStyleInheritDiagnostic<F>> checkTextStyleInherit<F extends Enum>(
    ComponentSpec<F> spec, List<FlatRule<F>> rules) {
  final List<TextStyleInheritDiagnostic<F>> out = <TextStyleInheritDiagnostic<F>>[];
  final Set<(int, int, F)> seen = <(int, int, F)>{};
  for (final FlatRule<F> r in rules) {
    r.style.values.forEach((F f, Object v) {
      if (spec.composites[f] is TextStyleComposite &&
          v is TextStyle &&
          !v.inherit &&
          seen.add((r.provider, r.position, f))) {
        out.add(TextStyleInheritDiagnostic<F>(r, f));
      }
    });
  }
  return out;
}
