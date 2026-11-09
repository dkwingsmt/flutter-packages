// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

// The receiver fixes the value type of `set` / `setFrom`.
final TokenRule a = Brand.accent.set(3); // error
final TokenRule b = Brand.cornerRadius.set(Color(0xFF000000)); // error
final TokenRule c = Brand.accent.setFrom(.value(3)); // error
final TokenRule d = CupertinoToken.primaryColor.set(const TextStyle()); // error
// Token rule classes take typed parameters.
const TokenRule e = BrandRule(accent: 3); // error
const TokenRule f = BrandRule(cornerRadius: Color(0xFF000000)); // error
const TokenRule g = CupertinoTokenRule(primaryColor: TextStyle()); // error
// The .derive constructor takes typed sources: no alpha transform on a
// non-Color token, no reference to a token of another value type.
const TokenRule i = CupertinoTokenRule.derive(textStyle: .opacity(.fromToken(.textStyle), 0.5)); // error
const TokenRule j = CupertinoTokenRule.derive(primaryColor: .fromToken(.textStyle)); // error
const TokenRule k = CupertinoTokenRule.derive(primaryColor: .value(TextStyle())); // error
// A single token read is typed by the token.
EdgeInsets h(Tokens t) => t.read(Brand.accent); // error
EdgeInsets l(BuildContext context) => Brand.accent.of(context); // error
