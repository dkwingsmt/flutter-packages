// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// COPIED from packages/style_codegen/engine/groups.dart by the generator. Do not
// edit here: edit the template and run the generator.

/// Token groups in the global channel (the ThemeExtension replacement).
///
/// A group is an enum whose values are tokens: it mixes in
/// [GroupTokenMixin], so each enum value is at the same time a field of
/// the global channel (the engine's field key), a typed [Token]
/// (components reference it through their source classes,
/// `.fromToken(...)` / `.fromCustomToken(...)`; token rules set it with
/// `token.set(value)` / `token.setFrom(source)` or a rule class) and a
/// read entry (`Brand.accent.of(context)`, non-null).
///
/// There is no data class for a whole group: a preset is a list of token
/// rules (values, environment-conditioned values and derives), and a
/// whole-group read is a Record assembled from single reads where needed.
///
/// Group tokens are ordinary global-channel fields, so they get "last rule
/// wins" per field, internal references (static cycle check, topological
/// evaluation) and composites (TextStyle) from the existing engine. A
/// theme animation lerps every token on its own resolved values
/// ([Tokens.lerp], [GroupTokenMixin.lerpObject]).
library;

import 'package:flutter/widgets.dart' show BuildContext;

import 'engine.dart';
import 'widgets.dart' show StyleTheme;

/// Makes an enum value a token of a group: the enum value is its own token
/// (field key). The enum supplies [lerp] (usually null: the built-in
/// type table of [lerpTokenValue] applies):
///
/// ```dart
/// enum Brand<T extends Object> with GroupTokenMixin<T> {
///   accent<Color>(),
///   radius<double>(),
///   info<SemanticGroup>(lerp: SemanticGroup.lerp);
///
///   const Brand({this.lerp});
///   @override
///   final T? Function(T? a, T? b, double t)? lerp;
///
///   static const TokenGroup group = TokenGroup('Brand', values);
/// }
/// ```
mixin GroupTokenMixin<T extends Object> on Enum implements Token<T> {
  /// How a theme animation interpolates this token. Null: the built-in
  /// type table ([lerpTokenValue]), then a switch at t = 0.5. Pass
  /// [discrete] to always switch.
  ///
  /// The engine never reads this field directly: [T] is in a parameter
  /// position, so reading it through a `Token<Object>` fails the runtime
  /// covariance check. It calls [lerpObject] instead.
  T? Function(T? a, T? b, double t)? get lerp;

  /// One theme-animation value of this token between [a] and [b] (values
  /// of this token, or null): [lerp] when given, otherwise the built-in
  /// type table, otherwise a switch at t = 0.5. Called inside this
  /// token's own [T], so the casts are sound.
  Object? lerpObject(Object? a, Object? b, double t) {
    final T? Function(T? a, T? b, double t)? f = lerp;
    if (f == null) {
      return lerpTokenValue(a, b, t);
    }
    return f(a as T?, b as T?, t);
  }

  /// The value type ([T]); the global channel's field type.
  Type get valueType => T;

  /// The value of this token at the environment of [context] (non-null).
  /// Throws a [RuleError] when the token's group is not registered in
  /// `StyleTheme(groups: ...)` or no rule gives it a value in the current
  /// environment.
  T of(BuildContext context) => StyleTheme.tokenOf<T>(context, this);
}

/// Theme-animation interpolation that always switches at t = 0.5 (for a
/// token's `lerp:`).
T? discrete<T>(T? a, T? b, double t) => t < 0.5 ? a : b;

/// A token group: its name (for diagnostics) and its tokens. Registered in
/// `StyleTheme(groups: [Brand.group])`.
final class TokenGroup {
  const TokenGroup(this.name, this.tokens);

  final String name;
  final List<GroupTokenMixin<Object>> tokens;

  @override
  String toString() => 'TokenGroup($name)';
}

/// A global channel spec built from token groups; remembers [groups].
class GroupChannelSpec extends ComponentSpec<Enum> {
  GroupChannelSpec({
    required super.name,
    required super.fields,
    required super.dimensions,
    required this.groups,
    super.fieldTypes,
    super.composites,
  });

  final List<TokenGroup> groups;
}

/// The global channel spec made of [groups]: every token is a field, its
/// field type is the token's value type, and value types listed in
/// [composites] (TextStyle) make the field a composite.
GroupChannelSpec groupChannelSpec(String name, List<TokenGroup> groups,
    {List<Dimension<Object>> dimensions = const <Dimension<Object>>[],
    Map<Type, Composite> composites = const <Type, Composite>{}}) {
  final List<GroupTokenMixin<Object>> all = <GroupTokenMixin<Object>>[
    for (final TokenGroup g in groups) ...g.tokens,
  ];
  return GroupChannelSpec(
    name: name,
    groups: List<TokenGroup>.unmodifiable(groups),
    fields: <Enum>[for (final GroupTokenMixin<Object> t in all) t],
    dimensions: dimensions,
    fieldTypes: <Enum, Type>{for (final GroupTokenMixin<Object> t in all) t: t.valueType},
    composites: <Enum, Composite>{
      for (final GroupTokenMixin<Object> t in all)
        if (composites[t.valueType] case final Composite c) t: c,
    },
  );
}

/// The name of the enum that declares [token] (`Brand` for
/// `Brand<Color>.accent`), for error messages about tokens whose group is
/// not registered.
String tokenEnumName(Enum token) {
  final String s = token.runtimeType.toString();
  final int lt = s.indexOf('<');
  return lt < 0 ? s : s.substring(0, lt);
}

/// A referrer with no dimensions: every environment dim comes from the
/// theme ([Tokens.env]).
final Minterm noReferrer = Minterm(const <Dimension<Object>>[], const <Object>[]);
