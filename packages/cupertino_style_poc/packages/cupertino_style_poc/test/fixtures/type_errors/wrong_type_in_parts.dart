// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

// `.parts` takes the component's color source for color sub-properties.
const ButtonStyleSpec a = ButtonStyleSpec(textStyle: .parts(color: .fromField(.padding))); // error
const ButtonStyleSpec b = ButtonStyleSpec(side: .parts(color: .value(BorderSide()))); // error
const ButtonStyleSpec c = ButtonStyleSpec(iconTheme: .parts(color: .fromToken(.actionTextStyle))); // error
// A double sub-property takes a double source; no such sub-property.
const ButtonStyleSpec d = ButtonStyleSpec(side: .parts(width: .value(Color(0xFF000000)))); // error
const ButtonStyleSpec f = ButtonStyleSpec(side: .parts(style: .value(BorderStyle.solid))); // error
// `.parts` exists only on composite slots.
const ButtonStyleSpec e = ButtonStyleSpec(backgroundColor: .parts(color: .value(Color(0xFF000000)))); // error
