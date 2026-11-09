// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The Button spec: dimensions, fields and the library defaults. The
// defaults are the original CupertinoButton's (cupertino_ui constants.dart
// and button.dart build).
library;

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoButtonSize, CupertinoColors;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:style_codegen/spec.dart';

import '../../engine/padding_scaler.dart';
import 'cupertino.dart';

/// Alias for [CupertinoButtonSize] to match the unprefixed [Button] naming.
@emit
typedef ButtonSize = CupertinoButtonSize;

/// The background style of a [Button] (was the private
/// `_ButtonStyle`; now a dimension rules can name).
@emit
enum ButtonAppearance {
  /// No background, primary foreground.
  plain,

  /// Translucent primary background, primary foreground.
  tinted,

  /// Solid primary background, contrasting foreground.
  filled,
}

@Component(name: 'Button', output: 'lib/src/button.g.dart', partOf: 'button.dart', description: 'button')
abstract final class ButtonSpec {
  // ---- Dimensions ----

  static const disabled = BoolDim(role: .disabled);
  static const pressed = BoolDim(role: .interaction);
  static const focused = BoolDim(role: .interaction);
  static const appearance = EnumDim<ButtonAppearance>(role: .variant);
  static const sizeStyle = EnumDim<ButtonSize>(role: .variant);

  // FocusableActionDetector is disabled and the tap handlers are null
  // while disabled.
  static final impossible = [
    [disabled.eq(true), pressed.eq(true)],
    [disabled.eq(true), focused.eq(true)],
  ];

  // ---- Fields ----

  /// The painted background. Unset = no background.
  static const backgroundColor = ColorField();

  /// Text and icon color (followed by textStyle.color / iconTheme.color
  /// through the default derive).
  static const foregroundColor = ColorField();

  /// The focus ring. Unset = computed by the widget from the resolved
  /// background (or activeBlue), as in the original; the same computation
  /// is available as a callback (`defaultButtonFocusColor`).
  static const focusColor = ColorField();

  /// The padding at a text scale of 1; the widget lays out
  /// `paddingScaler.apply(padding, ...)`.
  static const padding = Field<EdgeInsetsGeometry>();

  /// How [padding] follows the text scale (default `.identity()`).
  static const paddingScaler = Field<PaddingScaler>();

  static const borderRadius = Field<BorderRadius>();
  static const minimumSize = Field<Size>();
  static const alignment = Field<AlignmentGeometry>();

  /// Merged per property across rules (composite).
  static const textStyle = TextStyleField();

  /// Merged per property across rules (composite). An unset size is
  /// computed by the widget from textStyle.fontSize (x 1.2).
  static const iconTheme = IconThemeField();

  /// The outline of the button shape. Unset = none. While focused, the
  /// focus ring is drawn instead. A whole BorderSide replaces the earlier
  /// one; `side: .parts(color: ...)` changes only its color.
  static const side = BorderSideField();

  /// The opacity the button fades to while pressed (resolved at the
  /// pressed minterm). 1.0 = no fade.
  static const pressedOpacity = Field<double>();

  static const mouseCursor = Field<MouseCursor>();

  // ---- Library defaults ----

  static final defaults = <Rule>[
    // Every appearance and state.
    Rule.always(label: 'rest', [
      pressedOpacity.value(0.4),
      alignment.value(Alignment.center),
      paddingScaler.value(.identity()),
    ]),

    // Size table (kButtonPadding / SizeBorderRadius / MinSize).
    Rule.when([sizeStyle.oneOf({ButtonSize.small})], label: 'rest', [
      padding.value(EdgeInsets.symmetric(vertical: 6, horizontal: 12)),
      borderRadius.value(BorderRadius.all(Radius.circular(40))),
      minimumSize.value(Size(28, 28)),
      textStyle.from(.fromToken(Cupertino.actionSmallTextStyle)),
    ]),
    Rule.when([sizeStyle.oneOf({ButtonSize.medium})], label: 'rest', [
      padding.value(EdgeInsets.symmetric(vertical: 10, horizontal: 15)),
      borderRadius.value(BorderRadius.all(Radius.circular(40))),
      minimumSize.value(Size(32, 32)),
      textStyle.from(.fromToken(Cupertino.actionTextStyle)),
    ]),
    Rule.when([sizeStyle.oneOf({ButtonSize.large})], label: 'rest', [
      padding.value(EdgeInsets.symmetric(vertical: 16, horizontal: 20)),
      borderRadius.value(BorderRadius.all(Radius.circular(12))),
      minimumSize.value(Size(44, 44)),
      textStyle.from(.fromToken(Cupertino.actionTextStyle)),
    ]),

    // Foreground: primary, tertiaryLabel when disabled; filled buttons use
    // primaryContrastingColor in every state.
    Rule.when([disabled.eq(false)], label: 'rest', [foregroundColor.from(.fromToken(Cupertino.primaryColor))]),
    Rule.when([disabled.eq(true)], label: 'disabled', [foregroundColor.value(CupertinoColors.tertiaryLabel)]),
    Rule.when([appearance.oneOf({ButtonAppearance.filled})], label: 'rest', [
      foregroundColor.from(.fromToken(Cupertino.primaryContrastingColor)),
    ]),

    // Background: tinted = the tintedFill token (primary at 0.12 in light
    // mode, 0.26 in dark mode; the per-brightness opacity lives in the token
    // rules, so this stays one rule without environment conditions), filled
    // = primary made opaque (the original's `withOpacity(1.0)`); disabled =
    // tertiarySystemFill (the tinted / filled constructors' default
    // disabledColor). Plain buttons have no default background.
    Rule.when([appearance.oneOf({ButtonAppearance.tinted}), disabled.eq(false)], label: 'rest', [
      backgroundColor.from(.fromToken(Cupertino.tintedFill)),
    ]),
    Rule.when([appearance.oneOf({ButtonAppearance.filled}), disabled.eq(false)], label: 'rest', [
      backgroundColor.from(.opaque(.fromToken(Cupertino.primaryColor))),
    ]),
    Rule.when([appearance.oneOf({ButtonAppearance.tinted, ButtonAppearance.filled}), disabled.eq(true)], label: 'disabled', [
      backgroundColor.value(CupertinoColors.tertiarySystemFill),
    ]),

    // Mouse cursor (the original's _defaultCursor). Off the web both values
    // are `defer` (accepted redundancy: one rule pair covers web and native).
    Rule.when([disabled.eq(false)], label: 'rest', [
      mouseCursor.value(kIsWeb ? SystemMouseCursors.click : MouseCursor.defer),
    ]),
    Rule.when([disabled.eq(true)], label: 'disabled', [mouseCursor.value(MouseCursor.defer)]),

    // Text and icon follow the final foreground (a same-component derive). Last,
    // so the token text style written above (it carries primaryColor) does
    // not overwrite the derived color.
    Rule.always(label: 'rest', [
      textStyle.parts(color: .fromField(foregroundColor)),
      iconTheme.parts(color: .fromField(foregroundColor)),
    ]),
  ];
}
