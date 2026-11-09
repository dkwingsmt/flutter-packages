// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Reads the specs of one library directory with the analyzer (resolved,
/// never run) into the model.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/diagnostic/diagnostic.dart';
import 'package:analyzer/error/error.dart';
import 'package:path/path.dart' as p;

import 'model.dart';

/// A spec error: the spec does not compile, or does not have the shape the
/// generator reads.
final class SpecError implements Exception {
  SpecError(this.message);

  final String message;

  @override
  String toString() => 'SpecError: $message';
}

/// Reads every spec under [dir]: one library spec (a class annotated
/// `@StyleLibrary`) and any number of component specs (`@Component`).
Future<LibraryModel> readSpecs(String dir) async {
  final String root = p.normalize(p.absolute(dir));
  final List<String> files = <String>[
    for (final FileSystemEntity e in Directory(root).listSync()..sort((a, b) => a.path.compareTo(b.path)))
      if (e is File && e.path.endsWith('.dart')) e.path,
  ];
  final AnalysisContextCollection collection = AnalysisContextCollection(includedPaths: <String>[root]);
  LibraryModel? library;
  final List<(_SpecFile, ClassDeclaration)> components = <(_SpecFile, ClassDeclaration)>[];
  for (final String path in files) {
    final SomeResolvedUnitResult r = await collection.contextFor(path).currentSession.getResolvedUnit(path);
    if (r is! ResolvedUnitResult) {
      throw SpecError('$path: could not resolve ($r)');
    }
    final List<Diagnostic> errors = <Diagnostic>[
      for (final Diagnostic d in r.diagnostics)
        if (d.diagnosticCode.severity == DiagnosticSeverity.ERROR) d,
    ];
    if (errors.isNotEmpty) {
      throw SpecError(<String>[
        '$path does not compile:',
        for (final Diagnostic d in errors) '  ${r.lineInfo.getLocation(d.offset)}: ${d.message}',
      ].join('\n'));
    }
    final _SpecFile file = _SpecFile(path, r);
    for (final CompilationUnitMember m in r.unit.declarations) {
      if (m is! ClassDeclaration) {
        continue;
      }
      if (_annotation(m, 'StyleLibrary') != null) {
        if (library != null) {
          throw SpecError('$path: a second @StyleLibrary');
        }
        library = _readLibrary(file, m);
      } else if (_annotation(m, 'Component') != null) {
        components.add((file, m));
      }
    }
  }
  if (library == null) {
    throw SpecError('$root: no @StyleLibrary spec');
  }
  for (final (_SpecFile f, ClassDeclaration c) in components) {
    library.components.add(_readComponent(f, c, library));
  }
  return library;
}

final class _SpecFile {
  _SpecFile(this.path, this.result);

  final String path;
  final ResolvedUnitResult result;

  String text(AstNode n) => result.content.substring(n.offset, n.end);

  String where(AstNode n) => '$path:${result.lineInfo.getLocation(n.offset)}';

  Never fail(AstNode n, String message) => throw SpecError('${where(n)}: $message\n  ${text(n)}');

  /// Private top-level declarations, by name, as source.
  late final Map<String, String> privateDeclarations = <String, String>{
    for (final CompilationUnitMember m in result.unit.declarations)
      for (final String name in _declaredNames(m))
        if (name.startsWith('_')) name: text(m),
  };

  /// Declarations annotated `@emit`, as source without the annotation.
  late final List<String> emitted = <String>[
    for (final CompilationUnitMember m in result.unit.declarations)
      if (m.metadata.where((Annotation a) => a.name.name == 'emit').firstOrNull case final Annotation a)
        (text(m).substring(0, a.offset - m.offset) + text(m).substring(a.end - m.offset)).replaceFirst(RegExp(r'\n\n'), '\n'),
  ];
}

Iterable<String> _declaredNames(CompilationUnitMember m) sync* {
  switch (m) {
    case TopLevelVariableDeclaration(:final VariableDeclarationList variables):
      for (final VariableDeclaration v in variables.variables) {
        yield v.name.lexeme;
      }
    case FunctionDeclaration(:final Token name):
      yield name.lexeme;
    case ClassDeclaration(:final ClassNamePart namePart):
      yield namePart.typeName.lexeme;
    case EnumDeclaration(:final ClassNamePart namePart):
      yield namePart.typeName.lexeme;
    case GenericTypeAlias(:final Token name):
      yield name.lexeme;
    default:
      break;
  }
}

Annotation? _annotation(AnnotatedNode n, String name) =>
    n.metadata.where((Annotation a) => a.name.name == name).firstOrNull;

Map<String, Expression> _named(ArgumentList args) => <String, Expression>{
      for (final Argument a in args.arguments)
        if (a is NamedArgument) a.name.lexeme: a.argumentExpression,
    };

List<Expression> _positional(ArgumentList args) => <Expression>[
      for (final Argument a in args.arguments)
        if (a is! NamedArgument) a.argumentExpression,
    ];

String _string(_SpecFile f, Expression e) =>
    e is StringLiteral && e.stringValue != null ? e.stringValue! : f.fail(e, 'expected a string literal');

/// The doc comment of [n] as plain lines (without `/// `), or null.
String? _doc(_SpecFile f, AnnotatedNode n) {
  final Comment? c = n.documentationComment;
  if (c == null) {
    return null;
  }
  return <String>[
    for (final Token t in c.tokens) t.lexeme.replaceFirst(RegExp(r'^///\s?'), ''),
  ].join('\n');
}

/// The last identifier of a name expression: `Foo.bar`, `.bar`, `bar`.
String _lastName(_SpecFile f, Expression e) => switch (e) {
      SimpleIdentifier(:final String name) => name,
      PrefixedIdentifier(:final SimpleIdentifier identifier) => identifier.name,
      PropertyAccess(:final SimpleIdentifier propertyName) => propertyName.name,
      DotShorthandPropertyAccess(:final SimpleIdentifier propertyName) => propertyName.name,
      _ => f.fail(e, 'expected a name'),
    };

/// (constructor or method name, arguments) of a constructor call written
/// in full or as a dot shorthand.
(String, ArgumentList) _call(_SpecFile f, Expression e) => switch (e) {
      InstanceCreationExpression(:final ConstructorName constructorName, :final ArgumentList argumentList) => (
          constructorName.name?.name ?? '',
          argumentList
        ),
      DotShorthandConstructorInvocation(:final SimpleIdentifier constructorName, :final ArgumentList argumentList) => (
          constructorName.name,
          argumentList
        ),
      DotShorthandInvocation(:final SimpleIdentifier memberName, :final ArgumentList argumentList) => (
          memberName.name,
          argumentList
        ),
      MethodInvocation(:final SimpleIdentifier methodName, :final ArgumentList argumentList) => (
          methodName.name,
          argumentList
        ),
      _ => f.fail(e, 'expected a constructor call'),
    };

/// The spec class of a static: its declared type name and first type
/// argument (as written, and resolved).
({String cls, String? typeArg, DartType? typeArgType, ArgumentList args}) _static(_SpecFile f, Expression init) {
  if (init is! InstanceCreationExpression) {
    f.fail(init, 'expected a spec constructor call');
  }
  final NamedType t = init.constructorName.type;
  final TypeAnnotation? arg = t.typeArguments?.arguments.firstOrNull;
  final DartType? st = init.staticType;
  return (
    cls: t.name.lexeme,
    typeArg: arg == null ? null : f.text(arg),
    typeArgType: st is InterfaceType && st.typeArguments.isNotEmpty ? st.typeArguments.first : null,
    args: init.argumentList,
  );
}

List<String> _enumValues(_SpecFile f, AstNode at, DartType? t) {
  final Element? e = t?.element;
  if (e is! EnumElement) {
    f.fail(at, 'expected an enum type, got $t');
  }
  return <String>[for (final FieldElement c in e.constants) c.name!];
}

Iterable<(FieldDeclaration, VariableDeclaration)> _statics(ClassDeclaration c) sync* {
  for (final ClassMember m in c.body.members) {
    if (m is FieldDeclaration && m.isStatic) {
      for (final VariableDeclaration v in m.fields.variables) {
        yield (m, v);
      }
    }
  }
}

LibraryModel _readLibrary(_SpecFile f, ClassDeclaration c) {
  final Map<String, Expression> a = _named(_annotation(c, 'StyleLibrary')!.arguments!);
  String s(String name) => _string(f, a[name] ?? f.fail(c, 'missing $name'));
  final List<EnvDimModel> env = <EnvDimModel>[];
  final List<TokenModel> tokens = <TokenModel>[];
  for (final (FieldDeclaration d, VariableDeclaration v) in _statics(c)) {
    final Expression init = v.initializer ?? f.fail(v, 'no initializer');
    final st = _static(f, init);
    switch (st.cls) {
      case 'EnvDim':
        final String type = st.typeArg ?? f.fail(init, 'EnvDim needs a type argument');
        env.add(EnvDimModel(
          name: v.name.lexeme,
          type: type,
          values: type == 'bool' ? const <String>[] : _enumValues(f, init, st.typeArgType),
          read: _lastName(f, _named(st.args)['read'] ?? f.fail(init, 'EnvDim needs read:')),
        ));
      case 'Token':
        tokens.add(TokenModel(
          name: v.name.lexeme,
          type: st.typeArg ?? f.fail(init, 'Token needs a type argument'),
          doc: _doc(f, d),
        ));
      default:
        f.fail(init, 'a library spec holds EnvDim and Token statics');
    }
  }
  return LibraryModel(
    name: s('name'),
    specPath: f.path,
    target: s('target'),
    tokenInterface: s('tokenInterface'),
    tokenEnum: s('tokenEnum'),
    tokenRule: s('tokenRule'),
    facadeOutput: s('facadeOutput'),
    facadePartOf: s('facadePartOf'),
    environmentOutput: s('environmentOutput'),
    environmentPartOf: s('environmentPartOf'),
    engineOutput: s('engineOutput'),
    env: env,
    tokens: tokens,
    copied: f.privateDeclarations,
  );
}

const Map<String, (FieldKind, String)> _fieldClasses = <String, (FieldKind, String)>{
  'ColorField': (FieldKind.color, 'Color'),
  'TextStyleField': (FieldKind.textStyle, 'TextStyle'),
  'IconThemeField': (FieldKind.iconTheme, 'IconThemeData'),
  'BorderSideField': (FieldKind.borderSide, 'BorderSide'),
};

ComponentModel _readComponent(_SpecFile f, ClassDeclaration c, LibraryModel library) {
  final Map<String, Expression> a = _named(_annotation(c, 'Component')!.arguments!);
  String s(String name) => _string(f, a[name] ?? f.fail(c, 'missing $name'));
  final List<DimModel> dims = <DimModel>[];
  final List<FieldModel> fields = <FieldModel>[];
  Expression? impossible;
  Expression? defaults;
  for (final (FieldDeclaration d, VariableDeclaration v) in _statics(c)) {
    final String name = v.name.lexeme;
    final Expression init = v.initializer ?? f.fail(v, 'no initializer');
    if (name == 'impossible') {
      impossible = init;
      continue;
    }
    if (name == 'defaults') {
      defaults = init;
      continue;
    }
    final st = _static(f, init);
    DimRole role() => DimRole.values.byName(_lastName(f, _named(st.args)['role'] ?? f.fail(init, 'role: missing')));
    switch (st.cls) {
      case 'BoolDim':
        dims.add(DimModel(name: name, type: 'bool', values: const <String>[], role: role(), doc: _doc(f, d)));
      case 'EnumDim':
        dims.add(DimModel(
          name: name,
          type: st.typeArg ?? f.fail(init, 'EnumDim needs a type argument'),
          values: _enumValues(f, init, st.typeArgType),
          role: role(),
          doc: _doc(f, d),
        ));
      case 'Field':
        fields.add(FieldModel(
            name: name,
            type: st.typeArg ?? f.fail(init, 'Field needs a type argument'),
            kind: FieldKind.plain,
            doc: _doc(f, d)));
      default:
        final (FieldKind, String)? k = _fieldClasses[st.cls];
        if (k == null) {
          f.fail(init, 'unknown spec static ${st.cls}');
        }
        fields.add(FieldModel(name: name, type: k.$2, kind: k.$1, doc: _doc(f, d)));
    }
  }
  final Set<String> fieldNames = <String>{for (final FieldModel x in fields) x.name};
  final Set<String> dimNames = <String>{for (final DimModel x in dims) x.name};
  final Set<String> tokenNames = <String>{for (final TokenModel t in library.tokens) t.name};

  (String, Object) cond(Expression e) {
    if (e is! MethodInvocation || e.target is! SimpleIdentifier) {
      f.fail(e, 'expected dim.eq(...) or dim.oneOf({...})');
    }
    final String dim = (e.target! as SimpleIdentifier).name;
    if (!dimNames.contains(dim)) {
      f.fail(e, 'unknown dimension $dim');
    }
    final Expression arg = _positional(e.argumentList).single;
    return switch (e.methodName.name) {
      'eq' => (dim, arg is BooleanLiteral ? arg.value : f.fail(arg, 'expected true or false')),
      'oneOf' => (
          dim,
          arg is SetOrMapLiteral
              ? <String>{for (final CollectionElement x in arg.elements) _lastName(f, x as Expression)}
              : f.fail(arg, 'expected a set literal'),
        ),
      _ => f.fail(e, 'expected eq or oneOf'),
    };
  }

  Map<String, Object> conds(Expression list) {
    if (list is! ListLiteral) {
      f.fail(list, 'expected a list of conditions');
    }
    final Map<String, Object> out = <String, Object>{};
    for (final CollectionElement x in list.elements) {
      final (String d, Object v) = cond(x as Expression);
      if (out.containsKey(d)) {
        f.fail(x, 'dimension $d twice');
      }
      out[d] = v;
    }
    return out;
  }

  SourceModel source(Expression e) {
    final (String name, ArgumentList args) = _call(f, e);
    final List<Expression> pos = _positional(args);
    switch (name) {
      case 'value':
        return SourceModel(SourceKind.value, text: f.text(pos.single));
      case 'fromField':
        final String field = _lastName(f, pos.single);
        if (!fieldNames.contains(field)) {
          f.fail(e, 'unknown field $field');
        }
        return SourceModel(SourceKind.field, text: field);
      case 'fromToken':
        final String token = _lastName(f, pos.single);
        if (!tokenNames.contains(token)) {
          f.fail(e, 'not a token of ${library.name}: $token');
        }
        return SourceModel(SourceKind.token, text: token);
      case 'computed':
        return SourceModel(SourceKind.computed, text: f.text(pos.single));
      case 'opacity':
        return SourceModel(SourceKind.opacity, inner: source(pos[0]), text: f.text(pos[1]));
      case 'opaque':
        return SourceModel(SourceKind.opaque, inner: source(pos.single));
      default:
        f.fail(e, 'unknown source $name');
    }
  }

  EntryModel entry(Expression e) {
    if (e is! MethodInvocation || e.target is! SimpleIdentifier) {
      f.fail(e, 'expected field.value(...), field.from(...) or field.parts(...)');
    }
    final String field = (e.target! as SimpleIdentifier).name;
    if (!fieldNames.contains(field)) {
      f.fail(e, 'unknown field $field');
    }
    return switch (e.methodName.name) {
      'value' => EntryModel.value(field, f.text(_positional(e.argumentList).single)),
      'from' => EntryModel.source(field, source(_positional(e.argumentList).single)),
      'parts' => EntryModel.parts(field, <String, SourceModel>{
          for (final MapEntry<String, Expression> x in _named(e.argumentList).entries) x.key: source(x.value),
        }),
      _ => f.fail(e, 'expected value, from or parts'),
    };
  }

  final List<RuleModel> rules = <RuleModel>[];
  if (defaults is! ListLiteral) {
    f.fail(defaults ?? c, 'expected `static final defaults = <Rule>[...]`');
  }
  for (final CollectionElement x in defaults.elements) {
    final (String kind, ArgumentList args) = _call(f, x as Expression);
    final List<Expression> pos = _positional(args);
    final Map<String, Expression> named = _named(args);
    final String? label = named['label'] == null ? null : _string(f, named['label']!);
    final (Map<String, Object> condition, Expression entries) = switch (kind) {
      'always' => (<String, Object>{}, pos.single),
      'when' => (conds(pos[0]), pos[1]),
      _ => f.fail(x, 'expected Rule.always or Rule.when'),
    };
    if (entries is! ListLiteral) {
      f.fail(entries, 'expected a list of entries');
    }
    rules.add(RuleModel(
      label: label,
      when: condition,
      entries: <EntryModel>[for (final CollectionElement e in entries.elements) entry(e as Expression)],
    ));
  }

  return ComponentModel(
    name: s('name'),
    specPath: f.path,
    output: s('output'),
    partOf: s('partOf'),
    description: a['description'] == null ? s('name').toLowerCase() : s('description'),
    dims: dims,
    fields: fields,
    impossible: impossible == null
        ? const <Map<String, Object>>[]
        : <Map<String, Object>>[
            for (final CollectionElement x in (impossible as ListLiteral).elements) conds(x as Expression),
          ],
    defaults: rules,
    emitted: f.emitted,
    copied: f.privateDeclarations,
  );
}
