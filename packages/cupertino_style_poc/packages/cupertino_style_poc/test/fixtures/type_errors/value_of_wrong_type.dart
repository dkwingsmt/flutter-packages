// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

const ButtonStyleSpec a = ButtonStyleSpec(backgroundColor: .value(EdgeInsets.all(1))); // error
const ButtonStyleSpec b = ButtonStyleSpec(padding: .value(Color(0xFF000000))); // error
// ButtonStyle / `.values` take plain values only, of the field's type.
const ButtonStyle c = ButtonStyle(backgroundColor: .value(Color(0xFF000000))); // error
const ButtonRule d = .always(style: .values(backgroundColor: EdgeInsets.all(1))); // error
const ButtonRule e = .always(style: .values(padding: Color(0xFF000000))); // error
// `.derive` takes sources, not plain values.
const ButtonRule f = .always(style: .derive(backgroundColor: Color(0xFF000000))); // error
