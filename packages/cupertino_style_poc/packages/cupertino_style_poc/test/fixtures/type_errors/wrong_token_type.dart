// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

const ButtonStyleSpec a = ButtonStyleSpec(backgroundColor: .fromToken(.actionTextStyle)); // error
const ButtonStyleSpec b = ButtonStyleSpec(textStyle: .fromToken(.primaryColor)); // error
// An app token is not a CupertinoToken: it goes through `.fromCustomToken`.
const ButtonStyleSpec c = ButtonStyleSpec(backgroundColor: .fromToken(Brand.accent)); // error
// A callback reading a token of the wrong type.
Color d(ButtonView s) => s.token(.actionTextStyle); // error
// Token layer: a token source of the wrong type.
final TokenRule e = Brand.accent.setFrom(.fromToken(.actionTextStyle)); // error
