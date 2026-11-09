// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// GENERATED FILE. Do not edit: change the spec and run the generator.
//   spec:      style_codegen/specs/cupertino/cupertino.dart
//   generator: packages/style_codegen (dart run style_codegen:generate)
part of 'style_library.dart';

// ---- Environment readers of the spec (copied) -----------------------------

Brightness _readBrightness(BuildContext context) => CupertinoTheme.brightnessOf(context);

bool _readHighContrast(BuildContext context) => MediaQuery.highContrastOf(context);

CupertinoUserInterfaceLevelData _readInterfaceLevel(BuildContext context) =>
    CupertinoUserInterfaceLevel.maybeOf(context) ?? CupertinoUserInterfaceLevelData.base;

// ---- Environment dimensions -----------------------------------------------

/// Environment dimensions of the Cupertino library. Every component carries
/// all of them, and so does the global token channel.
abstract final class EnvDims {
  static const Dimension<Brightness> brightness =
      Dimension<Brightness>('brightness', Brightness.values, environment: true);
  static const BoolDimension highContrast = BoolDimension('highContrast', environment: true);
  static const Dimension<CupertinoUserInterfaceLevelData> interfaceLevel =
      Dimension<CupertinoUserInterfaceLevelData>('interfaceLevel', CupertinoUserInterfaceLevelData.values, environment: true);

  static const List<Dimension<Object>> all = <Dimension<Object>>[brightness, highContrast, interfaceLevel];
}

/// Condition of a [TokenRule]: environment dimensions only.
@immutable
final class TokenWhen {
  const TokenWhen({this.brightness, this.highContrast, this.interfaceLevel});

  final Brightness? brightness;
  final bool? highContrast;
  final CupertinoUserInterfaceLevelData? interfaceLevel;

  Condition toCondition() => Condition(<Dimension<Object>, Object>{
        if (brightness case final Brightness v) EnvDims.brightness: <Object>{v},
        EnvDims.highContrast: ?highContrast,
        if (interfaceLevel case final CupertinoUserInterfaceLevelData v) EnvDims.interfaceLevel: <Object>{v},
      });

  @override
  bool operator ==(Object other) =>
      other is TokenWhen &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.interfaceLevel == interfaceLevel;

  @override
  int get hashCode => Object.hash(brightness, highContrast, interfaceLevel);
}

/// An explicit environment set by [StyleTheme] / [StyleScope]. A null
/// field is read from the context at the component (the reader functions
/// of the library spec).
@immutable
final class StyleEnvironment {
  const StyleEnvironment({this.brightness, this.highContrast, this.interfaceLevel});

  static const StyleEnvironment none = StyleEnvironment();

  final Brightness? brightness;
  final bool? highContrast;
  final CupertinoUserInterfaceLevelData? interfaceLevel;

  /// [inner]'s set fields over this one's.
  StyleEnvironment merge(StyleEnvironment? inner) => inner == null
      ? this
      : StyleEnvironment(
          brightness: inner.brightness ?? brightness,
          highContrast: inner.highContrast ?? highContrast,
          interfaceLevel: inner.interfaceLevel ?? interfaceLevel,
        );

  /// Every field set: explicit ones, the rest from [context]. Reading the
  /// context registers the usual dependencies, so context changes rebuild
  /// as today.
  ResolvedEnvironment resolve(BuildContext context) => ResolvedEnvironment(
        brightness: brightness ?? _readBrightness(context),
        highContrast: highContrast ?? _readHighContrast(context),
        interfaceLevel: interfaceLevel ?? _readInterfaceLevel(context),
      );

  @override
  bool operator ==(Object other) =>
      other is StyleEnvironment &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.interfaceLevel == interfaceLevel;

  @override
  int get hashCode => Object.hash(brightness, highContrast, interfaceLevel);
}

/// A fully determined environment (the environment part of a minterm).
@immutable
final class ResolvedEnvironment {
  const ResolvedEnvironment({required this.brightness, required this.highContrast, required this.interfaceLevel});

  final Brightness brightness;
  final bool highContrast;
  final CupertinoUserInterfaceLevelData interfaceLevel;

  /// The values in [EnvDims.all] order.
  List<Object> get values => <Object>[brightness, highContrast, interfaceLevel];

  @override
  String toString() => '(${brightness.name}, highContrast: $highContrast, ${interfaceLevel.name})';
}
