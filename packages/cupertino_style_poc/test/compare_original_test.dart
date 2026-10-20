// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Default look vs the original cupertino_ui widgets: pixel comparison over
// every appearance x size x state x 8 environments (Button) and value x
// state x labels x 8 environments (Switch), plus flat-parameter parity
// with plain (non-dynamic) colors. Expected differences are listed in
// [expectedButtonDiff] with the reason; anything else fails.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' as orig;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// The one intended difference in default looks: a focused plain button
/// draws its focus ring from activeBlue. The original passes the dynamic
/// activeBlue to `withOpacity` without resolving it, so it always uses the
/// light variant; here it is resolved. The HSL transform keeps only the
/// hue, so the difference shows only where activeBlue's variants differ
/// in hue (dark, and high contrast).
bool expectedButtonDiff(ButtonAppearance a, Interaction i, ResolvedEnvironment e) =>
    a == ButtonAppearance.plain && i == Interaction.focused && (e.brightness == Brightness.dark || e.highContrast);

Widget _child() => const Text('Button');

Widget origButton(ButtonAppearance a, orig.CupertinoButtonSize size, bool enabled, FocusNode f) {
  final VoidCallback? onPressed = enabled ? () {} : null;
  return switch (a) {
    ButtonAppearance.plain => orig.CupertinoButton(sizeStyle: size, focusNode: f, onPressed: onPressed, child: _child()),
    ButtonAppearance.tinted =>
      orig.CupertinoButton.tinted(sizeStyle: size, focusNode: f, onPressed: onPressed, child: _child()),
    ButtonAppearance.filled =>
      orig.CupertinoButton.filled(sizeStyle: size, focusNode: f, onPressed: onPressed, child: _child()),
  };
}

Widget newButton(ButtonAppearance a, ButtonSize size, bool enabled, FocusNode f) =>
    Button(appearance: a, sizeStyle: size, focusNode: f, onPressed: enabled ? () {} : null, child: _child());

void main() {
  testWidgets('Button defaults: pixels equal the original', (WidgetTester tester) async {
    int compared = 0;
    final List<String> expectedDiffs = <String>[];
    final List<String> unexpected = <String>[];
    for (final ResolvedEnvironment env in allEnvironments) {
      for (final ButtonAppearance a in ButtonAppearance.values) {
        for (final ButtonSize size in ButtonSize.values) {
          for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.pressed, Interaction.focused]) {
            final bool enabled = i != Interaction.disabled;
            final o = await pumpAndCapture(tester, (FocusNode f) => origButton(a, size, enabled, f), i, env: env);
            final n = await pumpAndCapture(tester, (FocusNode f) => newButton(a, size, enabled, f), i, env: env);
            compared++;
            final String name = '${a.name}/${size.name}/${i.name}/${envName(env)}';
            if (!samePixels(o, n)) {
              (expectedButtonDiff(a, i, env) ? expectedDiffs : unexpected).add(name);
            } else if (expectedButtonDiff(a, i, env)) {
              unexpected.add('$name (expected a difference, got none)');
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('Button defaults: $compared cases, ${expectedDiffs.length} expected diffs '
        '(plain focus ring, resolved activeBlue), ${unexpected.length} unexpected');
    expect(unexpected, isEmpty);
    expect(compared, 3 * 3 * 4 * 8);
  });

  testWidgets('Button flat parameters (plain colors): pixels equal the original', (WidgetTester tester) async {
    // Non-dynamic values, so the original's missing resolution doesn't
    // matter; checks the parameter -> region mapping.
    const Color red = Color(0xFFE53935);
    const Color green = Color(0xFF43A047);
    const Color grey = Color(0x80808080);
    final List<(String, Widget Function(bool, FocusNode), Widget Function(bool, FocusNode))> cases =
        <(String, Widget Function(bool, FocusNode), Widget Function(bool, FocusNode))>[
      ('plain color', (bool e, FocusNode f) => orig.CupertinoButton(color: red, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button(color: red, focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('plain color+disabledColor',
          (bool e, FocusNode f) => orig.CupertinoButton(color: red, disabledColor: grey, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button(color: red, disabledColor: grey, focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('tinted color', (bool e, FocusNode f) => orig.CupertinoButton.tinted(color: red, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button.tinted(color: red, focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('filled color+fg', (bool e, FocusNode f) => orig.CupertinoButton.filled(color: red, foregroundColor: green, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button.filled(color: red, foregroundColor: green, focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('filled disabledColor', (bool e, FocusNode f) => orig.CupertinoButton.filled(disabledColor: grey, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button.filled(disabledColor: grey, focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('plain fg', (bool e, FocusNode f) => orig.CupertinoButton(foregroundColor: green, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button(foregroundColor: green, focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('geometry', (bool e, FocusNode f) => orig.CupertinoButton.filled(
              padding: const EdgeInsets.all(3), borderRadius: const BorderRadius.all(Radius.circular(2)),
              minimumSize: const Size(90, 60), alignment: Alignment.bottomRight, pressedOpacity: 0.7,
              focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button.filled(
              padding: const EdgeInsets.all(3), borderRadius: const BorderRadius.all(Radius.circular(2)),
              minimumSize: const Size(90, 60), alignment: Alignment.bottomRight, pressedOpacity: 0.7,
              focusNode: f, onPressed: e ? () {} : null, child: _child())),
      ('focusColor', (bool e, FocusNode f) => orig.CupertinoButton.tinted(focusColor: green, focusNode: f, onPressed: e ? () {} : null, child: _child()),
          (bool e, FocusNode f) => Button.tinted(focusColor: green, focusNode: f, onPressed: e ? () {} : null, child: _child())),
    ];
    final List<String> unexpected = <String>[];
    final List<String> expectedDiffs = <String>[];
    int compared = 0;
    for (final ResolvedEnvironment env in allEnvironments) {
      for (final (String name, Widget Function(bool, FocusNode) o, Widget Function(bool, FocusNode) n) in cases) {
        for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.pressed, Interaction.focused]) {
          final bool enabled = i != Interaction.disabled;
          final a = await pumpAndCapture(tester, (FocusNode f) => o(enabled, f), i, env: env);
          final b = await pumpAndCapture(tester, (FocusNode f) => n(enabled, f), i, env: env);
          compared++;
          // 'plain fg' has no background, so its focus ring comes from
          // activeBlue: same expected difference as in the defaults.
          final bool expected = name == 'plain fg' && expectedButtonDiff(ButtonAppearance.plain, i, env);
          if (!samePixels(a, b)) {
            (expected ? expectedDiffs : unexpected).add('$name/${i.name}/${envName(env)}');
          }
        }
      }
    }
    // ignore: avoid_print
    print('Button flat params: $compared cases, ${expectedDiffs.length} expected diffs (activeBlue focus ring), '
        '${unexpected.length} unexpected: $unexpected');
    expect(unexpected, isEmpty);
  });

  testWidgets('captures are not trivially equal', (WidgetTester tester) async {
    final ResolvedEnvironment light = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.light);
    final ResolvedEnvironment dark = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.dark);
    Widget b(FocusNode f) => orig.CupertinoButton.filled(focusNode: f, onPressed: () {}, child: _child());
    final l = await pumpAndCapture(tester, b, Interaction.rest, env: light);
    final d = await pumpAndCapture(tester, b, Interaction.rest, env: dark);
    final p = await pumpAndCapture(tester, b, Interaction.pressed, env: light);
    expect(samePixels(l, d), isFalse);
    expect(samePixels(l, p), isFalse);
    expect(l.$2.any((int byte) => byte != 0), isTrue);
    final fo = await pumpAndCapture(tester, b, Interaction.focused, env: light);
    expect(samePixels(l, fo), isFalse);
    Widget s(FocusNode f) => orig.CupertinoSwitch(value: true, focusNode: f, onChanged: (bool _) {});
    final sr = await pumpAndCapture(tester, s, Interaction.rest, env: light);
    final sp = await pumpAndCapture(tester, s, Interaction.pressed, env: light);
    final sf = await pumpAndCapture(tester, s, Interaction.focused, env: light);
    expect(samePixels(sr, sp), isFalse);
    expect(samePixels(sr, sf), isFalse);
  });

  testWidgets('Switch defaults: pixels equal the original', (WidgetTester tester) async {
    int compared = 0;
    final List<String> unexpected = <String>[];
    for (final ResolvedEnvironment env in allEnvironments) {
      for (final bool value in <bool>[false, true]) {
        for (final bool labels in <bool>[false, true]) {
          for (final Interaction i in Interaction.values) {
            final bool enabled = i != Interaction.disabled;
            final o = await pumpAndCapture(
                tester,
                (FocusNode f) => orig.CupertinoSwitch(value: value, focusNode: f, onChanged: enabled ? (bool _) {} : null),
                i,
                env: env,
                onOffLabels: labels);
            final n = await pumpAndCapture(
                tester,
                (FocusNode f) => Switch(value: value, focusNode: f, onChanged: enabled ? (bool _) {} : null),
                i,
                env: env,
                onOffLabels: labels);
            compared++;
            if (!samePixels(o, n)) {
              unexpected.add('value=$value/labels=$labels/${i.name}/${envName(env)}');
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('Switch defaults: $compared cases, ${unexpected.length} diffs: $unexpected');
    expect(unexpected, isEmpty);
  });

  testWidgets('Switch flat parameters (plain colors): pixels equal the original', (WidgetTester tester) async {
    const Color red = Color(0xFFE53935);
    const Color blue = Color(0xFF1E88E5);
    const Color yellow = Color(0xFFFDD835);
    const Color black = Color(0xFF000000);
    final List<String> unexpected = <String>[];
    int compared = 0;
    for (final ResolvedEnvironment env in allEnvironments) {
      for (final bool value in <bool>[false, true]) {
        for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.focused]) {
          final bool enabled = i != Interaction.disabled;
          final o = await pumpAndCapture(
              tester,
              (FocusNode f) => orig.CupertinoSwitch(
                    value: value,
                    focusNode: f,
                    activeTrackColor: red,
                    inactiveTrackColor: blue,
                    thumbColor: yellow,
                    inactiveThumbColor: black,
                    trackOutlineColor: const WidgetStatePropertyAll<Color>(black),
                    trackOutlineWidth: const WidgetStatePropertyAll<double>(3),
                    focusColor: blue,
                    onChanged: enabled ? (bool _) {} : null,
                  ),
              i,
              env: env);
          final n = await pumpAndCapture(
              tester,
              (FocusNode f) => Switch(
                    value: value,
                    focusNode: f,
                    activeTrackColor: red,
                    inactiveTrackColor: blue,
                    thumbColor: yellow,
                    inactiveThumbColor: black,
                    trackOutlineColor: black,
                    trackOutlineWidth: 3,
                    focusColor: blue,
                    onChanged: enabled ? (bool _) {} : null,
                  ),
              i,
              env: env);
          compared++;
          if (!samePixels(o, n)) {
            unexpected.add('value=$value/${i.name}/${envName(env)}');
          }
        }
      }
    }
    // ignore: avoid_print
    print('Switch flat params: $compared cases, ${unexpected.length} diffs: $unexpected');
    expect(unexpected, isEmpty);
  });

  test('environment list covers 8 combinations', () {
    expect(allEnvironments.length, 8);
    expect(allEnvironments.where((ResolvedEnvironment e) => e.interfaceLevel == CupertinoUserInterfaceLevelData.elevated).length, 4);
    expect(CupertinoColors.systemGreen, isNotNull);
  });
}
