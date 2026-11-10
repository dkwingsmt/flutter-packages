// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Legacy WidgetStateProperty flat parameters (Switch trackOutlineColor /
// trackOutlineWidth / mouseCursor, Button mouseCursor) as one legacy rule:
// resolveWith works, resolves with the states the original passes, matches
// the original's pixels and cursors, falls through on null, and is
// re-evaluated on every lookup (an impure closure behaves like the
// original on rebuild) while everything else stays cached.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc/src/engine/cache.dart' show BoundCache;
import 'package:cupertino_style_poc/src/engine/engine.dart'
    show FlatRule, RawRule, Resolved, SymbolicStyle, chain, findShadowed, resolveSymbolic;
import 'package:cupertino_ui/cupertino_ui.dart' as orig;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/resolve_own.dart';

const Color red = Color(0xFFE53935);
const Color blue = Color(0xFF1E88E5);
const Color green = Color(0xFF43A047);
const Color grey = Color(0xFF9E9E9E);
const Color black = Color(0xFF000000);

final ResolvedEnvironment light = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.light);
final ResolvedEnvironment dark = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.dark);

Color? outlineByState(Set<WidgetState> s) {
  if (s.contains(WidgetState.disabled)) {
    return grey;
  }
  if (s.contains(WidgetState.focused)) {
    return blue;
  }
  if (s.contains(WidgetState.hovered)) {
    return green;
  }
  return s.contains(WidgetState.selected) ? red : black;
}

double? widthByState(Set<WidgetState> s) =>
    s.contains(WidgetState.focused) ? 4.0 : (s.contains(WidgetState.selected) ? 3.0 : 1.0);

/// Null for the unselected end unless focused: the original lerps the
/// width from null (0.0), the rewrite falls through to the default 2.0.
double? widthWithNull(Set<WidgetState> s) =>
    s.contains(WidgetState.focused) ? 4.0 : (s.contains(WidgetState.selected) ? 3.0 : null);

final WidgetStateProperty<Color?> outline = WidgetStateProperty.resolveWith<Color?>(outlineByState);
final WidgetStateProperty<double?> width = WidgetStateProperty.resolveWith<double?>(widthByState);
final WidgetStateProperty<double?> widthNull = WidgetStateProperty.resolveWith<double?>(widthWithNull);

MouseCursor buttonCursorByState(Set<WidgetState> s) => s.contains(WidgetState.disabled)
    ? SystemMouseCursors.forbidden
    : s.contains(WidgetState.pressed)
        ? SystemMouseCursors.grabbing
        : s.contains(WidgetState.focused)
            ? SystemMouseCursors.text
            : SystemMouseCursors.click;

MouseCursor switchCursorByState(Set<WidgetState> s) => s.contains(WidgetState.disabled)
    ? SystemMouseCursors.forbidden
    : s.contains(WidgetState.hovered)
        ? SystemMouseCursors.grab
        : s.contains(WidgetState.selected)
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic;

final WidgetStateMouseCursor buttonCursor = WidgetStateMouseCursor.resolveWith(buttonCursorByState);
final WidgetStateMouseCursor switchCursor = WidgetStateMouseCursor.resolveWith(switchCursorByState);

/// The cursors of every MouseRegion inside the capture boundary after
/// driving [interaction].
Future<List<MouseCursor>> cursorsAfter(
    WidgetTester tester, Widget Function(FocusNode f) build, Interaction interaction, ResolvedEnvironment env) async {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  final FocusNode f = FocusNode();
  await tester.pumpWidget(inEnvironment(env, build(f)));
  TestGesture? gesture;
  switch (interaction) {
    case Interaction.rest:
    case Interaction.disabled:
      break;
    case Interaction.focused:
      f.requestFocus();
      await tester.pump();
    case Interaction.pressed:
      gesture = await tester.startGesture(tester.getCenter(find.byKey(captureKey)));
      await tester.pump(const Duration(milliseconds: 500));
    case Interaction.hovered:
      gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(captureKey)));
      await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pump();
  final List<MouseCursor> out = <MouseCursor>[
    for (final MouseRegion r in tester.widgetList<MouseRegion>(
        find.descendant(of: find.byKey(captureKey), matching: find.byType(MouseRegion))))
      r.cursor,
  ];
  if (gesture != null) {
    if (interaction == Interaction.hovered) {
      await gesture.removePointer();
    } else {
      await gesture.up();
    }
  }
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  f.dispose();
  return out;
}

void main() {
  testWidgets('resolveWith flat parameters work and resolve with the states the original passes', (WidgetTester tester) async {
    await tester.pumpWidget(inEnvironment(light, const SizedBox()));
    final BuildContext ctx = tester.element(find.byType(SizedBox));
    final Switch sw = Switch(
        value: true, onChanged: (bool _) {}, trackOutlineColor: outline, trackOutlineWidth: width, mouseCursor: switchCursor);
    for (final bool selected in <bool>[false, true]) {
      for (final bool disabled in <bool>[false, true]) {
        for (final bool focused in <bool>[false, true]) {
          for (final bool hovered in <bool>[false, true]) {
            for (final bool pressed in <bool>[false, true]) {
              if (disabled && (focused || hovered || pressed)) {
                continue;
              }
              final Set<WidgetState> states = <WidgetState>{
                if (disabled) WidgetState.disabled,
                if (focused) WidgetState.focused,
                if (hovered) WidgetState.hovered,
                if (selected) WidgetState.selected,
                // never pressed: the original doesn't pass it for these
              };
              final SwitchStyle s = sw.resolveOwn(ctx,
                  selected: selected, disabled: disabled, focused: focused, hovered: hovered, pressed: pressed);
              expect(s.trackOutlineColor, outlineByState(states), reason: '$states');
              expect(s.trackOutlineWidth, widthByState(states), reason: '$states');
              expect(s.mouseCursor, switchCursorByState(states), reason: '$states');
            }
          }
        }
      }
    }
    final Button b = Button(mouseCursor: buttonCursor, onPressed: () {}, child: const SizedBox());
    expect(b.callSiteRules(), hasLength(1), reason: 'one legacy rule, no truth table');
    expect(b.resolveOwn(ctx).mouseCursor, SystemMouseCursors.click);
    expect(b.resolveOwn(ctx, pressed: true).mouseCursor, SystemMouseCursors.grabbing);
    expect(b.resolveOwn(ctx, focused: true).mouseCursor, SystemMouseCursors.text);
    expect(b.resolveOwn(ctx, disabled: true).mouseCursor, SystemMouseCursors.forbidden);
  });

  testWidgets('Switch with resolveWith outline color and width: pixels equal the original', (WidgetTester tester) async {
    final List<String> unexpected = <String>[];
    final List<String> expectedDiffs = <String>[];
    int compared = 0;
    for (final ResolvedEnvironment env in allEnvironments) {
      for (final bool value in <bool>[false, true]) {
        for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.focused, Interaction.hovered]) {
          for (final (String name, WidgetStateProperty<double?> w) in <(String, WidgetStateProperty<double?>)>[
            ('width', width),
            ('width with null', widthNull),
          ]) {
            final bool enabled = i != Interaction.disabled;
            final Pixels o = await pumpAndCapture(
                tester,
                (FocusNode f) => orig.CupertinoSwitch(
                    value: value,
                    focusNode: f,
                    trackOutlineColor: outline,
                    trackOutlineWidth: w,
                    onChanged: enabled ? (bool _) {} : null),
                i,
                env: env);
            final Pixels n = await pumpAndCapture(
                tester,
                (FocusNode f) => Switch(
                    value: value,
                    focusNode: f,
                    trackOutlineColor: outline,
                    trackOutlineWidth: w,
                    onChanged: enabled ? (bool _) {} : null),
                i,
                env: env);
            compared++;
            // Expected: the original lerps the width from the unselected
            // end's null (0.0, a hairline at value=false); the rewrite
            // treats null as "not set" and falls through to the default
            // 2.0. Focused states give 4.0 at both ends, so no difference.
            final bool expected = w == widthNull && !value && i != Interaction.focused;
            final String label = '$name/value=$value/${i.name}/${envName(env)}';
            if (!samePixels(o, n)) {
              (expected ? expectedDiffs : unexpected).add(label);
            } else if (expected) {
              unexpected.add('$label (expected a difference, got none)');
            }
          }
        }
      }
    }
    // ignore: avoid_print
    print('Switch resolveWith outline: $compared cases, ${expectedDiffs.length} expected diffs (null width), '
        '${unexpected.length} unexpected: $unexpected');
    expect(unexpected, isEmpty);
    expect(compared, 8 * 2 * 4 * 2);
  });

  testWidgets('resolveWith mouse cursors: the same MouseRegion cursors as the original', (WidgetTester tester) async {
    final List<String> unexpected = <String>[];
    for (final ResolvedEnvironment env in <ResolvedEnvironment>[light, dark]) {
      for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.pressed, Interaction.focused]) {
        final bool enabled = i != Interaction.disabled;
        final List<MouseCursor> o = await cursorsAfter(
            tester,
            (FocusNode f) => orig.CupertinoButton(
                mouseCursor: buttonCursor, focusNode: f, onPressed: enabled ? () {} : null, child: const Text('b')),
            i,
            env);
        final List<MouseCursor> n = await cursorsAfter(
            tester,
            (FocusNode f) => Button(mouseCursor: buttonCursor, focusNode: f, onPressed: enabled ? () {} : null, child: const Text('b')),
            i,
            env);
        if (!listEquals(o, n)) {
          unexpected.add('button ${i.name} ${envName(env)}: $o vs $n');
        }
      }
      for (final bool value in <bool>[false, true]) {
        for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.focused, Interaction.hovered]) {
          final bool enabled = i != Interaction.disabled;
          final List<MouseCursor> o = await cursorsAfter(
              tester,
              (FocusNode f) => orig.CupertinoSwitch(
                  value: value, mouseCursor: switchCursor, focusNode: f, onChanged: enabled ? (bool _) {} : null),
              i,
              env);
          final List<MouseCursor> n = await cursorsAfter(
              tester,
              (FocusNode f) =>
                  Switch(value: value, mouseCursor: switchCursor, focusNode: f, onChanged: enabled ? (bool _) {} : null),
              i,
              env);
          if (!listEquals(o, n)) {
            unexpected.add('switch value=$value ${i.name} ${envName(env)}: $o vs $n');
          }
        }
      }
    }
    expect(unexpected, isEmpty);
  });

  testWidgets('null falls through to the theme and the defaults; rules: still comes after', (WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(inEnvironment(
        light,
        StyleTheme(
          rules: const <Rule>[SwitchRule(SwitchWhen(), style: SwitchStyle(trackOutlineColor: blue))],
          child: Builder(builder: (BuildContext c) {
            ctx = c;
            return const SizedBox();
          }),
        )));
    final Switch sw = Switch(
      value: true,
      onChanged: (bool _) {},
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> s) => s.contains(WidgetState.focused) ? red : null),
      trackOutlineWidth: WidgetStateProperty.resolveWith<double?>(
          (Set<WidgetState> s) => s.contains(WidgetState.disabled) ? 5.0 : null),
      rules: const <SwitchRule>[SwitchRule(SwitchWhen(hovered: true), style: SwitchStyle(trackOutlineColor: green))],
    );
    expect(sw.resolveOwn(ctx, selected: true).trackOutlineColor, blue, reason: 'null -> theme');
    expect(sw.resolveOwn(ctx, selected: true, focused: true).trackOutlineColor, red);
    expect(sw.resolveOwn(ctx, selected: true, focused: true, hovered: true).trackOutlineColor, green,
        reason: 'rules: is after the flat parameters');
    expect(sw.resolveOwn(ctx, selected: false).trackOutlineWidth, 2.0, reason: 'null -> default');
    expect(sw.resolveOwn(ctx, selected: false, disabled: true).trackOutlineWidth, 5.0);

    // Provenance: the legacy rule when it returned a value, else the rule
    // it fell through to.
    final StyleNode node = StyleTheme.peekNode(ctx);
    final StyleResolver<SwitchField> r = StyleResolver<SwitchField>(switchStyle);
    Minterm m({bool focused = false}) => switchMinterm(
        disabled: false, selected: true, pressed: false, focused: focused, hovered: false, env: light);
    expect(r.debugSources(node, sw.callSiteRules(), m(focused: true))[SwitchField.trackOutlineColor],
        'WidgetStateProperty rule #0 (call site)');
    expect(r.debugSources(node, sw.callSiteRules(), m())[SwitchField.trackOutlineColor],
        'WidgetStateProperty rule #0 (call site) returned null -> rule #0 (theme)');
  });

  testWidgets('a dynamic color returned by the closure is resolved per environment', (WidgetTester tester) async {
    for (final ResolvedEnvironment env in allEnvironments) {
      await tester.pumpWidget(inEnvironment(env, const SizedBox()));
      final BuildContext ctx = tester.element(find.byType(SizedBox));
      final Switch sw = Switch(
          value: true,
          onChanged: (bool _) {},
          trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> _) => CupertinoColors.systemRed));
      expect(sw.resolveOwn(ctx, selected: true).trackOutlineColor,
          cupertinoEnvSplitter.resolve(CupertinoColors.systemRed, Minterm(EnvDims.all, env.values)),
          reason: envName(env));
    }
  });

  testWidgets('an impure closure is re-evaluated on rebuild, like the original; the rest stays cached', (WidgetTester tester) async {
    Color current = red;
    final WidgetStateProperty<Color?> impure = WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> _) => current);
    Widget ours() => StyleTheme(child: Switch(value: true, trackOutlineColor: impure, onChanged: (bool _) {}));
    Widget theirs() => orig.CupertinoSwitch(value: true, trackOutlineColor: impure, onChanged: (bool _) {});

    await tester.pumpWidget(inEnvironment(light, ours()));
    final BoundCache cache = StyleTheme.peekNode(tester.element(find.byType(Switch))).boundCache;
    final int misses = cache.misses;
    final Pixels oursRed = await capture(tester);
    current = blue;
    await tester.pumpWidget(inEnvironment(light, ours())); // rebuild, same property object
    final Pixels oursBlue = await capture(tester);
    expect(samePixels(oursRed, oursBlue), isFalse, reason: 'the new value is painted');
    expect(cache.misses, misses, reason: 'same chain, same minterms: the cache entries are reused');
    expect(cache.refreshes, greaterThan(0), reason: 'only the legacy field is evaluated again');

    current = red;
    await tester.pumpWidget(inEnvironment(light, theirs()));
    await tester.pumpAndSettle();
    final Pixels theirsRed = await capture(tester);
    current = blue;
    await tester.pumpWidget(inEnvironment(light, theirs()));
    final Pixels theirsBlue = await capture(tester);
    expect(samePixels(oursRed, theirsRed), isTrue);
    expect(samePixels(oursBlue, theirsBlue), isTrue);
  });

  test('cache: only fields that depend on a legacy source are re-evaluated (callbacks reading one included)', () {
    Color current = red;
    final Switch sw = Switch(
      value: true,
      onChanged: (bool _) {},
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> _) => current),
      rules: <SwitchRule>[
        SwitchRule(const SwitchWhen(),
            style: SwitchStyleSpec(focusColor: .computed((SwitchView s) => s.field(.trackOutlineColor)!.withAlpha(99)))),
      ],
    );
    final StyleNode node = StyleNode.root();
    final StyleResolver<SwitchField> r = StyleResolver<SwitchField>(switchStyle);
    final List<SwitchRule> callSite = sw.callSiteRules();
    final Minterm m = switchMinterm(disabled: false, selected: true, pressed: false, focused: false, hovered: false, env: light);
    final Map<SwitchField, Object> first = r.resolve(node, callSite, m);
    expect(first[SwitchField.trackOutlineColor], red);
    expect(first[SwitchField.focusColor], red.withAlpha(99));
    current = green;
    final Map<SwitchField, Object> second = r.resolve(node, callSite, m);
    expect(second[SwitchField.trackOutlineColor], green);
    expect(second[SwitchField.focusColor], green.withAlpha(99), reason: 'a callback reading a legacy field is volatile');
    expect(identical(second[SwitchField.trackColor], first[SwitchField.trackColor]), isTrue);
    expect(node.boundCache.misses, 1);
    expect(node.boundCache.refreshes, 1);
  });

  test('a legacy rule does not shadow the rules before it (it may fall through)', () {
    final Button b = Button(mouseCursor: buttonCursor, onPressed: () {}, child: const SizedBox());
    final List<FlatRule<ButtonField>> flat = chain<ButtonField>(<List<RawRule<ButtonField>>>[
      buttonStyle.defaults,
      <RawRule<ButtonField>>[for (final ButtonRule r in b.callSiteRules()) ...r.toRaws()],
    ], spec: buttonStyle.spec, splitter: cupertinoEnvSplitter);
    final Map<Minterm, Resolved<ButtonField>> table = <Minterm, Resolved<ButtonField>>{
      for (final Minterm m in buttonStyle.spec.minterms())
        m: () {
          final SymbolicStyle<ButtonField> s =
              resolveSymbolic(flat, m, buttonStyle.spec.fields, composites: buttonStyle.spec.composites);
          return Resolved<ButtonField>(const <ButtonField, Object>{}, s.winners, s.contributors);
        }(),
    };
    expect(findShadowed(buttonStyle.spec, flat, table), isEmpty);
  });

  test('map-form values keep the expansion path (plain rules, no legacy rule)', () {
    final WidgetStateMouseCursor map = WidgetStateMouseCursor.fromMap(<WidgetStatesConstraint, MouseCursor>{
      WidgetState.pressed: SystemMouseCursors.grabbing,
      WidgetState.any: SystemMouseCursors.click,
    });
    final List<ButtonRule> rules = Button(mouseCursor: map, onPressed: () {}, child: const SizedBox()).callSiteRules();
    for (final ButtonRule r in rules) {
      expect(r.toRaws().single.derive.isEmpty, isTrue);
    }
    final List<SwitchRule> all = Switch(
            value: true, onChanged: (bool _) {}, trackOutlineColor: const WidgetStatePropertyAll<Color>(red))
        .callSiteRules();
    expect(all.single, const SwitchRule(SwitchWhen(), style: SwitchStyle(trackOutlineColor: red)));
  });
}
