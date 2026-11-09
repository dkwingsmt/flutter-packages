// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// What the generator reads from the specs: plain data, no analyzer types.
library;

/// One design-language library: environment, tokens, components.
final class LibraryModel {
  LibraryModel({
    required this.name,
    required this.specPath,
    required this.target,
    required this.tokenInterface,
    required this.tokenEnum,
    required this.tokenRule,
    required this.facadeOutput,
    required this.facadePartOf,
    required this.environmentOutput,
    required this.environmentPartOf,
    required this.engineOutput,
    required this.env,
    required this.tokens,
    required this.copied,
  });

  final String name;
  final String specPath;
  final String target;
  final String tokenInterface;
  final String tokenEnum;
  final String tokenRule;

  /// The hand-written token-layer source classes the generated
  /// `tokenRule.derive(...)` takes (`CupertinoTokenSource<T>`,
  /// `CupertinoTokenColorSource`).
  String get tokenSource => '${tokenInterface}Source';
  String get tokenColorSource => '${tokenInterface}ColorSource';
  final String facadeOutput;
  final String facadePartOf;
  final String environmentOutput;
  final String environmentPartOf;
  final String engineOutput;
  final List<EnvDimModel> env;
  final List<TokenModel> tokens;

  /// Private top-level declarations of the spec file, by name (source).
  final Map<String, String> copied;

  final List<ComponentModel> components = <ComponentModel>[];

  TokenModel? token(String name) => tokens.where((TokenModel t) => t.name == name).firstOrNull;
}

/// An environment dimension.
final class EnvDimModel {
  EnvDimModel({required this.name, required this.type, required this.values, required this.read});

  final String name;

  /// The value type as written (`Brightness`, `bool`).
  final String type;

  /// Enum constant names; empty for a bool dimension.
  final List<String> values;

  /// The reader function's name (a private top-level function of the
  /// library spec, copied into the environment file).
  final String read;

  bool get isBool => type == 'bool';

  /// A two-valued enum: a scalar `T?` in conditions (design doc 4, step 2:
  /// binary dimensions are scalars; `brightness: .dark`).
  bool get isScalar => !isBool && values.length == 2;
}

/// A built-in token.
final class TokenModel {
  TokenModel({required this.name, required this.type, required this.doc});

  final String name;
  final String type;
  final String? doc;
}

enum DimRole { disabled, interaction, semantic, variant }

/// A state dimension of a component.
final class DimModel {
  DimModel({required this.name, required this.type, required this.values, required this.role, required this.doc});

  final String name;

  /// The enum type as written (`ButtonAppearance`), or `bool`.
  final String type;

  /// Enum constant names in declaration order; empty for a bool dimension.
  final List<String> values;
  final DimRole role;
  final String? doc;

  bool get isBool => type == 'bool';

  /// A two-valued enum: a scalar `T?` in conditions (design doc 4, step 2).
  bool get isScalar => !isBool && values.length == 2;

  /// The values of the dimension's domain, as region math sees them.
  List<Object> get domain => isBool ? const <Object>[false, true] : values;
}

/// How a field's value type takes part in rules.
enum FieldKind { plain, color, textStyle, iconTheme, borderSide }

/// A field of a component.
final class FieldModel {
  FieldModel({required this.name, required this.type, required this.kind, required this.doc});

  final String name;

  /// The value type as written.
  final String type;
  final FieldKind kind;
  final String? doc;

  bool get isComposite => kind == FieldKind.textStyle || kind == FieldKind.iconTheme || kind == FieldKind.borderSide;
}

/// A component.
final class ComponentModel {
  ComponentModel({
    required this.name,
    required this.specPath,
    required this.output,
    required this.partOf,
    required this.description,
    required this.dims,
    required this.fields,
    required this.impossible,
    required this.defaults,
    required this.emitted,
    required this.copied,
  });

  final String name;
  final String specPath;
  final String output;
  final String partOf;
  final String description;
  final List<DimModel> dims;
  final List<FieldModel> fields;

  /// Impossible combinations: dimension name -> value.
  final List<Map<String, Object>> impossible;
  final List<RuleModel> defaults;

  /// Declarations marked `@emit`, as source (doc comments included).
  final List<String> emitted;

  /// Private top-level declarations of the spec file, by name.
  final Map<String, String> copied;

  DimModel dim(String name) => dims.firstWhere((DimModel d) => d.name == name);
  FieldModel field(String name) => fields.firstWhere((FieldModel f) => f.name == name);
}

/// A library default rule.
final class RuleModel {
  RuleModel({required this.label, required this.when, required this.entries});

  final String? label;

  /// Dimension name -> bool, or the set of enum constant names allowed.
  /// Empty: every state.
  final Map<String, Object> when;
  final List<EntryModel> entries;
}

/// One field set by a rule.
final class EntryModel {
  EntryModel.value(this.field, String this.expression)
      : source = null,
        parts = null;
  EntryModel.source(this.field, SourceModel this.source)
      : expression = null,
        parts = null;
  EntryModel.parts(this.field, Map<String, SourceModel> this.parts)
      : expression = null,
        source = null;

  final String field;

  /// A literal value (Dart source).
  final String? expression;

  /// A derived value.
  final SourceModel? source;

  /// Sub-properties of a composite (sub-property name -> source).
  final Map<String, SourceModel>? parts;

  bool get isValue => expression != null;
}

enum SourceKind { value, field, token, computed, opacity, opaque }

/// A derive source.
final class SourceModel {
  SourceModel(this.kind, {this.text, this.inner});

  final SourceKind kind;

  /// value / computed: the expression; field / token: the name;
  /// opacity: the factor expression.
  final String? text;

  /// opacity / opaque: the wrapped source.
  final SourceModel? inner;

  /// The private identifiers it references (for copying helpers).
  Iterable<String> get expressions sync* {
    if (kind == SourceKind.value || kind == SourceKind.computed || kind == SourceKind.opacity) {
      yield text!;
    }
    if (inner != null) {
      yield* inner!.expressions;
    }
  }
}
