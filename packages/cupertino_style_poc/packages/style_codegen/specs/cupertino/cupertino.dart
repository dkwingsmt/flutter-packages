// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The Cupertino library spec: environment dimensions and built-in tokens.
library;

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoTheme, CupertinoUserInterfaceLevel, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:style_codegen/spec.dart';

Brightness _readBrightness(BuildContext context) => CupertinoTheme.brightnessOf(context);

bool _readHighContrast(BuildContext context) => MediaQuery.highContrastOf(context);

CupertinoUserInterfaceLevelData _readInterfaceLevel(BuildContext context) =>
    CupertinoUserInterfaceLevel.maybeOf(context) ?? CupertinoUserInterfaceLevelData.base;

@StyleLibrary(
  name: 'Cupertino',
  target: '../cupertino_style_poc',
  tokenInterface: 'CupertinoToken',
  tokenEnum: '_CupertinoTokens',
  tokenRule: 'CupertinoTokenRule',
  facadeOutput: 'lib/src/cupertino_adapter.facade.g.dart',
  facadePartOf: 'cupertino_adapter.dart',
  environmentOutput: 'lib/src/style_library.g.dart',
  environmentPartOf: 'style_library.dart',
  engineOutput: 'lib/src/engine',
)
abstract final class Cupertino {
  // ---- Environment dimensions (every component and the token channel) ----

  static const brightness = EnvDim<Brightness>(read: _readBrightness);
  static const highContrast = EnvDim<bool>.bool(read: _readHighContrast);
  static const interfaceLevel = EnvDim<CupertinoUserInterfaceLevelData>(read: _readInterfaceLevel);

  // ---- Built-in tokens ----

  static const primaryColor = Token<Color>();
  static const primaryContrastingColor = Token<Color>();
  static const barBackgroundColor = Token<Color>();
  static const scaffoldBackgroundColor = Token<Color>();
  static const textStyle = Token<TextStyle>();
  static const actionTextStyle = Token<TextStyle>();
  static const actionSmallTextStyle = Token<TextStyle>();

  /// The fill of a tinted button: [primaryColor] at opacity 0.12 in light
  /// mode and 0.26 in dark mode. A derived token (CupertinoThemeData has no
  /// such field): set by two brightness-conditioned token rules in the
  /// library defaults ([cupertinoDefaultTokenRules]), so a component
  /// default can reference it as one rule without environment conditions.
  /// A theme can override it like any token.
  static const tintedFill = Token<Color>();
}
