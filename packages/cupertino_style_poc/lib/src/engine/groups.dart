// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// App token groups in the global channel (ThemeExtension-like).
///
/// Every group is field-level: each token is its own field of the global
/// channel (there is no whole-group token). A group is a plain class `G`
/// (fields + lerp). Its tokens are the values of an enum that mixes in
/// [GroupTokenMixin]: each enum value is at the same time a field of the
/// global channel (the engine's field key), a [TokenRef] without alpha (so
/// a rule writes `Cs.primary` as a derive source and
/// `TokenRef(Cs.primary, alpha: 0.38)` for alpha), and a typed getter
/// `T? of(G group)` (a const static tear-off passed to the enum constructor).
/// Group fields are ordinary global-channel fields, so they get "last rule
/// wins" per field, internal references (static cycle check, topological
/// evaluation) and composites (TextStyle) from the existing engine. A whole
/// `G` value is sugar: [TokenGroup.value] expands it into one rule setting
/// every non-null field.
///
/// On the component side group tokens are [TokenRef]s: the symbolic stage
/// keeps them as `TokVal`, binding goes through [Tokens.read]. Nothing in
/// resolveSymbolic / the caches knows about groups.
library;

import 'engine.dart';

/// Makes an enum value its own alpha-less [TokenRef] (token = itself,
/// alpha = null) without a group: for token channels that are not built
/// from groups (engine tests). Group tokens use [GroupTokenMixin].
mixin TokenMixin on Enum implements TokenRef<Enum> {
  @override
  Enum get token => this;
  @override
  Object? get alpha => null;
  @override
  Type get channel => Enum;
}

/// A token of group [G] whose value has type [T]. Implemented by enum
/// values through [GroupTokenMixin].
abstract interface class GroupToken<G extends Object, T extends Object> implements TokenRef<Enum> {
  /// The token's value inside a whole group value.
  T? of(G group);

  /// The group type ([G]).
  Type get group;

  /// The value type ([T]); used as the global channel's field type.
  Type get valueType;
}

/// Makes an enum value a [GroupToken]: the enum value is its own token
/// (field key) and has no alpha. The enum supplies [of], normally from a
/// const static tear-off passed to its constructor:
///
/// ```dart
/// enum Brand<T extends Object> with GroupTokenMixin<BrandColors, T> {
///   success<Color>(_success), ...;
///   const Brand(this._of);
///   final T? Function(BrandColors) _of;
///   @override
///   T? of(BrandColors g) => _of(g);
///   static Color _success(BrandColors g) => g.success;
/// }
/// ```
mixin GroupTokenMixin<G extends Object, T extends Object> on Enum implements GroupToken<G, T> {
  @override
  Enum get token => this;
  @override
  Object? get alpha => null;
  @override
  Type get channel => Enum;
  @override
  Type get group => G;
  @override
  Type get valueType => T;
}

/// Reads one field of group [G] (typed by the token): `r(Cs.primary)`.
///
/// Also carries the global-channel environment minterm the group is
/// read at ([env]), so a build can take values that are not tokens from
/// the environment (ColorScheme.brightness from the brightness dim).
class GroupFieldReader<G extends Object> {
  GroupFieldReader(this._field, this.env);

  final Object? Function(GroupToken<G, Object> token) _field;

  /// The environment minterm (empty for [TokenGroup.assemble] without env).
  final Minterm env;

  T? call<T extends Object>(GroupToken<G, T> token) => _field(token) as T?;

  /// The value of environment dim [d], or null if the channel lacks it.
  V? envValue<V extends Object>(Dimension<V> d) => env.dimensions.contains(d) ? env[d] as V : null;
}

/// The descriptor of a group: its tokens, how to assemble a
/// whole value from fields ([build], needed for whole-group reads and
/// lerp) and the group's lerp.
class TokenGroup<G extends Object> {
  TokenGroup(this.name, this.tokens, this._build, this._lerp);

  final String name;
  final List<GroupToken<G, Object>> tokens;
  final G Function(GroupFieldReader<G> read) _build;
  final G Function(G a, G b, double t) _lerp;

  Type get type => G;

  /// Whole-group sugar: one rule setting every
  /// non-null field of [value].
  RawRule<Enum> value(Condition when, G value, {String? label}) => RawRule<Enum>(when,
      label: label,
      style: Style<Enum>(<Enum, Object>{
        for (final GroupToken<G, Object> t in tokens)
          if (t.of(value) case final Object v) t.token: v,
      }));

  /// The whole group value in [tokens] at (the environment part of) [m].
  G read(Tokens tokens, Minterm m) =>
      _build(GroupFieldReader<G>((GroupToken<G, Object> t) => tokens.read(t, m), tokens.envMinterm(m)));

  /// A whole value from per-token values given by [field].
  G assemble(Object? Function(GroupToken<G, Object> token) field, {Minterm? env}) =>
      _build(GroupFieldReader<G>(field, env ?? noReferrer));

  /// [_lerp] for callers holding a `TokenGroup<Object>`.
  Object lerpValues(Object a, Object b, double t) => _lerp(a as G, b as G, t);
}

/// A global channel spec built from token groups; remembers [groups]
/// so [Tokens.lerp] can find every group's lerp without a list.
class GroupChannelSpec extends ComponentSpec<Enum> {
  GroupChannelSpec({
    required super.name,
    required super.fields,
    required super.dimensions,
    required this.groups,
    super.fieldTypes,
    super.composites,
  });

  final List<TokenGroup<Object>> groups;
}

/// The global channel spec made of [groups]: every token is a field, its
/// field type is the token's value type, and value types listed in
/// [composites] (TextStyle) make the field a composite.
GroupChannelSpec groupChannelSpec(String name, List<TokenGroup<Object>> groups,
    {List<Dimension<Object>> dimensions = const <Dimension<Object>>[],
    Map<Type, Composite> composites = const <Type, Composite>{}}) {
  final List<GroupToken<Object, Object>> all = <GroupToken<Object, Object>>[
    for (final TokenGroup<Object> g in groups) ...g.tokens,
  ];
  return GroupChannelSpec(
    name: name,
    groups: List<TokenGroup<Object>>.unmodifiable(groups),
    fields: <Enum>[for (final GroupToken<Object, Object> t in all) t.token],
    dimensions: dimensions,
    fieldTypes: <Enum, Type>{for (final GroupToken<Object, Object> t in all) t.token: t.valueType},
    composites: <Enum, Composite>{
      for (final GroupToken<Object, Object> t in all)
        if (composites[t.valueType] case final Composite c) t.token: c,
    },
  );
}

/// The groups a lerp between [a] and [b] covers: those of [a]'s channel
/// that [b]'s channel provides too. Throws if a channel is not built from
/// groups.
List<TokenGroup<Object>> lerpGroupsOf(Tokens a, Tokens b) {
  final ComponentSpec<Enum> sa = a.global.spec;
  final ComponentSpec<Enum> sb = b.global.spec;
  for (final ComponentSpec<Enum> s in <ComponentSpec<Enum>>[sa, sb]) {
    if (s is! GroupChannelSpec) {
      throw RuleError('Tokens.lerp: channel ${s.name} is not built from token groups (groupChannelSpec)');
    }
  }
  final List<TokenGroup<Object>> gb = (sb as GroupChannelSpec).groups;
  return <TokenGroup<Object>>[
    for (final TokenGroup<Object> g in (sa as GroupChannelSpec).groups)
      if (gb.contains(g)) g,
  ];
}

/// Reads outside components. [env] is a global-channel minterm (or
/// any minterm; missing environment dims come from [Tokens.env]).
extension TokenReads on Tokens {
  /// A typed group token, e.g. `tokens.value(Brand.success)`.
  T? value<G extends Object, T extends Object>(GroupToken<G, T> token, {Minterm? env}) =>
      read(token, env ?? noReferrer) as T?;

  /// The whole value of a group.
  G groupValue<G extends Object>(TokenGroup<G> group, {Minterm? env}) => group.read(this, env ?? noReferrer);
}

/// A referrer with no dimensions: every environment dim comes from the
/// theme ([Tokens.env]).
final Minterm noReferrer = Minterm(const <Dimension<Object>>[], const <Object>[]);

/// One theme-animation frame (see [Tokens.lerp]).
class GroupLerp {
  GroupLerp(this.a, this.b, this.t, List<TokenGroup<Object>> groups)
      : _groupOf = <Enum, TokenGroup<Object>>{
          for (final TokenGroup<Object> g in groups)
            for (final GroupToken<Object, Object> tok in g.tokens) tok.token: g,
        };

  final Tokens a;
  final Tokens b;
  final double t;
  final Map<Enum, TokenGroup<Object>> _groupOf;
  final Map<(Object, Minterm), Object> _cache = <(Object, Minterm), Object>{};

  /// A group token: its field of the lerped group value.
  Object? read(Enum token, Minterm m) {
    final TokenGroup<Object>? g = _groupOf[token];
    if (g == null) {
      throw RuleError('$token: not in a group both channels of Tokens.lerp provide');
    }
    final Minterm em = a.envMinterm(m);
    final Object v = _cache[(g, em)] ??= g.lerpValues(g.read(a, m), g.read(b, m), t);
    return (token as GroupToken<Object, Object>).of(v);
  }
}
