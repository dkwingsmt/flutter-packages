// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Emits the library-level files: the environment part and the token
/// facade part.
library;

import 'model.dart';
import 'util.dart';

String _whenType(EnvDimModel d) => d.isBool ? 'bool?' : (d.isScalar ? '${d.type}?' : 'Set<${d.type}>?');

/// `style_library.g.dart`: EnvDims, TokenWhen, StyleEnvironment and
/// ResolvedEnvironment from the library's environment dimensions.
String emitEnvironment(LibraryModel lib, {required String specRelative}) {
  final Out o = Out();
  o.header(specRelative, partOf: lib.environmentPartOf);
  final List<String> helpers = copiedHelpers(lib.copied, <String>[for (final EnvDimModel d in lib.env) d.read]);
  if (helpers.isNotEmpty) {
    o.section('Environment readers of the spec (copied)');
    for (final String h in helpers) {
      o.raw(h);
      o.blank();
    }
  }
  final List<EnvDimModel> env = lib.env;
  String names() => <String>[for (final EnvDimModel d in env) d.name].join(', ');

  o.section('Environment dimensions');
  o.doc('Environment dimensions of the ${lib.name} library. Every component carries\n'
      'all of them, and so does the global token channel.');
  o.line('abstract final class EnvDims {');
  for (final EnvDimModel d in env) {
    if (d.isBool) {
      o.line("  static const BoolDimension ${d.name} = BoolDimension('${d.name}', environment: true);");
    } else {
      o.line("  static const Dimension<${d.type}> ${d.name} =");
      o.line("      Dimension<${d.type}>('${d.name}', ${d.type}.values, environment: true);");
    }
  }
  o.blank();
  o.line('  static const List<Dimension<Object>> all = <Dimension<Object>>[${names()}];');
  o.line('}');
  o.blank();

  o.doc('Condition of a [TokenRule]: environment dimensions only.');
  o.line('@immutable');
  o.line('final class TokenWhen {');
  o.line('  const TokenWhen({${<String>[for (final EnvDimModel d in env) 'this.${d.name}'].join(', ')}});');
  o.blank();
  for (final EnvDimModel d in env) {
    o.line('  final ${_whenType(d)} ${d.name};');
  }
  o.blank();
  o.line('  Condition toCondition() => Condition(<Dimension<Object>, Object>{');
  for (final EnvDimModel d in env) {
    o.line(d.isScalar
        ? '        if (${d.name} case final ${d.type} v) EnvDims.${d.name}: <Object>{v},'
        : '        EnvDims.${d.name}: ?${d.name},');
  }
  o.line('      });');
  o.blank();
  o.line('  @override');
  o.line('  bool operator ==(Object other) =>');
  o.line('      other is TokenWhen &&');
  for (int i = 0; i < env.length; i++) {
    final EnvDimModel d = env[i];
    o.line('      ${d.isBool || d.isScalar ? 'other.${d.name} == ${d.name}' : 'setEquals(other.${d.name}, ${d.name})'}${i == env.length - 1 ? ';' : ' &&'}');
  }
  o.blank();
  o.line('  @override');
  o.line('  int get hashCode => Object.hash(${<String>[
    for (final EnvDimModel d in env) d.isBool || d.isScalar ? d.name : '${d.name} == null ? null : Object.hashAllUnordered(${d.name}!)',
  ].join(', ')});');
  o.line('}');
  o.blank();

  o.doc('An explicit environment set by [StyleTheme] / [StyleScope]. A null\n'
      'field is read from the context at the component (the reader functions\n'
      'of the library spec).');
  o.line('@immutable');
  o.line('final class StyleEnvironment {');
  o.line('  const StyleEnvironment({${<String>[for (final EnvDimModel d in env) 'this.${d.name}'].join(', ')}});');
  o.blank();
  o.line('  static const StyleEnvironment none = StyleEnvironment();');
  o.blank();
  for (final EnvDimModel d in env) {
    o.line('  final ${d.type}? ${d.name};');
  }
  o.blank();
  o.doc("[inner]'s set fields over this one's.", indent: 2);
  o.line('  StyleEnvironment merge(StyleEnvironment? inner) => inner == null');
  o.line('      ? this');
  o.line('      : StyleEnvironment(');
  for (final EnvDimModel d in env) {
    o.line('          ${d.name}: inner.${d.name} ?? ${d.name},');
  }
  o.line('        );');
  o.blank();
  o.doc('Every field set: explicit ones, the rest from [context]. Reading the\n'
      'context registers the usual dependencies, so context changes rebuild\n'
      'as today.', indent: 2);
  o.line('  ResolvedEnvironment resolve(BuildContext context) => ResolvedEnvironment(');
  for (final EnvDimModel d in env) {
    o.line('        ${d.name}: ${d.name} ?? ${d.read}(context),');
  }
  o.line('      );');
  o.blank();
  o.line('  @override');
  o.line('  bool operator ==(Object other) =>');
  o.line('      other is StyleEnvironment &&');
  for (int i = 0; i < env.length; i++) {
    o.line('      other.${env[i].name} == ${env[i].name}${i == env.length - 1 ? ';' : ' &&'}');
  }
  o.blank();
  o.line('  @override');
  o.line('  int get hashCode => Object.hash(${names()});');
  o.line('}');
  o.blank();

  o.doc('A fully determined environment (the environment part of a minterm).');
  o.line('@immutable');
  o.line('final class ResolvedEnvironment {');
  o.line('  const ResolvedEnvironment({${<String>[for (final EnvDimModel d in env) 'required this.${d.name}'].join(', ')}});');
  o.blank();
  for (final EnvDimModel d in env) {
    o.line('  final ${d.type} ${d.name};');
  }
  o.blank();
  o.doc('The values in [EnvDims.all] order.', indent: 2);
  o.line('  List<Object> get values => <Object>[${names()}];');
  o.blank();
  o.line('  @override');
  o.line("  String toString() => '(${<String>[for (final EnvDimModel d in env) d.isBool ? '${d.name}: \$${d.name}' : '\${${d.name}.name}'].join(', ')})';");
  o.line('}');
  return o.toString();
}

/// The token facade part: the public token interface (statics over the
/// private enum), the private enum itself, the built-in group and the
/// token rule class.
String emitFacade(LibraryModel lib, {required String specRelative}) {
  final Out o = Out();
  o.header(specRelative, partOf: lib.facadePartOf);
  o.line("// The token rule's fields are private; a named parameter can't be.");
  o.line('// ignore_for_file: prefer_initializing_formals');
  o.blank();
  final String i = lib.tokenInterface;
  final String e = lib.tokenEnum;
  final String first = lib.tokens.first.name;
  o.doc('The built-in ${lib.name} tokens: one static const per token, plus\n'
      '[values]. The tokens are values of a private enum behind this\n'
      'library-owned interface, so adding a token is not a breaking change (a\n'
      'switch over [$i] is not exhaustive).\n'
      '\n'
      "The statics live on the interface because a dot shorthand looks for\n"
      "static members of the parameter's own type: `XSource.fromToken` takes a\n"
      '`$i<T>`, so `.fromToken(.$first)` finds [$first]\n'
      "here, and the type argument checks the token's value type against the\n"
      "slot's.\n"
      '\n'
      "App tokens don't implement this interface; they implement the engine's\n"
      '[Token] (through [GroupTokenMixin]) and are passed to\n'
      '`.fromCustomToken(...)`.');
  o.line('abstract interface class $i<T extends Object> implements Token<T> {');
  o.line('  static const List<$i<Object>> values = $e.values;');
  o.blank();
  for (final TokenModel t in lib.tokens) {
    if (t.doc != null) {
      o.blank();
      o.doc(t.doc!, indent: 2);
    }
    o.line('  static const $i<${t.type}> ${t.name} = $e.${t.name};');
  }
  o.blank();
  o.doc('The value of this token at the environment of [context] (non-null).', indent: 2);
  o.line('  T of(BuildContext context);');
  o.line('}');
  o.blank();

  o.doc('The tokens behind [$i]. Library-private, so adding one is not a\n'
      'breaking change. Every token uses the built-in theme-animation table\n'
      '([lerpTokenValue]).');
  o.line('enum $e<T extends Object> with GroupTokenMixin<T> implements $i<T> {');
  for (int k = 0; k < lib.tokens.length; k++) {
    final TokenModel t = lib.tokens[k];
    o.line('  ${t.name}<${t.type}>()${k == lib.tokens.length - 1 ? ';' : ','}');
  }
  o.blank();
  o.line('  const $e({this.lerp});');
  o.blank();
  o.line('  @override');
  o.line('  final T? Function(T? a, T? b, double t)? lerp;');
  o.line('}');
  o.blank();

  final String g = '${lowerFirst(lib.name)}TokenGroup';
  o.doc('The built-in ${lib.name} token group. Always part of the global channel\n'
      '(not listed in `StyleTheme(groups: ...)`).');
  o.line("const TokenGroup $g = TokenGroup('${lib.name}', $e.values);");
  o.blank();

  final String r = lib.tokenRule;
  String sourceType(TokenModel t) => t.type == 'Color' ? lib.tokenColorSource : '${lib.tokenSource}<${t.type}>';
  o.doc('Sets some ${lib.name} tokens: one optional parameter per token, and only\n'
      'the tokens given are set, so `$r($first: x)` leaves tokens derived\n'
      'from it deriving from the new value. Values may be\n'
      'environment-dependent (expanded per environment).\n'
      '\n'
      'The main constructor takes plain values; [$r.derive] takes sources\n'
      '(`.value(x)`, `.fromToken(...)`, `.fromCustomToken(...)` and, for\n'
      'colors, `.opacity(...)` / `.opaque(...)`). One token alone:\n'
      '`$i.x.set(value)` / `$i.x.setFrom(source)`.');
  o.line('final class $r extends TokenSourceRule {');
  o.line('  const $r({');
  for (final TokenModel t in lib.tokens) {
    o.line('    ${t.type}? ${t.name},');
  }
  o.line('    super.when,');
  o.line('  })  : ${_initializers(lib)};');
  o.blank();
  o.doc('Sources instead of plain values; literals are `.value(x)`.', indent: 2);
  o.line('  const $r.derive({');
  for (final TokenModel t in lib.tokens) {
    o.line('    ${sourceType(t)}? ${t.name},');
  }
  o.line('    super.when,');
  o.line('  })  : ${_initializers(lib)};');
  o.blank();
  o.line('  // A plain value (main constructor) or a source (.derive).');
  for (final TokenModel t in lib.tokens) {
    o.line('  final Object? _${t.name};');
  }
  o.blank();
  o.line('  static DeriveSource? _source<T extends Object>(Object? v) => switch (v) {');
  o.line('        null => null,');
  o.line('        final DeriveSource s => s,');
  o.line('        _ => ${lib.tokenSource}<T>.value(v as T),');
  o.line('      };');
  o.blank();
  o.line('  @override');
  o.line('  Map<Token<Object>, DeriveSource> get sources => <Token<Object>, DeriveSource>{');
  for (final TokenModel t in lib.tokens) {
    o.line('        $i.${t.name}: ?_source<${t.type}>(_${t.name}),');
  }
  o.line('      };');
  o.line('}');
  return o.toString();
}

String _initializers(LibraryModel lib) =>
    <String>[for (final TokenModel t in lib.tokens) '_${t.name} = ${t.name}'].join(',\n        ');
