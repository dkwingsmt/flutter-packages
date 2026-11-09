// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

// An app token of the wrong value type.
const ButtonStyleSpec a = ButtonStyleSpec(borderRadius: .fromCustomToken(Brand.cornerRadius)); // error
const ButtonStyleSpec b = ButtonStyleSpec(backgroundColor: .fromCustomToken(Brand.cornerRadius)); // error
const ButtonStyleSpec c = ButtonStyleSpec(textStyle: .parts(color: .fromCustomToken(Brand.cornerRadius))); // error
final TokenRule d = Brand.cornerRadius.setFrom(.fromCustomToken(Brand.accent)); // error
Color e(ButtonView s) => s.customToken(Brand.cornerRadius); // error
