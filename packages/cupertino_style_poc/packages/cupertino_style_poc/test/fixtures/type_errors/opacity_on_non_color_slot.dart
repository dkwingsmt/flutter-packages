// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Must NOT compile: checked by test/type_safety_test.dart, which runs the
// analyzer on this file and expects an error on every line marked
// `// error` and nowhere else. Excluded from `flutter analyze`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';

// `.opacity` / `.opaque` exist only on the Color source class; a non-Color
// slot is typed with the generic source, which has neither.
const ButtonStyleSpec a = ButtonStyleSpec(padding: .opacity(.fromField(.padding), 0.5)); // error
const ButtonStyleSpec b = ButtonStyleSpec(pressedOpacity: .opaque(.value(0.4))); // error
const ButtonStyleSpec c = ButtonStyleSpec(textStyle: .opacity(.fromToken(.actionTextStyle), 0.5)); // error
// The Color source class in a non-Color slot.
const ButtonStyleSpec d = ButtonStyleSpec(padding: ButtonColorSource.opacity(.fromField(.foregroundColor), 0.5)); // error
// A non-Color source inside a color transform.
const ButtonStyleSpec e = ButtonStyleSpec(backgroundColor: .opacity(.fromField(.padding), 0.5)); // error
// Token layer: only Color tokens take the transforms.
final TokenRule f = Brand.cornerRadius.setFrom(.opacity(.value(4.0), 0.5)); // error
// The old named parameter is gone.
const ButtonStyleSpec g = ButtonStyleSpec(backgroundColor: .fromField(.foregroundColor, opacity: 0.5)); // error
