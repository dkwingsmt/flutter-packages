// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// SHOULD BE GENERATED (by a facade generator for private token enums);
// hand-written in this sample.
// Public facade of the private token enum `_CupertinoTokens`.
part of 'cupertino_adapter.dart';

/// Public facade of the built-in Cupertino tokens: one static const per
/// token, plus [values]. A switch over [CupertinoTokens] is not exhaustive,
/// so adding a token is not a breaking change.
abstract final class CupertinoTokens<T extends Object> implements Enum, GroupToken<CupertinoThemeData, T> {
  static const List<CupertinoTokens<Object>> values = _CupertinoTokens.values;

  static const primaryColor = _CupertinoTokens.primaryColor;
  static const primaryContrastingColor = _CupertinoTokens.primaryContrastingColor;
  static const barBackgroundColor = _CupertinoTokens.barBackgroundColor;
  static const scaffoldBackgroundColor = _CupertinoTokens.scaffoldBackgroundColor;
  static const textStyle = _CupertinoTokens.textStyle;
  static const actionTextStyle = _CupertinoTokens.actionTextStyle;
  static const actionSmallTextStyle = _CupertinoTokens.actionSmallTextStyle;
}
