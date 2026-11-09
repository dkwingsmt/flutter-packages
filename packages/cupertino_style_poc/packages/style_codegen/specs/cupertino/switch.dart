// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The Switch spec: dimensions, fields and the library defaults (the
// original CupertinoSwitch's values).
library;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:style_codegen/spec.dart';

import 'cupertino.dart';

const CupertinoDynamicColor _kOffLabelColor = CupertinoDynamicColor.withBrightnessAndContrast(
  debugLabel: 'offSwitchLabel',
  color: Color.fromARGB(255, 179, 179, 179),
  darkColor: Color.fromARGB(255, 179, 179, 179),
  highContrastColor: Color.fromARGB(255, 255, 255, 255),
  darkHighContrastColor: Color.fromARGB(255, 255, 255, 255),
);

@Component(name: 'Switch', output: 'lib/src/switch.g.dart', partOf: 'switch.dart', description: 'switch')
abstract final class SwitchSpec {
  // ---- Dimensions ----

  static const disabled = BoolDim(role: .disabled);

  /// The switch value.
  static const selected = BoolDim(role: .semantic);
  static const pressed = BoolDim(role: .interaction);
  static const focused = BoolDim(role: .interaction);
  static const hovered = BoolDim(role: .interaction);

  static final impossible = [
    [disabled.eq(true), pressed.eq(true)],
    [disabled.eq(true), focused.eq(true)],
    [disabled.eq(true), hovered.eq(true)],
  ];

  // ---- Fields ----

  static const trackColor = ColorField();

  /// Painted over [thumbBackdropColor] (alpha blend), as before.
  static const thumbColor = ColorField();
  static const trackOutlineColor = ColorField();
  static const trackOutlineWidth = Field<double>();
  static const focusColor = ColorField();
  static const onLabelColor = ColorField();
  static const offLabelColor = ColorField();
  static const thumbImage = Field<ImageProvider>();
  static const thumbIcon = Field<IconData>();
  static const thumbIconColor = ColorField();
  static const thumbIconSize = Field<double>();
  static const mouseCursor = Field<MouseCursor>();

  /// Opacity of the whole switch (0.5 when disabled).
  static const opacity = Field<double>();

  /// What a translucent thumb is blended against (scaffold background).
  static const thumbBackdropColor = ColorField();

  // ---- Library defaults ----

  static final defaults = <Rule>[
    Rule.when([selected.eq(false)], label: 'rest', [
      trackColor.value(CupertinoColors.secondarySystemFill),
      thumbColor.value(CupertinoColors.white),
    ]),
    Rule.when([selected.eq(true)], label: 'selected', [
      trackColor.value(CupertinoColors.systemGreen),
      thumbColor.value(CupertinoColors.white),
    ]),
    Rule.always(label: 'rest', [
      trackOutlineWidth.value(2.0),
      onLabelColor.value(CupertinoColors.white),
      offLabelColor.value(_kOffLabelColor),
      thumbIconColor.value(CupertinoColors.black),
      thumbIconSize.value(16.0),
      opacity.value(1.0),
      thumbBackdropColor.from(.fromToken(Cupertino.scaffoldBackgroundColor)),
    ]),
    Rule.when([disabled.eq(false)], label: 'rest', [
      mouseCursor.value(kIsWeb ? SystemMouseCursors.click : MouseCursor.defer),
    ]),
    Rule.when([disabled.eq(true)], label: 'disabled', [
      mouseCursor.value(MouseCursor.defer),
      opacity.value(0.5),
    ]),
  ];
}
