// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';

// `.parts()` without a sub-property fails its assert at const evaluation.
const ButtonStyleSpec a = ButtonStyleSpec(textStyle: .parts()); // error
const ButtonStyleSpec b = ButtonStyleSpec(side: .parts()); // error
