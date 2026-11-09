// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

EdgeInsets padding(ButtonView s) => const EdgeInsets.all(8);
Color color(SwitchView s) => const Color(0xFF000000);

const ButtonStyleSpec a = ButtonStyleSpec(backgroundColor: .computed(padding)); // error
// A callback taking another component's view.
const ButtonStyleSpec b = ButtonStyleSpec(backgroundColor: .computed(color)); // error
final ButtonStyleSpec c = ButtonStyleSpec(backgroundColor: .computed((ButtonView s) => 3)); // error
