// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

const ButtonStyleSpec a = ButtonStyleSpec(backgroundColor: .fromField(SwitchField.trackColor)); // error
const SwitchStyleSpec b = SwitchStyleSpec(trackColor: .fromField(ButtonField.foregroundColor)); // error
// A callback reading a field of another component.
Color c(ButtonView s) => s.field(SwitchField.trackColor)!; // error
// A source of another component in a slot.
const ButtonStyleSpec d = ButtonStyleSpec(backgroundColor: SwitchColorSource.fromToken(.primaryColor)); // error
// Inside a transform and inside `.parts`.
const ButtonStyleSpec e = ButtonStyleSpec(backgroundColor: .opacity(.fromField(SwitchField.trackColor), 0.5)); // error
const ButtonStyleSpec f = ButtonStyleSpec(textStyle: .parts(color: .fromField(SwitchField.thumbColor))); // error
