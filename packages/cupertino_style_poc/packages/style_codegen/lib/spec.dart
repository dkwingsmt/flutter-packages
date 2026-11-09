// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The spec language of the style generator.
///
/// A spec is a Dart file under `specs/<library>/` that describes one
/// design-language library (its environment dimensions and built-in
/// tokens) or one component (its dimensions, fields and library default
/// rules). Specs are resolved by the analyzer and never run: the classes
/// here only give them types, so a value of the wrong type, a transform on a
/// non-Color field or a token of the wrong type is a compile error in the
/// spec. The generator reads the source and copies value expressions
/// verbatim into the generated code, so they must also be valid there
/// (public names of the packages the target library imports, or private
/// top-level declarations of the spec file, which are copied along).
///
/// Shape of a component spec:
///
/// ```dart
/// @Component(name: 'Button', output: 'lib/src/button.g.dart', partOf: 'button.dart')
/// abstract final class ButtonSpec {
///   static const disabled = BoolDim(role: .disabled);
///   static const appearance = EnumDim<ButtonAppearance>(role: .variant);
///
///   /// The painted background.
///   static const backgroundColor = ColorField();
///
///   static final impossible = [[disabled.eq(true), pressed.eq(true)]];
///
///   static final defaults = <Rule>[
///     Rule.when([appearance.oneOf({.filled}), disabled.eq(false)], label: 'rest', [
///       backgroundColor.from(.opaque(.fromToken(Cupertino.primaryColor))),
///     ]),
///   ];
/// }
/// ```
library;

import 'package:flutter/painting.dart' show BorderSide, Color, TextStyle;
import 'package:flutter/widgets.dart' show IconThemeData;

/// Marks a declaration of a spec file that is copied verbatim (doc comment
/// included, this annotation removed) into the generated file, e.g. an
/// enum that is a dimension of the component.
const Object emit = _Emit();

final class _Emit {
  const _Emit();
}

// ---------------------------------------------------------------------------
// Library spec.

/// Annotates the class of a library spec: environment dimensions
/// ([EnvDim] statics) and built-in tokens ([Token] statics).
final class StyleLibrary {
  const StyleLibrary({
    required this.name,
    required this.target,
    required this.tokenInterface,
    required this.tokenEnum,
    required this.tokenRule,
    required this.facadeOutput,
    required this.facadePartOf,
    required this.environmentOutput,
    required this.environmentPartOf,
    required this.engineOutput,
  });

  /// The design language, e.g. `Cupertino`.
  final String name;

  /// The target package, relative to the generator package root.
  final String target;

  /// The public token interface (`CupertinoToken`).
  final String tokenInterface;

  /// The private enum behind it (`_CupertinoTokens`), generated into the
  /// facade part.
  final String tokenEnum;

  /// The generated token rule class (`CupertinoTokenRule`). Its
  /// `.derive(...)` constructor takes the hand-written token-layer source
  /// classes `<tokenInterface>Source<T>` / `<tokenInterface>ColorSource`
  /// of the facade's parent library.
  final String tokenRule;

  /// The token facade file and the library it is a part of (relative to
  /// the facade file).
  final String facadeOutput;
  final String facadePartOf;

  /// The environment file (`EnvDims`, `TokenWhen`, `StyleEnvironment`,
  /// `ResolvedEnvironment`) and its parent library.
  final String environmentOutput;
  final String environmentPartOf;

  /// Where the engine is copied (a directory of the target package).
  final String engineOutput;
}

/// An environment dimension of the library. [read] is a function
/// `(BuildContext context) => T` that reads the value from the context
/// when no `StyleTheme` / `StyleScope` sets it.
final class EnvDim<T extends Object> {
  const EnvDim({required this.read});

  /// A bool dimension (tri-state in conditions).
  const EnvDim.bool({required this.read});

  final Function read;
}

/// A built-in token of value type [T].
final class Token<T extends Object> {
  const Token();
}

// ---------------------------------------------------------------------------
// Component spec.

/// Annotates the class of a component spec.
final class Component {
  const Component({required this.name, required this.output, required this.partOf, this.description});

  /// The component (`Button`): the generated classes are `ButtonStyle`,
  /// `ButtonRule`, `ButtonWhen`, ...
  final String name;

  /// The generated file, relative to the target package root.
  final String output;

  /// The hand-written library the generated file is a part of (relative
  /// to the output file).
  final String partOf;

  /// What the component is, for generated doc comments (`button`).
  final String? description;
}

/// How a state dimension takes part in region names (see the generator's
/// naming rules): [disabled] and [interaction] dims make the base word,
/// [semantic] dims the suffix, [variant] dims the prefix.
enum DimRole { disabled, interaction, semantic, variant }

/// A condition literal: one dimension and its allowed values.
final class Cond {
  const Cond._();
}

/// A bool dimension of the component.
final class BoolDim {
  const BoolDim({required this.role});

  final DimRole role;

  /// The dimension is [value].
  Cond eq(bool value) => const Cond._();
}

/// An enum dimension of the component; its values are [E]'s values.
final class EnumDim<E extends Enum> {
  const EnumDim({required this.role});

  final DimRole role;

  /// The dimension is one of [values].
  Cond oneOf(Set<E> values) => const Cond._();
}

/// One field set by a rule.
final class Entry {
  const Entry._();
}

/// A field of value type [T].
base class Field<T extends Object> {
  const Field();

  /// A literal value.
  Entry value(T value) => const Entry._();

  /// A derived value (a field, a token, a callback, ...).
  Entry from(covariant Src<T> source) => const Entry._();
}

/// A Color field: its sources may use `.opacity` / `.opaque`.
final class ColorField extends Field<Color> {
  const ColorField();

  @override
  Entry from(ColorSrc source) => const Entry._();
}

/// A TextStyle field (merged per property across rules).
final class TextStyleField extends Field<TextStyle> {
  const TextStyleField();

  /// Only the given sub-properties.
  Entry parts({ColorSrc? color, ColorSrc? decorationColor}) => const Entry._();
}

/// An IconThemeData field (merged per property across rules).
final class IconThemeField extends Field<IconThemeData> {
  const IconThemeField();

  /// Only the given sub-properties.
  Entry parts({ColorSrc? color}) => const Entry._();
}

/// A BorderSide field (a whole value replaces the earlier one).
final class BorderSideField extends Field<BorderSide> {
  const BorderSideField();

  /// Only the given sub-properties of the side the earlier rules produced.
  Entry parts({ColorSrc? color, Src<double>? width}) => const Entry._();
}

/// The source of a derived value of type [T].
base class Src<T extends Object> {
  /// A literal.
  const Src.value(T value);

  /// The final value of another field of the component, same state.
  const Src.fromField(Field<T> field);

  /// A built-in token of the library.
  const Src.fromToken(Token<T> token);

  /// A callback `T Function(XView s)`: a public top-level function of the
  /// target library, referenced by name (its type is checked when the
  /// generated code compiles).
  const Src.computed(Function function);
}

/// A Color source, with the alpha transforms.
final class ColorSrc extends Src<Color> {
  const ColorSrc.value(super.value) : super.value();
  const ColorSrc.fromField(super.field) : super.fromField();
  const ColorSrc.fromToken(super.token) : super.fromToken();
  const ColorSrc.computed(super.function) : super.computed();

  /// The source's alpha multiplied by [opacity].
  const ColorSrc.opacity(ColorSrc source, double opacity) : super.value(const Color(0x00000000));

  /// The source with alpha 1.
  const ColorSrc.opaque(ColorSrc source) : super.value(const Color(0x00000000));
}

/// A library default rule: a condition (a list of [Cond], all must hold),
/// a label (the region identity: rules with the same label form one
/// region of a field) and the fields it sets.
final class Rule {
  /// Every state.
  const Rule.always(List<Entry> set, {String? label});

  /// The states that match every condition in [when].
  const Rule.when(List<Cond> when, List<Entry> set, {String? label});
}
