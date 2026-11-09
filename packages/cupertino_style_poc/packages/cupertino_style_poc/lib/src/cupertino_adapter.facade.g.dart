// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// GENERATED FILE. Do not edit: change the spec and run the generator.
//   spec:      style_codegen/specs/cupertino/cupertino.dart
//   generator: packages/style_codegen (dart run style_codegen:generate)
part of 'cupertino_adapter.dart';

// The token rule's fields are private; a named parameter can't be.
// ignore_for_file: prefer_initializing_formals

/// The built-in Cupertino tokens: one static const per token, plus
/// [values]. The tokens are values of a private enum behind this
/// library-owned interface, so adding a token is not a breaking change (a
/// switch over [CupertinoToken] is not exhaustive).
///
/// The statics live on the interface because a dot shorthand looks for
/// static members of the parameter's own type: `XSource.fromToken` takes a
/// `CupertinoToken<T>`, so `.fromToken(.primaryColor)` finds [primaryColor]
/// here, and the type argument checks the token's value type against the
/// slot's.
///
/// App tokens don't implement this interface; they implement the engine's
/// [Token] (through [GroupTokenMixin]) and are passed to
/// `.fromCustomToken(...)`.
abstract interface class CupertinoToken<T extends Object> implements Token<T> {
  static const List<CupertinoToken<Object>> values = _CupertinoTokens.values;

  static const CupertinoToken<Color> primaryColor = _CupertinoTokens.primaryColor;
  static const CupertinoToken<Color> primaryContrastingColor = _CupertinoTokens.primaryContrastingColor;
  static const CupertinoToken<Color> barBackgroundColor = _CupertinoTokens.barBackgroundColor;
  static const CupertinoToken<Color> scaffoldBackgroundColor = _CupertinoTokens.scaffoldBackgroundColor;
  static const CupertinoToken<TextStyle> textStyle = _CupertinoTokens.textStyle;
  static const CupertinoToken<TextStyle> actionTextStyle = _CupertinoTokens.actionTextStyle;
  static const CupertinoToken<TextStyle> actionSmallTextStyle = _CupertinoTokens.actionSmallTextStyle;

  /// The fill of a tinted button: [primaryColor] at opacity 0.12 in light
  /// mode and 0.26 in dark mode. A derived token (CupertinoThemeData has no
  /// such field): set by two brightness-conditioned token rules in the
  /// library defaults ([cupertinoDefaultTokenRules]), so a component
  /// default can reference it as one rule without environment conditions.
  /// A theme can override it like any token.
  static const CupertinoToken<Color> tintedFill = _CupertinoTokens.tintedFill;

  /// The value of this token at the environment of [context] (non-null).
  T of(BuildContext context);
}

/// The tokens behind [CupertinoToken]. Library-private, so adding one is not a
/// breaking change. Every token uses the built-in theme-animation table
/// ([lerpTokenValue]).
enum _CupertinoTokens<T extends Object> with GroupTokenMixin<T> implements CupertinoToken<T> {
  primaryColor<Color>(),
  primaryContrastingColor<Color>(),
  barBackgroundColor<Color>(),
  scaffoldBackgroundColor<Color>(),
  textStyle<TextStyle>(),
  actionTextStyle<TextStyle>(),
  actionSmallTextStyle<TextStyle>(),
  tintedFill<Color>();

  const _CupertinoTokens({this.lerp});

  @override
  final T? Function(T? a, T? b, double t)? lerp;
}

/// The built-in Cupertino token group. Always part of the global channel
/// (not listed in `StyleTheme(groups: ...)`).
const TokenGroup cupertinoTokenGroup = TokenGroup('Cupertino', _CupertinoTokens.values);

/// Sets some Cupertino tokens: one optional parameter per token, and only
/// the tokens given are set, so `CupertinoTokenRule(primaryColor: x)` leaves tokens derived
/// from it deriving from the new value. Values may be
/// environment-dependent (expanded per environment).
///
/// The main constructor takes plain values; [CupertinoTokenRule.derive] takes sources
/// (`.value(x)`, `.fromToken(...)`, `.fromCustomToken(...)` and, for
/// colors, `.opacity(...)` / `.opaque(...)`). One token alone:
/// `CupertinoToken.x.set(value)` / `CupertinoToken.x.setFrom(source)`.
final class CupertinoTokenRule extends TokenSourceRule {
  const CupertinoTokenRule({
    Color? primaryColor,
    Color? primaryContrastingColor,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    TextStyle? textStyle,
    TextStyle? actionTextStyle,
    TextStyle? actionSmallTextStyle,
    Color? tintedFill,
    super.when,
  })  : _primaryColor = primaryColor,
        _primaryContrastingColor = primaryContrastingColor,
        _barBackgroundColor = barBackgroundColor,
        _scaffoldBackgroundColor = scaffoldBackgroundColor,
        _textStyle = textStyle,
        _actionTextStyle = actionTextStyle,
        _actionSmallTextStyle = actionSmallTextStyle,
        _tintedFill = tintedFill;

  /// Sources instead of plain values; literals are `.value(x)`.
  const CupertinoTokenRule.derive({
    CupertinoTokenColorSource? primaryColor,
    CupertinoTokenColorSource? primaryContrastingColor,
    CupertinoTokenColorSource? barBackgroundColor,
    CupertinoTokenColorSource? scaffoldBackgroundColor,
    CupertinoTokenSource<TextStyle>? textStyle,
    CupertinoTokenSource<TextStyle>? actionTextStyle,
    CupertinoTokenSource<TextStyle>? actionSmallTextStyle,
    CupertinoTokenColorSource? tintedFill,
    super.when,
  })  : _primaryColor = primaryColor,
        _primaryContrastingColor = primaryContrastingColor,
        _barBackgroundColor = barBackgroundColor,
        _scaffoldBackgroundColor = scaffoldBackgroundColor,
        _textStyle = textStyle,
        _actionTextStyle = actionTextStyle,
        _actionSmallTextStyle = actionSmallTextStyle,
        _tintedFill = tintedFill;

  // A plain value (main constructor) or a source (.derive).
  final Object? _primaryColor;
  final Object? _primaryContrastingColor;
  final Object? _barBackgroundColor;
  final Object? _scaffoldBackgroundColor;
  final Object? _textStyle;
  final Object? _actionTextStyle;
  final Object? _actionSmallTextStyle;
  final Object? _tintedFill;

  static DeriveSource? _source<T extends Object>(Object? v) => switch (v) {
        null => null,
        final DeriveSource s => s,
        _ => CupertinoTokenSource<T>.value(v as T),
      };

  @override
  Map<Token<Object>, DeriveSource> get sources => <Token<Object>, DeriveSource>{
        CupertinoToken.primaryColor: ?_source<Color>(_primaryColor),
        CupertinoToken.primaryContrastingColor: ?_source<Color>(_primaryContrastingColor),
        CupertinoToken.barBackgroundColor: ?_source<Color>(_barBackgroundColor),
        CupertinoToken.scaffoldBackgroundColor: ?_source<Color>(_scaffoldBackgroundColor),
        CupertinoToken.textStyle: ?_source<TextStyle>(_textStyle),
        CupertinoToken.actionTextStyle: ?_source<TextStyle>(_actionTextStyle),
        CupertinoToken.actionSmallTextStyle: ?_source<TextStyle>(_actionSmallTextStyle),
        CupertinoToken.tintedFill: ?_source<Color>(_tintedFill),
      };
}
