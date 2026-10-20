// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Confirms, on the original cupertino_ui widgets, which user-supplied
// CupertinoDynamicColors are painted unresolved in dark mode, and that the
// rule-based widgets resolve all of them. Method: in dark mode, render the
// original with a dynamic color D (light = red, dark = green) and compare
// with the original rendered with plain red / plain green.
//   bug in original  <=> orig(D) == orig(red) and orig(D) != orig(green)
//   fixed            <=> new(D) == orig(green)
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

class Case {
  const Case(this.name, this.original, this.rewritten, this.interaction, {required this.bugExpected});
  final String name;
  final Build original;
  final Build rewritten;
  final Interaction interaction;
  final bool bugExpected;
}

final List<Case> cases = <Case>[
  Case('Switch.activeTrackColor',
      (Color c, FocusNode f) => orig.CupertinoSwitch(value: true, activeTrackColor: c, focusNode: f, onChanged: (bool _) {}),
      (Color c, FocusNode f) => Switch(value: true, activeTrackColor: c, focusNode: f, onChanged: (bool _) {}),
      Interaction.rest,
      bugExpected: true),
  Case('Switch.inactiveTrackColor',
      (Color c, FocusNode f) => orig.CupertinoSwitch(value: false, inactiveTrackColor: c, focusNode: f, onChanged: (bool _) {}),
      (Color c, FocusNode f) => Switch(value: false, inactiveTrackColor: c, focusNode: f, onChanged: (bool _) {}),
      Interaction.rest,
      bugExpected: true),
  Case('Switch.thumbColor',
      (Color c, FocusNode f) => orig.CupertinoSwitch(value: true, thumbColor: c, focusNode: f, onChanged: (bool _) {}),
      (Color c, FocusNode f) => Switch(value: true, thumbColor: c, focusNode: f, onChanged: (bool _) {}),
      Interaction.rest,
      bugExpected: true),
  Case('Switch.inactiveThumbColor',
      (Color c, FocusNode f) => orig.CupertinoSwitch(value: false, inactiveThumbColor: c, focusNode: f, onChanged: (bool _) {}),
      (Color c, FocusNode f) => Switch(value: false, inactiveThumbColor: c, focusNode: f, onChanged: (bool _) {}),
      Interaction.rest,
      bugExpected: true),
  Case('Switch.trackOutlineColor',
      (Color c, FocusNode f) => orig.CupertinoSwitch(
          value: true, trackOutlineColor: WidgetStatePropertyAll<Color>(c), focusNode: f, onChanged: (bool _) {}),
      (Color c, FocusNode f) => Switch(value: true, trackOutlineColor: c, focusNode: f, onChanged: (bool _) {}),
      Interaction.rest,
      bugExpected: true),
  Case('Switch.focusColor (control)',
      (Color c, FocusNode f) => orig.CupertinoSwitch(value: true, focusColor: c, focusNode: f, onChanged: (bool _) {}),
      (Color c, FocusNode f) => Switch(value: true, focusColor: c, focusNode: f, onChanged: (bool _) {}),
      Interaction.focused,
      bugExpected: false),
  Case('Button.foregroundColor',
      (Color c, FocusNode f) => orig.CupertinoButton(foregroundColor: c, focusNode: f, onPressed: () {}, child: const Text('Button')),
      (Color c, FocusNode f) => Button(foregroundColor: c, focusNode: f, onPressed: () {}, child: const Text('Button')),
      Interaction.rest,
      bugExpected: true),
  Case('Button.focusColor',
      (Color c, FocusNode f) => orig.CupertinoButton.filled(focusColor: c, focusNode: f, onPressed: () {}, child: const Text('Button')),
      (Color c, FocusNode f) => Button.filled(focusColor: c, focusNode: f, onPressed: () {}, child: const Text('Button')),
      Interaction.focused,
      bugExpected: true),
  Case('Button.color (control)',
      (Color c, FocusNode f) => orig.CupertinoButton(color: c, focusNode: f, onPressed: () {}, child: const Text('Button')),
      (Color c, FocusNode f) => Button(color: c, focusNode: f, onPressed: () {}, child: const Text('Button')),
      Interaction.rest,
      bugExpected: false),
  Case('Button.disabledColor (control)',
      (Color c, FocusNode f) => orig.CupertinoButton.filled(disabledColor: c, focusNode: f, onPressed: null, child: const Text('Button')),
      (Color c, FocusNode f) => Button.filled(disabledColor: c, focusNode: f, onPressed: null, child: const Text('Button')),
      Interaction.disabled,
      bugExpected: false),
];

void main() {
  for (final Case c in cases) {
    testWidgets('${c.name}: original ${c.bugExpected ? 'paints the light variant in dark' : 'resolves'}; rewrite resolves',
        (WidgetTester tester) async {
      Future<Pixels> run(Build b, Color color) =>
          pumpAndCapture(tester, (FocusNode f) => b(color, f), c.interaction, env: dark);
      final origDyn = await run(c.original, dyn);
      final origRed = await run(c.original, red);
      final origGreen = await run(c.original, green);
      final newDyn = await run(c.rewritten, dyn);
      expect(samePixels(origRed, origGreen), isFalse, reason: 'the probe must be visible');
      final bool bug = samePixels(origDyn, origRed) && !samePixels(origDyn, origGreen);
      final bool fixed = samePixels(newDyn, origGreen);
      // ignore: avoid_print
      print('${c.name}: original unresolved in dark = $bug; rewrite resolved = $fixed');
      expect(bug, c.bugExpected);
      expect(fixed, isTrue);
    });
  }

  testWidgets('Switch: pressing an off switch shows thumbColor instead of inactiveThumbColor (original quirk)',
      (WidgetTester tester) async {
    const Color blue = Color(0xFF0000FF);
    final light = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.light && !e.highContrast &&
        e.interfaceLevel == CupertinoUserInterfaceLevelData.base);
    Future<Pixels> o(Color thumb, Color inactive) => pumpAndCapture(
        tester,
        (FocusNode f) => orig.CupertinoSwitch(
            value: false, thumbColor: thumb, inactiveThumbColor: inactive, focusNode: f, onChanged: (bool _) {}),
        Interaction.pressed,
        env: light);
    final origRedBlue = await o(red, blue);
    final origRedRed = await o(red, red);
    final newRedBlue = await pumpAndCapture(
        tester,
        (FocusNode f) => Switch(value: false, thumbColor: red, inactiveThumbColor: blue, focusNode: f, onChanged: (bool _) {}),
        Interaction.pressed,
        env: light);
    final origOnlyBlue = await pumpAndCapture(
        tester,
        (FocusNode f) => orig.CupertinoSwitch(value: false, inactiveThumbColor: blue, focusNode: f, onChanged: (bool _) {}),
        Interaction.pressed,
        env: light);
    // Original: the pressed off-thumb ignores inactiveThumbColor when
    // thumbColor is set.
    expect(samePixels(origRedBlue, origRedRed), isTrue);
    // Rewrite: inactiveThumbColor applies in every unselected state,
    // pressed included (same pixels as the original without thumbColor).
    expect(samePixels(newRedBlue, origOnlyBlue), isTrue);
    expect(samePixels(newRedBlue, origRedBlue), isFalse);
  });
}
