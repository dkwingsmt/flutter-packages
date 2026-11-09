// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The resolved style of one widget instance (its appearance, size and
// call-site rules) through the static `X.resolveStyle` of design doc 7.6.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

extension ButtonResolveOwn on Button {
  ButtonStyle resolveOwn(BuildContext context, {bool disabled = false, bool pressed = false, bool focused = false}) =>
      Button.resolveStyle(context,
          appearance: appearance,
          sizeStyle: sizeStyle,
          disabled: disabled,
          pressed: pressed,
          focused: focused,
          states: callSiteRules());
}

extension SwitchResolveOwn on Switch {
  SwitchStyle resolveOwn(BuildContext context,
          {required bool selected, bool disabled = false, bool pressed = false, bool focused = false, bool hovered = false}) =>
      Switch.resolveStyle(context,
          selected: selected,
          disabled: disabled,
          pressed: pressed,
          focused: focused,
          hovered: hovered,
          states: callSiteRules());
}
