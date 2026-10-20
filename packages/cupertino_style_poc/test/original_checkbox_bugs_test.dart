// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Confirms, on the original cupertino_ui CupertinoCheckbox, which
// user-supplied CupertinoDynamicColors are painted unresolved in dark mode.
// The sample has no rewritten checkbox, so this only documents the original
// behaviour (quick-version names CupertinoCheckbox.fillColor as an example).
// Method as in original_bugs_test.dart: in dark mode, render with a dynamic
// color D (light = red, dark = green) and compare with plain red / green.
//   unresolved  <=>  orig(D) == orig(red) and orig(D) != orig(green)
//   resolved    <=>  orig(D) == orig(green)
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as orig;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDynamicColor, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const Color red = Color(0xFFFF0000);
const Color green = Color(0xFF00C000);
const CupertinoDynamicColor dyn = CupertinoDynamicColor.withBrightness(color: red, darkColor: green);

const ResolvedEnvironment dark =
    ResolvedEnvironment(brightness: Brightness.dark, highContrast: false, interfaceLevel: CupertinoUserInterfaceLevelData.base);

typedef Build = Widget Function(Color c, FocusNode f);

class CheckboxCase {
  const CheckboxCase(this.name, this.build, this.interaction, {required this.unresolvedExpected});
  final String name;
  final Build build;
  final Interaction interaction;
  final bool unresolvedExpected;
}

final List<CheckboxCase> cases = <CheckboxCase>[
  CheckboxCase(
      'fillColor (checked)',
      (Color c, FocusNode f) => orig.CupertinoCheckbox(
          value: true, fillColor: WidgetStatePropertyAll<Color>(c), focusNode: f, onChanged: (bool? _) {}),
      Interaction.rest,
      unresolvedExpected: true),
  CheckboxCase(
      'fillColor (unchecked)',
      (Color c, FocusNode f) => orig.CupertinoCheckbox(
          value: false, fillColor: WidgetStatePropertyAll<Color>(c), focusNode: f, onChanged: (bool? _) {}),
      Interaction.rest,
      unresolvedExpected: true),
  CheckboxCase(
      'checkColor',
      (Color c, FocusNode f) =>
          orig.CupertinoCheckbox(value: true, checkColor: c, focusNode: f, onChanged: (bool? _) {}),
      Interaction.rest,
      unresolvedExpected: true),
  CheckboxCase(
      'activeColor (deprecated)',
      // ignore: deprecated_member_use
      (Color c, FocusNode f) => orig.CupertinoCheckbox(value: true, activeColor: c, focusNode: f, onChanged: (bool? _) {}),
      Interaction.rest,
      unresolvedExpected: true),
  CheckboxCase(
      'focusColor',
      (Color c, FocusNode f) =>
          orig.CupertinoCheckbox(value: true, focusColor: c, focusNode: f, onChanged: (bool? _) {}),
      Interaction.focused,
      unresolvedExpected: true),
];

void main() {
  for (final CheckboxCase c in cases) {
    testWidgets('original CupertinoCheckbox.${c.name} in dark mode', (WidgetTester tester) async {
      Future<Pixels> run(Color color) => pumpAndCapture(tester, (FocusNode f) => c.build(color, f), c.interaction, env: dark);
      final Pixels origDyn = await run(dyn);
      final Pixels origRed = await run(red);
      final Pixels origGreen = await run(green);
      expect(samePixels(origRed, origGreen), isFalse, reason: 'the probe must be visible');
      final bool unresolved = samePixels(origDyn, origRed) && !samePixels(origDyn, origGreen);
      final bool resolved = samePixels(origDyn, origGreen);
      // ignore: avoid_print
      print('CupertinoCheckbox.${c.name}: unresolved in dark = $unresolved; resolved = $resolved');
      expect(unresolved || resolved, isTrue, reason: 'expected either the light or the dark variant');
      expect(unresolved, c.unresolvedExpected);
    });
  }
}
