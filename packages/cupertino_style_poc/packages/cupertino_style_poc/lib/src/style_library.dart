// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The Cupertino side of the engine contract. The engine (lib/src/engine/,
/// copied from packages/style_codegen/engine) imports this library and
/// expects:
///
/// * the environment: [EnvDims], [TokenWhen], [StyleEnvironment] and
///   [ResolvedEnvironment] (generated from the library spec into
///   style_library.g.dart);
/// * [styleEnvSplitter]: how environment-dependent values
///   (CupertinoDynamicColor) are expanded into environment-conditioned
///   rules;
/// * [buildTokens]: the global token channel with the library's built-in
///   group and defaults.
library;

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoTheme, CupertinoUserInterfaceLevel, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';

import 'cupertino_adapter.dart';
import 'engine/engine.dart';

export 'cupertino_adapter.dart' show buildTokens;

part 'style_library.g.dart';

/// The splitter every chain of this library is expanded with.
const EnvSplitter styleEnvSplitter = cupertinoEnvSplitter;
