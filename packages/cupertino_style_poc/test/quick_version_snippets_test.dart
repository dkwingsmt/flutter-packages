// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The example code of quick-version.md,
// section "Design Skeleton" parts 1-3, and the FAQ entries on dynamic colors
// and WidgetStateProperty (plus the ThemeExtension entry, which the Brand
// group of part 2 relies on), turned into tests. Each group quotes the
// doc's code, then writes it with this repo's API as literally as the API
// allows, and checks every claim the surrounding prose and code comments
// make, in all 8 environments and every possible button state.
//
// A claim that does not hold is written as the doc states it, skipped
// with a reason starting 'DOC MISMATCH:', and followed by a test of the
// actual behaviour.
//
// Name mapping (doc, hypothetical Liquid Glass API -> this repo):
//
//   Button                         -> Button
//   ButtonRule / ButtonWhen        -> ButtonRule / ButtonWhen
//   ButtonStyle / ButtonDerive     -> ButtonStyle / ButtonDerive
//   ButtonAppearance.prominent     -> ButtonAppearance.filled
//   tintColor: (constructor)       -> color:
//   tintColor (style / derive)     -> backgroundColor
//   iconColor (derive)             -> iconThemeColor (sub-property target)
//   iconColor (plain style value)  -> iconTheme: IconThemeData(color: ...)
//   borderRadius: 12               -> borderRadius: BorderRadius.all(Radius.circular(12))
//   Brand.green                    -> Brand.accent of the sample Brand group
//                                     (StyleTheme(groups: [brandGroup]) plus
//                                     TokenRule.group(brandGroup, BrandPalettes.teal))
//   FieldRef(.foregroundColor)     -> FieldRef(ButtonField.foregroundColor)
//   tintColor: CupertinoTokens.primaryColor (default derive)
//                                  -> backgroundColor: TokenRef(CupertinoTokens.primaryColor,
//                                     alpha: 1.0) on filled buttons (the doc's one
//                                     default rule is two default rules here)
//   CheckoutPanel()                -> CheckoutPanel, a placeholder below: plain,
//                                     tinted and filled buttons (medium size, whose
//                                     default radius 40 differs from 12; large is 12
//                                     already), two disabled buttons, a switch
//   save                           -> a top-level no-op
//   the app's environment          -> CupertinoApp(theme: brightness) plus a
//                                     `builder` setting MediaQuery.highContrast and
//                                     CupertinoUserInterfaceLevel
// ignore_for_file: avoid_redundant_argument_values
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc/src/engine/engine.dart' show FlatRule;
import 'package:cupertino_ui/cupertino_ui.dart' as orig;
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoApp, CupertinoColors, CupertinoDynamicColor, CupertinoThemeData, CupertinoUserInterfaceLevel, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

// ---------------------------------------------------------------------------
// Shared helpers.

void save() {}

/// Eight distinct variants, so every environment slot is told apart.
const CupertinoDynamicColor eight = CupertinoDynamicColor(
  debugLabel: 'eight',
  color: Color(0xFF110000),
  darkColor: Color(0xFF220000),
  highContrastColor: Color(0xFF330000),
  darkHighContrastColor: Color(0xFF440000),
  elevatedColor: Color(0xFF550000),
  darkElevatedColor: Color(0xFF660000),
  highContrastElevatedColor: Color(0xFF770000),
  darkHighContrastElevatedColor: Color(0xFF880000),
);

Color variant(Color c, ResolvedEnvironment e) {
  if (c is! CupertinoDynamicColor) {
    return c;
  }
  final bool d = e.brightness == Brightness.dark;
  final bool el = e.interfaceLevel == CupertinoUserInterfaceLevelData.elevated;
  return switch ((d, e.highContrast, el)) {
    (false, false, false) => c.color,
    (true, false, false) => c.darkColor,
    (false, true, false) => c.highContrastColor,
    (true, true, false) => c.darkHighContrastColor,
    (false, false, true) => c.elevatedColor,
    (true, false, true) => c.darkElevatedColor,
    (false, true, true) => c.highContrastElevatedColor,
    (true, true, true) => c.darkHighContrastElevatedColor,
  };
}

bool isDark(ResolvedEnvironment e) => e.brightness == Brightness.dark;

/// Every possible button state (disabled excludes pressed and focused).
typedef BState = ({bool disabled, bool pressed, bool focused});
const List<BState> buttonStates = <BState>[
  (disabled: false, pressed: false, focused: false),
  (disabled: false, pressed: true, focused: false),
  (disabled: false, pressed: false, focused: true),
  (disabled: false, pressed: true, focused: true),
  (disabled: true, pressed: false, focused: false),
];

String stateName(BState s) => s.disabled
    ? 'disabled'
    : s.pressed
        ? (s.focused ? 'pressed+focused' : 'pressed')
        : (s.focused ? 'focused' : 'rest');

/// One resolved button style: environment x button x state.
class Probe {
  Probe(this.env, this.id, this.appearance, this.state, this.style);
  final ResolvedEnvironment env;
  final String id;
  final ButtonAppearance appearance;
  final BState state;
  final ButtonStyle style;
  String get name => '${envName(env)}/$id/${stateName(state)}';
}

/// Pumps [build] in every environment and resolves every button in [ids]
/// in every state (`resolveStyle` reads the button's own chain: theme,
/// scopes, flat parameters, `states:`).
Future<List<Probe>> probeButtons(WidgetTester tester, Widget Function(ResolvedEnvironment e) build,
    {List<String> ids = CheckoutPanel.buttons}) async {
  final List<Probe> out = <Probe>[];
  for (final ResolvedEnvironment e in allEnvironments) {
    await tester.pumpWidget(build(e));
    for (final String id in ids) {
      final Finder f = find.byKey(ValueKey<String>(id));
      final Button b = tester.widget<Button>(f);
      final BuildContext ctx = tester.element(f);
      for (final BState s in buttonStates) {
        out.add(Probe(e, id, b.appearance, s,
            b.resolveStyle(ctx, disabled: s.disabled, pressed: s.pressed, focused: s.focused)));
      }
    }
  }
  return out;
}

const Color _mask = Color(0x00000000);

/// [s] with the named fields blanked (text / icon color go with the
/// foreground, which they follow), for "everything else unchanged".
ButtonStyle blank(ButtonStyle s, {bool background = false, bool foreground = false, bool icon = false}) =>
    ButtonStyle(
      backgroundColor: background ? null : s.backgroundColor,
      foregroundColor: foreground ? null : s.foregroundColor,
      focusColor: s.focusColor,
      padding: s.padding,
      borderRadius: s.borderRadius,
      minimumSize: s.minimumSize,
      alignment: s.alignment,
      textStyle: foreground ? s.textStyle?.copyWith(color: _mask) : s.textStyle,
      iconTheme: foreground || icon ? s.iconTheme?.copyWith(color: _mask) : s.iconTheme,
      pressedOpacity: s.pressedOpacity,
      mouseCursor: s.mouseCursor,
    );

/// Pairs two probe lists taken over the same tree shape.
void forPairs(List<Probe> a, List<Probe> b, void Function(Probe x, Probe y) check) {
  expect(a.length, b.length);
  expect(a, isNotEmpty);
  for (int i = 0; i < a.length; i++) {
    expect(a[i].name, b[i].name);
    check(a[i], b[i]);
  }
}

/// The app's environment, the way an app sets it today.
TransitionBuilder envBuilder(ResolvedEnvironment e) => (BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(highContrast: e.highContrast),
      child: CupertinoUserInterfaceLevel(data: e.interfaceLevel, child: child!),
    );

Widget app(ResolvedEnvironment e, Widget home) =>
    CupertinoApp(theme: CupertinoThemeData(brightness: e.brightness), builder: envBuilder(e), home: home);

/// Placeholder for the doc's `CheckoutPanel()`.
class CheckoutPanel extends StatelessWidget {
  const CheckoutPanel({super.key});

  static const String plain = 'plain';
  static const String tinted = 'tinted';
  static const String filled = 'filled';
  static const String plainDisabled = 'plainDisabled';
  static const String filledDisabled = 'filledDisabled';
  static const List<String> buttons = <String>[plain, tinted, filled, plainDisabled, filledDisabled];
  static const Key toggle = ValueKey<String>('switch');

  static Widget _button(String id, ButtonAppearance a, {bool enabled = true}) => Button(
        key: ValueKey<String>(id),
        appearance: a,
        sizeStyle: ButtonSize.medium,
        onPressed: enabled ? save : null,
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          SizedBox(key: ValueKey<String>('$id.probe'), width: 4, height: 4),
          const Text('Pay'),
        ]),
      );

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        _button(plain, ButtonAppearance.plain),
        _button(tinted, ButtonAppearance.tinted),
        _button(filled, ButtonAppearance.filled),
        _button(plainDisabled, ButtonAppearance.plain, enabled: false),
        _button(filledDisabled, ButtonAppearance.filled, enabled: false),
        Switch(key: toggle, value: true, onChanged: (bool _) {}),
      ]);
}

/// What the button paints: background, text color, icon color.
Color? paintedBackground(WidgetTester tester, String id) => ((tester
            .widget<DecoratedBox>(
                find.descendant(of: find.byKey(ValueKey<String>(id)), matching: find.byType(DecoratedBox)).first)
            .decoration) as ShapeDecoration)
    .color;
Color? paintedText(WidgetTester tester, String id) =>
    DefaultTextStyle.of(tester.element(find.byKey(ValueKey<String>('$id.probe')))).style.color;
Color? paintedIcon(WidgetTester tester, String id) =>
    IconTheme.of(tester.element(find.byKey(ValueKey<String>('$id.probe')))).color;

/// No value in [flat] depends on the environment.
void expectNoDynamicValues<F extends Enum>(List<FlatRule<F>> flat) {
  for (final FlatRule<F> r in flat) {
    for (final Object v in <Object>[...r.style.values.values, ...r.sub.values]) {
      expect(cupertinoEnvSplitter.varies(v), isFalse, reason: '${r.label}: $v');
    }
  }
}

/// Counts component builds by key.
final Map<Key, int> builds = <Key, int>{};

// ---------------------------------------------------------------------------
// Snippet 2 rules (shared by several groups).

/// Only changes non-disabled background and corner radius; the default disabled look is preserved
const ButtonRule themeEnabledRule = ButtonRule(ButtonWhen(disabled: false),
    style: ButtonStyle(borderRadius: BorderRadius.all(Radius.circular(12))),
    derive: ButtonDerive(backgroundColor: Brand.accent)); // Brand is the app's own token group

/// Dark + pressed: brightness and interaction state live in the same condition, resolved once
const Color darkPressedYellow = Color(0xFFFFD60A);
const ButtonRule themeDarkPressedRule = ButtonRule(
    ButtonWhen(pressed: true, brightness: <Brightness>{Brightness.dark}),
    style: ButtonStyle(foregroundColor: darkPressedYellow));

/// Local override appends after outer rules: only tintColor changes here (passing a dynamic color automatically expands by environment),
/// while borderRadius: 12 and the dark-pressed foreground color from the theme above remain intact
const ButtonRule scopeOrangeRule = ButtonRule(ButtonWhen(disabled: false),
    style: ButtonStyle(backgroundColor: CupertinoColors.systemOrange));

final TokenRule brandTeal = TokenRule.group(brandGroup, BrandPalettes.teal);

final List<Rule> docThemeRules = <Rule>[brandTeal, themeEnabledRule, themeDarkPressedRule];

/// The doc's tree: StyleTheme > CupertinoApp > StyleScope > CheckoutPanel.
/// [scope] null: no StyleScope (theme only).
Widget docTree(ResolvedEnvironment e,
        {List<Rule>? theme, List<Rule>? scope = const <Rule>[scopeOrangeRule], Widget panel = const CheckoutPanel()}) =>
    StyleTheme(
      groups: <TokenGroup<Object>>[brandGroup],
      rules: theme ?? docThemeRules,
      child: app(e, scope == null ? panel : StyleScope(rules: scope, child: panel)),
    );

Widget defaultsTree(ResolvedEnvironment e) => docTree(e, theme: const <Rule>[], scope: null);

final CupertinoDynamicColor tealAccent = BrandPalettes.teal.accent as CupertinoDynamicColor;
final CupertinoDynamicColor purpleAccent = BrandPalettes.purple.accent as CupertinoDynamicColor;

void main() {
  setUp(() {
    builds.clear();
    StyleDebug.onComponentBuild = (Widget w) {
      if (w.key != null) {
        builds[w.key!] = (builds[w.key!] ?? 0) + 1;
      }
    };
  });
  tearDown(() => StyleDebug.onComponentBuild = null);

  // -------------------------------------------------------------------------
  // 1. Everyday Call Sites: Standard Usage Remains Unchanged; State Customization Without Closures
  //
  // Most call sites use flat parameters without touching rules, and dynamic colors from
  // `CupertinoColors` pass in as usual:
  //
  //   Button(
  //     appearance: ButtonAppearance.prominent,
  //     tintColor: CupertinoColors.systemRed,
  //     onPressed: save,
  //     child: const Text('Save'),
  //   )
  //
  // You only add `states:` when tweaking a specific state on a single instance. Flat parameters compile
  // down to rules placed before `states:`, so `states:` only needs to specify the state being changed—unlike
  // `WidgetStateProperty.resolveWith`, which forces you to handle every state branch:
  //
  //   Button(
  //     appearance: ButtonAppearance.prominent,
  //     tintColor: CupertinoColors.systemRed,
  //     states: [
  //       ButtonRule(ButtonWhen(pressed: true),
  //           style: ButtonStyle(foregroundColor: CupertinoColors.systemYellow)),
  //     ],
  //     onPressed: save,
  //     child: const Text('Save'),
  //   )
  group('snippet 1: call site', () {
    Widget saveButton({FocusNode? focusNode, bool enabled = true}) => Button(
          key: const ValueKey<String>('save'),
          appearance: ButtonAppearance.filled,
          color: CupertinoColors.systemRed,
          focusNode: focusNode,
          onPressed: enabled ? save : null,
          child: const Text('Save'),
        );

    const ButtonRule pressedYellow = ButtonRule(ButtonWhen(pressed: true),
        style: ButtonStyle(foregroundColor: CupertinoColors.systemYellow));

    Widget saveButtonWithStates(
            {Color? foregroundColor, ButtonAppearance appearance = ButtonAppearance.filled, bool states = true}) =>
        Button(
          key: const ValueKey<String>('save'),
          appearance: appearance,
          color: CupertinoColors.systemRed,
          foregroundColor: foregroundColor,
          states: <ButtonRule>[if (states) pressedYellow],
          onPressed: save,
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            const SizedBox(key: ValueKey<String>('save.probe'), width: 4, height: 4),
            const Text('Save'),
          ]),
        );

    testWidgets('flat parameters with a dynamic color: same pixels as the original cupertino_ui button, 8 environments x 4 states',
        (WidgetTester tester) async {
      final List<String> differ = <String>[];
      int compared = 0;
      for (final ResolvedEnvironment e in allEnvironments) {
        for (final Interaction i in <Interaction>[Interaction.rest, Interaction.disabled, Interaction.pressed, Interaction.focused]) {
          final bool enabled = i != Interaction.disabled;
          final Pixels o = await pumpAndCapture(
              tester,
              (FocusNode f) => orig.CupertinoButton.filled(
                  color: orig.CupertinoColors.systemRed, focusNode: f, onPressed: enabled ? save : null, child: const Text('Save')),
              i,
              env: e);
          final Pixels n = await pumpAndCapture(tester, (FocusNode f) => saveButton(focusNode: f, enabled: enabled), i, env: e);
          compared++;
          if (!samePixels(o, n)) {
            differ.add('${envName(e)}/${i.name}');
          }
        }
      }
      expect(compared, 32);
      expect(differ, isEmpty);
    });

    testWidgets('flat parameters: the dynamic color is resolved per environment (plain color in the style, the painted one)',
        (WidgetTester tester) async {
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(inEnvironment(e, saveButton()));
        final Button b = tester.widget<Button>(find.byKey(const ValueKey<String>('save')));
        final BuildContext ctx = tester.element(find.byKey(const ValueKey<String>('save')));
        for (final BState s in buttonStates.where((BState s) => !s.disabled)) {
          final Color? bg = b.resolveStyle(ctx, pressed: s.pressed, focused: s.focused).backgroundColor;
          expect(bg, variant(CupertinoColors.systemRed, e), reason: '${envName(e)}/${stateName(s)}');
          expect(bg, isNot(isA<CupertinoDynamicColor>()));
        }
        final Color? painted = paintedBackground(tester, 'save');
        expect(painted, variant(CupertinoColors.systemRed, e));
        expect(painted, isNot(isA<CupertinoDynamicColor>()));
      }
    });

    testWidgets('states: [pressed rule] changes only foregroundColor, only in pressed states; rest / focused / disabled unchanged',
        (WidgetTester tester) async {
      for (final ButtonAppearance appearance in ButtonAppearance.values) {
        final List<Probe> a = await probeButtons(
            tester, (ResolvedEnvironment e) => inEnvironment(e, saveButtonWithStates(appearance: appearance)),
            ids: <String>['save']);
        final List<Probe> b = await probeButtons(
            tester, (ResolvedEnvironment e) => inEnvironment(e, saveButtonWithStates(appearance: appearance, states: false)),
            ids: <String>['save']);
        int changed = 0;
        forPairs(a, b, (Probe x, Probe y) {
          if (x.state.pressed) {
            final Color expectedYellow = variant(CupertinoColors.systemYellow, x.env);
            expect(x.style.foregroundColor, expectedYellow, reason: '${appearance.name}/${x.name}');
            expect(blank(x.style, foreground: true), blank(y.style, foreground: true), reason: '${appearance.name}/${x.name}');
            if (y.style.foregroundColor != expectedYellow) {
              changed++;
            }
          } else {
            expect(x.style, y.style, reason: '${appearance.name}/${x.name}');
          }
        });
        // Changed in all 8 environments x 2 pressed states across all appearances (including filled).
        expect(changed, 16, reason: appearance.name);
        // The disabled look is the default one: the pressed rule did not
        // spill into other states.
        if (appearance != ButtonAppearance.plain) {
          for (final Probe p in a.where((Probe p) => p.state.disabled)) {
            expect(p.style.backgroundColor, variant(CupertinoColors.tertiarySystemFill, p.env));
            expect(p.style.foregroundColor,
                appearance == ButtonAppearance.filled ? CupertinoColors.white : variant(CupertinoColors.tertiaryLabel, p.env));
          }
        }
      }
    });

    testWidgets('states: the painted text color is systemYellow while pressed and back after release', (WidgetTester tester) async {
      for (final ButtonAppearance appearance in ButtonAppearance.values) {
        for (final ResolvedEnvironment e in allEnvironments) {
          await tester.pumpWidget(inEnvironment(e, saveButtonWithStates(appearance: appearance)));
          final Color rest = appearance == ButtonAppearance.filled
              ? variant(const CupertinoThemeData().primaryContrastingColor, e)
              : variant(CupertinoColors.systemBlue, e);
          expect(paintedText(tester, 'save'), rest);
          final Color? bgRest = paintedBackground(tester, 'save');
          final TestGesture g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<String>('save'))));
          await tester.pump(const Duration(milliseconds: 500));
          final Color expectedYellow = variant(CupertinoColors.systemYellow, e);
          expect(paintedText(tester, 'save'), expectedYellow, reason: '${appearance.name}/${envName(e)}');
          expect(paintedIcon(tester, 'save'), expectedYellow);
          expect(paintedBackground(tester, 'save'), bgRest);
          await g.up();
          await tester.pumpAndSettle();
          expect(paintedText(tester, 'save'), rest);
        }
      }
    });

    testWidgets('flat parameters are rules placed before states:, so states: wins only where it matches',
        (WidgetTester tester) async {
      final Button b = saveButtonWithStates(foregroundColor: CupertinoColors.systemGreen) as Button;
      final List<ButtonRule> rules = b.callSiteRules();
      expect(rules.last, same(pressedYellow), reason: 'states: come last');
      expect(rules.first.style.backgroundColor, CupertinoColors.systemRed, reason: 'flat color: is a rule');
      expect(rules.where((ButtonRule r) => r.style.foregroundColor == CupertinoColors.systemGreen), hasLength(1),
          reason: 'flat foregroundColor: is a rule');
      final List<Probe> probes =
          await probeButtons(tester, (ResolvedEnvironment e) => inEnvironment(e, b), ids: <String>['save']);
      for (final Probe p in probes) {
        expect(p.style.foregroundColor,
            p.state.pressed ? variant(CupertinoColors.systemYellow, p.env) : variant(CupertinoColors.systemGreen, p.env),
            reason: p.name);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 2. Themes and Local Overrides: Modify Only Specified States and Properties; Combine Brightness and Interaction States Directly
  //
  // Rules concatenate into a single chain ordered as:
  // Component Defaults -> `StyleTheme` -> outer-to-inner `StyleScope` -> Call-site Flat Parameters -> Call-site `states:`.
  // Later rules win on a per-property basis. Conditions are flat, and omitted dimensions remain unconstrained:
  //
  //   StyleTheme(
  //     rules: [
  //       // Only changes non-disabled background and corner radius; the default disabled look is preserved
  //       ButtonRule(ButtonWhen(disabled: false),
  //           style: ButtonStyle(borderRadius: 12),
  //           derive: ButtonDerive(tintColor: Brand.green)),      // Brand is the app's own token group
  //       // Dark + pressed: brightness and interaction state live in the same condition, resolved once
  //       ButtonRule(
  //           ButtonWhen(pressed: true, brightness: {Brightness.dark}),
  //           style: ButtonStyle(foregroundColor: Color(0xFFFFD60A))),
  //     ],
  //     child: CupertinoApp(
  //       home: StyleScope(
  //         // Local override appends after outer rules: only tintColor changes here (passing a dynamic color automatically expands by environment),
  //         // while borderRadius: 12 and the dark-pressed foreground color from the theme above remain intact
  //         rules: [
  //           ButtonRule(ButtonWhen(disabled: false),
  //               style: ButtonStyle(tintColor: CupertinoColors.systemOrange)),
  //         ],
  //         child: CheckoutPanel(),
  //       ),
  //     ),
  //   )
  //
  // Rules for different components can live in the same `rules` list. Each rule routes to its
  // component's channel, so updating rules for one component only notifies widgets of that type.
  //
  // Written here as [themeEnabledRule], [themeDarkPressedRule],
  // [scopeOrangeRule] and [docTree] (plus the Brand group and its values).
  group('snippet 2: theme and local override', () {
    testWidgets('the chain: defaults -> StyleTheme -> StyleScopes outer to inner -> flat parameters -> states:, later wins per field',
        (WidgetTester tester) async {
      BorderRadius r(double v) => BorderRadius.all(Radius.circular(v));
      ButtonRule radius(double v) =>
          ButtonRule(const ButtonWhen(), style: ButtonStyle(borderRadius: r(v)));
      const EdgeInsets themePadding = EdgeInsets.all(3);
      final ButtonRule themeRule =
          ButtonRule(const ButtonWhen(), style: ButtonStyle(borderRadius: r(1), padding: themePadding));
      Future<ButtonStyle> resolve(
          {bool theme = true, bool outer = true, bool inner = true, bool flat = true, bool states = true}) async {
        await tester.pumpWidget(inEnvironment(
            allEnvironments.first,
            StyleTheme(
              rules: <Rule>[if (theme) themeRule],
              child: StyleScope(
                rules: <Rule>[if (outer) radius(2)],
                child: StyleScope(
                  rules: <Rule>[if (inner) radius(3)],
                  child: Button(
                    key: const ValueKey<String>('b'),
                    borderRadius: flat ? r(4) : null,
                    states: <ButtonRule>[if (states) radius(5)],
                    onPressed: save,
                    child: const Text('b'),
                  ),
                ),
              ),
            )));
        final Finder f = find.byKey(const ValueKey<String>('b'));
        return tester.widget<Button>(f).resolveStyle(tester.element(f));
      }

      expect((await resolve()).borderRadius, r(5));
      expect((await resolve(states: false)).borderRadius, r(4));
      expect((await resolve(states: false, flat: false)).borderRadius, r(3));
      expect((await resolve(states: false, flat: false, inner: false)).borderRadius, r(2));
      expect((await resolve(states: false, flat: false, inner: false, outer: false)).borderRadius, r(1));
      expect((await resolve(states: false, flat: false, inner: false, outer: false, theme: false)).borderRadius, r(12),
          reason: 'the large-size default');
      // Per field: the theme's padding survives every later radius.
      expect((await resolve()).padding, themePadding);
    });

    testWidgets('theme rule 1: only non-disabled background (Brand token) and radius change; the default disabled look stays',
        (WidgetTester tester) async {
      final List<Probe> theme =
          await probeButtons(tester, (ResolvedEnvironment e) => docTree(e, theme: <Rule>[brandTeal, themeEnabledRule], scope: null));
      final List<Probe> defaults = await probeButtons(tester, defaultsTree);
      forPairs(theme, defaults, (Probe x, Probe y) {
        if (x.state.disabled) {
          expect(x.style, y.style, reason: '${x.name}: default disabled look');
        } else {
          // Unwritten dims are unconstrained: every appearance, pressed /
          // focused and environment.
          expect(x.style.backgroundColor, variant(tealAccent, x.env), reason: x.name);
          expect(x.style.borderRadius, const BorderRadius.all(Radius.circular(12)), reason: x.name);
          expect(y.style.borderRadius, const BorderRadius.all(Radius.circular(40)));
          final ButtonStyle rest = ButtonStyle(
            foregroundColor: x.style.foregroundColor,
            focusColor: x.style.focusColor,
            padding: x.style.padding,
            minimumSize: x.style.minimumSize,
            alignment: x.style.alignment,
            textStyle: x.style.textStyle,
            iconTheme: x.style.iconTheme,
            pressedOpacity: x.style.pressedOpacity,
            mouseCursor: x.style.mouseCursor,
          );
          final ButtonStyle restDefault = ButtonStyle(
            foregroundColor: y.style.foregroundColor,
            focusColor: y.style.focusColor,
            padding: y.style.padding,
            minimumSize: y.style.minimumSize,
            alignment: y.style.alignment,
            textStyle: y.style.textStyle,
            iconTheme: y.style.iconTheme,
            pressedOpacity: y.style.pressedOpacity,
            mouseCursor: y.style.mouseCursor,
          );
          expect(rest, restDefault, reason: '${x.name}: other fields unchanged');
        }
      });
      // Painted: the disabled buttons look like the defaults.
      await tester.pumpWidget(docTree(allEnvironments.first, theme: <Rule>[brandTeal, themeEnabledRule], scope: null));
      expect(paintedBackground(tester, CheckoutPanel.filledDisabled),
          variant(CupertinoColors.tertiarySystemFill, allEnvironments.first));
      expect(paintedBackground(tester, CheckoutPanel.plainDisabled), isNull);
      expect(paintedBackground(tester, CheckoutPanel.plain), variant(tealAccent, allEnvironments.first));
    });

    testWidgets('theme rule 1: Brand is the app\'s own token group; changing its value changes the derived background',
        (WidgetTester tester) async {
      final List<Probe> purple = await probeButtons(
          tester,
          (ResolvedEnvironment e) => docTree(e,
              theme: <Rule>[TokenRule.group(brandGroup, BrandPalettes.purple), themeEnabledRule], scope: null));
      for (final Probe p in purple.where((Probe p) => !p.state.disabled)) {
        expect(p.style.backgroundColor, variant(purpleAccent, p.env), reason: p.name);
      }
    });

    testWidgets('theme rule 2: dark + pressed in one condition sets the foreground only where both hold',
        (WidgetTester tester) async {
      final List<Probe> both = await probeButtons(tester, (ResolvedEnvironment e) => docTree(e, scope: null));
      final List<Probe> rule1 =
          await probeButtons(tester, (ResolvedEnvironment e) => docTree(e, theme: <Rule>[brandTeal, themeEnabledRule], scope: null));
      int hits = 0;
      forPairs(both, rule1, (Probe x, Probe y) {
        if (isDark(x.env) && x.state.pressed) {
          hits++;
          expect(x.style.foregroundColor, darkPressedYellow, reason: x.name);
          expect(blank(x.style, foreground: true), blank(y.style, foreground: true), reason: x.name);
        } else {
          expect(x.style, y.style, reason: '${x.name}: light pressed, dark rest / focused / disabled unchanged');
        }
      });
      expect(hits, 4 * 2 * CheckoutPanel.buttons.length, reason: '4 dark environments x 2 pressed states x 5 buttons');
      // Light pressed keeps the default foreground.
      final Probe lightPressed =
          both.firstWhere((Probe p) => !isDark(p.env) && p.state.pressed && p.id == CheckoutPanel.plain);
      expect(lightPressed.style.foregroundColor, variant(CupertinoColors.systemBlue, lightPressed.env));
    });

    testWidgets('theme rule 2: one authored rule, one flat rule in the chain, conditioned on pressed and brightness together',
        (WidgetTester tester) async {
      await tester.pumpWidget(docTree(allEnvironments.first, scope: null));
      final StyleNode node = StyleTheme.peekNode(tester.element(find.byKey(const ValueKey<String>(CheckoutPanel.plain))));
      final List<FlatRule<ButtonField>> chain =
          StyleResolver<ButtonField>(buttonStyle).debugChain(node, const <ButtonRule>[]);
      final List<FlatRule<ButtonField>> fromRule =
          chain.where((FlatRule<ButtonField> r) => identical(r.source, themeDarkPressedRule.toRaw())).toList();
      expect(fromRule, hasLength(1));
      expect(fromRule.single.condition.constraints[ButtonDims.pressed], <Object>{true});
      expect(fromRule.single.condition.constraints[EnvDims.brightness], <Object>{Brightness.dark});
    });

    testWidgets('StyleScope: appended after the theme; only the background changes, radius 12 and the dark-pressed yellow stay',
        (WidgetTester tester) async {
      final List<Probe> scoped = await probeButtons(tester, docTree);
      final List<Probe> themeOnly = await probeButtons(tester, (ResolvedEnvironment e) => docTree(e, scope: null));
      final List<Probe> defaults = await probeButtons(tester, defaultsTree);
      forPairs(scoped, themeOnly, (Probe x, Probe y) {
        if (x.state.disabled) {
          expect(x.style, y.style, reason: x.name);
        } else {
          // The scope's dynamic color, expanded per environment.
          expect(x.style.backgroundColor, variant(CupertinoColors.systemOrange, x.env), reason: x.name);
          expect(blank(x.style, background: true), blank(y.style, background: true), reason: '${x.name}: only the tint changed');
          expect(x.style.borderRadius, const BorderRadius.all(Radius.circular(12)), reason: x.name);
          if (isDark(x.env) && x.state.pressed) {
            expect(x.style.foregroundColor, darkPressedYellow, reason: '${x.name}: dark-pressed foreground kept');
          }
        }
      });
      // Disabled still the default look under theme + scope.
      forPairs(scoped, defaults, (Probe x, Probe y) {
        if (x.state.disabled) {
          expect(x.style, y.style, reason: x.name);
        }
      });
      // Painted, in every environment.
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(docTree(e));
        for (final String id in <String>[CheckoutPanel.plain, CheckoutPanel.tinted, CheckoutPanel.filled]) {
          expect(paintedBackground(tester, id), variant(CupertinoColors.systemOrange, e), reason: '${envName(e)}/$id');
        }
        // A real press on the plain button: yellow text in dark only, the
        // orange background either way.
        final TestGesture g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey<String>(CheckoutPanel.plain))));
        await tester.pump(const Duration(milliseconds: 500));
        expect(paintedText(tester, CheckoutPanel.plain),
            isDark(e) ? darkPressedYellow : variant(CupertinoColors.systemBlue, e), reason: '${envName(e)} pressed');
        expect(paintedBackground(tester, CheckoutPanel.plain), variant(CupertinoColors.systemOrange, e));
        await g.up();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('StyleScope: the dynamic color becomes plain-color sub-rules of the scope rule, one per distinct variant',
        (WidgetTester tester) async {
      await tester.pumpWidget(docTree(allEnvironments.first));
      final StyleNode node = StyleTheme.peekNode(tester.element(find.byKey(const ValueKey<String>(CheckoutPanel.plain))));
      final List<FlatRule<ButtonField>> chain =
          StyleResolver<ButtonField>(buttonStyle).debugChain(node, const <ButtonRule>[]);
      expectNoDynamicValues(chain);
      final List<FlatRule<ButtonField>> sub =
          chain.where((FlatRule<ButtonField> r) => identical(r.source, scopeOrangeRule.toRaw())).toList();
      final Set<Color> distinct = <Color>{for (final ResolvedEnvironment e in allEnvironments) variant(CupertinoColors.systemOrange, e)};
      expect(sub, hasLength(distinct.length));
      expect(<Object?>{for (final FlatRule<ButtonField> r in sub) r.style.values[ButtonField.backgroundColor]},
          distinct);
      for (final FlatRule<ButtonField> r in sub) {
        expect(r.condition.constraints[ButtonDims.disabled], <Object>{false});
      }
    });

    testWidgets('one rules list holds several components; each rule goes to its own channel', (WidgetTester tester) async {
      const SwitchRule orangeTrack =
          SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: CupertinoColors.systemOrange));
      final List<Rule> mixed = <Rule>[brandTeal, themeEnabledRule, orangeTrack, themeDarkPressedRule];
      final RuleChannels c = RuleChannels.of(mixed);
      expect(c.rulesOf(ButtonRule), <Rule>[themeEnabledRule, themeDarkPressedRule]);
      expect(c.rulesOf(SwitchRule), <Rule>[orangeTrack]);
      expect(c.tokens, <TokenRule>[brandTeal]);
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(docTree(e, theme: mixed, scope: null));
        final Switch sw = tester.widget<Switch>(find.byKey(CheckoutPanel.toggle));
        final SwitchStyle s = sw.resolveStyle(tester.element(find.byKey(CheckoutPanel.toggle)), selected: true);
        expect(s.trackColor, variant(CupertinoColors.systemOrange, e));
        expect(paintedBackground(tester, CheckoutPanel.plain), variant(tealAccent, e));
      }
    });

    testWidgets('changing one component\'s rules notifies only that component type (theme list)', (WidgetTester tester) async {
      const SwitchRule orangeTrack =
          SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: CupertinoColors.systemOrange));
      const SwitchRule purpleTrack =
          SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: CupertinoColors.systemPurple));
      // One CupertinoApp instance, so only StyleTheme notifications rebuild.
      final Widget theApp = app(allEnvironments.first, const StyleScope(rules: <Rule>[scopeOrangeRule], child: CheckoutPanel()));
      Widget tree(List<Rule> rules) => StyleTheme(groups: <TokenGroup<Object>>[brandGroup], rules: rules, child: theApp);
      int buttonBuilds() => <String>[for (final String id in CheckoutPanel.buttons) id]
          .map((String id) => builds[ValueKey<String>(id)] ?? 0)
          .fold(0, (int a, int b) => a + b);
      int switchBuilds() => builds[CheckoutPanel.toggle] ?? 0;

      await tester.pumpWidget(tree(<Rule>[brandTeal, themeEnabledRule, orangeTrack]));
      expect(buttonBuilds(), 5);
      expect(switchBuilds(), 1);

      // Button rule changes: buttons rebuild, the switch does not.
      await tester.pumpWidget(tree(<Rule>[brandTeal, themeEnabledRule, themeDarkPressedRule, orangeTrack]));
      expect(buttonBuilds(), 10);
      expect(switchBuilds(), 1);

      // Switch rule changes: the switch rebuilds, buttons do not.
      await tester.pumpWidget(tree(<Rule>[brandTeal, themeEnabledRule, themeDarkPressedRule, purpleTrack]));
      expect(buttonBuilds(), 10);
      expect(switchBuilds(), 2);
      final Switch sw = tester.widget<Switch>(find.byKey(CheckoutPanel.toggle));
      expect(sw.resolveStyle(tester.element(find.byKey(CheckoutPanel.toggle)), selected: true).trackColor,
          variant(CupertinoColors.systemPurple, allEnvironments.first));

      // An equal new list notifies nobody.
      await tester.pumpWidget(tree(<Rule>[brandTeal, themeEnabledRule, themeDarkPressedRule, purpleTrack]));
      expect(buttonBuilds(), 10);
      expect(switchBuilds(), 2);
    });

    testWidgets('changing one component\'s rules notifies only that component type (scope list)', (WidgetTester tester) async {
      final GlobalKey<_ScopeHostState> host = GlobalKey<_ScopeHostState>();
      await tester.pumpWidget(StyleTheme(
          groups: <TokenGroup<Object>>[brandGroup],
          rules: docThemeRules,
          child: app(allEnvironments.first, _ScopeHost(key: host, initial: const <Rule>[scopeOrangeRule]))));
      int buttonBuilds() =>
          CheckoutPanel.buttons.map((String id) => builds[ValueKey<String>(id)] ?? 0).fold(0, (int a, int b) => a + b);
      int switchBuilds() => builds[CheckoutPanel.toggle] ?? 0;
      expect(buttonBuilds(), 5);
      expect(switchBuilds(), 1);
      host.currentState!.setRules(const <Rule>[
        ButtonRule(ButtonWhen(disabled: false),
            style: ButtonStyle(backgroundColor: CupertinoColors.systemPink)),
      ]);
      await tester.pump();
      expect(buttonBuilds(), 10);
      expect(switchBuilds(), 1);
      expect(paintedBackground(tester, CheckoutPanel.plain), variant(CupertinoColors.systemPink, allEnvironments.first));
      host.currentState!.setRules(const <Rule>[
        ButtonRule(ButtonWhen(disabled: false),
            style: ButtonStyle(backgroundColor: CupertinoColors.systemPink)),
        SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: CupertinoColors.systemPink)),
      ]);
      await tester.pump();
      expect(buttonBuilds(), 10);
      expect(switchBuilds(), 2);
    });
  });

  // -------------------------------------------------------------------------
  // 3. Derivation and Global Settings: Explicit Follow Relationships That Can Be Overridden Anytime
  //
  // Relationships like "icon color follows foreground color" or "reference global brand color" live in
  // a rule's `derive` block and evaluate after the entire rule chain resolves:
  //
  //   // In component defaults: icon color follows the final foreground color; background color references the global primaryColor token
  //   const ButtonRule(ButtonWhen(disabled: false),
  //     derive: ButtonDerive(
  //       iconColor: FieldRef(.foregroundColor),
  //       tintColor: CupertinoTokens.primaryColor,
  //     ),
  //   )
  //
  // Because evaluation happens after the entire chain resolves, passing `foregroundColor: CupertinoColors.white`
  // at the call site (or overriding the foreground color only in dark mode) automatically updates the icon color
  // in that environment. If a theme wants to break this follow relationship, it simply writes a standard
  // `ButtonRule` assigning a concrete color or another reference to `iconColor`—the later rule wins.
  group('snippet 3: derives', () {
    // The doc's one default rule is two default rules here: the follow
    // derive (in every state, not only `disabled: false`; text color too)
    // and the background derive of filled buttons.
    const ButtonRule followForeground = ButtonRule(ButtonWhen(), label: 'rest',
        derive: ButtonDerive(
          textStyleColor: FieldRef(ButtonField.foregroundColor),
          iconThemeColor: FieldRef(ButtonField.foregroundColor),
        ));
    const ButtonRule primaryBackground = ButtonRule(
        ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.filled}, disabled: false),
        label: 'rest',
        derive: ButtonDerive(backgroundColor: TokenRef(CupertinoTokens.primaryColor, alpha: 1.0)));

    Widget tree(ResolvedEnvironment e, {List<Rule> theme = const <Rule>[], Widget panel = const CheckoutPanel()}) =>
        docTree(e, theme: <Rule>[brandTeal, ...theme], scope: null, panel: panel);

    testWidgets('the defaults hold the two derives; icon follows the final foreground, background takes the primaryColor token',
        (WidgetTester tester) async {
      expect(buttonDefaults, contains(followForeground));
      expect(buttonDefaults, contains(primaryBackground));
      final List<Probe> probes = await probeButtons(tester, tree);
      for (final Probe p in probes) {
        expect(p.style.iconTheme?.color, p.style.foregroundColor, reason: p.name);
        if (p.appearance == ButtonAppearance.filled && !p.state.disabled) {
          expect(p.style.backgroundColor, variant(CupertinoColors.systemBlue, p.env), reason: p.name);
        }
      }
      // Changing the global token changes both, in every environment.
      const Color primary = Color(0xFF123456);
      final List<Probe> custom = await probeButtons(
          tester,
          (ResolvedEnvironment e) =>
              tree(e, theme: <Rule>[TokenRule.group(cupertinoTokenGroup, const CupertinoThemeData(primaryColor: primary))]));
      for (final Probe p in custom.where((Probe p) => !p.state.disabled)) {
        if (p.appearance == ButtonAppearance.filled) {
          expect(p.style.backgroundColor, primary, reason: p.name);
        } else {
          expect(p.style.foregroundColor, primary, reason: p.name);
          expect(p.style.iconTheme?.color, primary, reason: p.name);
        }
      }
    });

    testWidgets('call-site foregroundColor: white: the icon follows, in every environment and state', (WidgetTester tester) async {
      Widget panel(ButtonAppearance a) => Button(
            key: const ValueKey<String>('b'),
            appearance: a,
            foregroundColor: CupertinoColors.white,
            onPressed: save,
            child: const SizedBox(key: ValueKey<String>('b.probe'), width: 4, height: 4),
          );
      for (final ButtonAppearance a in ButtonAppearance.values) {
        final List<Probe> probes =
            await probeButtons(tester, (ResolvedEnvironment e) => tree(e, panel: panel(a)), ids: <String>['b']);
        for (final Probe p in probes) {
          expect(p.style.foregroundColor, CupertinoColors.white, reason: p.name);
          expect(p.style.iconTheme?.color, CupertinoColors.white, reason: '${a.name}/${p.name}');
        }
        expect(paintedIcon(tester, 'b'), CupertinoColors.white);
      }
    });

    testWidgets('foreground overridden in dark only: the icon follows in dark, light unchanged', (WidgetTester tester) async {
      const ButtonRule darkWhite = ButtonRule(ButtonWhen(brightness: <Brightness>{Brightness.dark}),
          style: ButtonStyle(foregroundColor: CupertinoColors.white));
      Widget panel({required bool override}) => Button(
            key: const ValueKey<String>('b'),
            states: <ButtonRule>[if (override) darkWhite],
            onPressed: save,
            child: const SizedBox(key: ValueKey<String>('b.probe'), width: 4, height: 4),
          );
      final List<Probe> a =
          await probeButtons(tester, (ResolvedEnvironment e) => tree(e, panel: panel(override: true)), ids: <String>['b']);
      final List<Probe> b =
          await probeButtons(tester, (ResolvedEnvironment e) => tree(e, panel: panel(override: false)), ids: <String>['b']);
      forPairs(a, b, (Probe x, Probe y) {
        if (isDark(x.env)) {
          expect(x.style.iconTheme?.color, CupertinoColors.white, reason: x.name);
        } else {
          expect(x.style, y.style, reason: x.name);
        }
        expect(x.style.iconTheme?.color, x.style.foregroundColor, reason: x.name);
      });
      // The same override in the theme.
      final List<Probe> t = await probeButtons(
          tester, (ResolvedEnvironment e) => tree(e, theme: const <Rule>[darkWhite], panel: panel(override: false)),
          ids: <String>['b']);
      forPairs(t, b, (Probe x, Probe y) {
        expect(x.style.iconTheme?.color, isDark(x.env) ? CupertinoColors.white : y.style.iconTheme?.color, reason: x.name);
      });
    });

    testWidgets('a plain theme rule on the icon color breaks the follow; the later rule wins', (WidgetTester tester) async {
      const Color green = Color(0xFF00FF00);
      const ButtonRule iconGreen =
          ButtonRule(ButtonWhen(), style: ButtonStyle(iconTheme: IconThemeData(color: green)));
      final List<Probe> probes = await probeButtons(
          tester,
          (ResolvedEnvironment e) => tree(e,
              theme: const <Rule>[iconGreen],
              panel: const Button(
                key: ValueKey<String>('b'),
                foregroundColor: CupertinoColors.white,
                onPressed: save,
                child: SizedBox(key: ValueKey<String>('b.probe'), width: 4, height: 4),
              )),
          ids: <String>['b']);
      for (final Probe p in probes) {
        expect(p.style.foregroundColor, CupertinoColors.white, reason: p.name);
        expect(p.style.iconTheme?.color, green, reason: '${p.name}: follow broken');
        expect(p.style.textStyle?.color, CupertinoColors.white, reason: '${p.name}: only the icon is cut loose');
      }
      expect(paintedIcon(tester, 'b'), green);
    });

    testWidgets('a theme rule pointing the icon at another reference also wins', (WidgetTester tester) async {
      const ButtonRule iconBrand =
          ButtonRule(ButtonWhen(), derive: ButtonDerive(iconThemeColor: Brand.accent));
      final List<Probe> probes = await probeButtons(
          tester,
          (ResolvedEnvironment e) => tree(e,
              theme: const <Rule>[iconBrand],
              panel: const Button(
                key: ValueKey<String>('b'),
                foregroundColor: CupertinoColors.white,
                onPressed: save,
                child: SizedBox(key: ValueKey<String>('b.probe'), width: 4, height: 4),
              )),
          ids: <String>['b']);
      for (final Probe p in probes) {
        expect(p.style.foregroundColor, CupertinoColors.white, reason: p.name);
        expect(p.style.iconTheme?.color, variant(tealAccent, p.env), reason: p.name);
      }
    });
  });

  // -------------------------------------------------------------------------
  // FAQ: What happens to Cupertino's dynamic colors?
  //
  // Both widget constructor parameters and a rule's `style` can accept dynamic colors like
  // `CupertinoColors.systemRed` directly (the outer `When` condition usually omits environment
  // dimensions; if specified, only the dynamic color's values within those matching environments
  // are used). The system expands them into environment-specific rules in one place, so individual
  // widgets never have to call `resolveFrom` by hand.
  group('FAQ: dynamic colors', () {
    const ButtonRule eightBackground =
        ButtonRule(ButtonWhen(), style: ButtonStyle(backgroundColor: eight));

    Future<void> expectExpanded(WidgetTester tester, Widget Function(ResolvedEnvironment e) build,
        {required String what, bool Function(BState s)? where, Color? Function(ButtonStyle s)? read}) async {
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(build(e));
        final Finder f = find.byKey(const ValueKey<String>('b'));
        final Button b = tester.widget<Button>(f);
        final BuildContext ctx = tester.element(f);
        for (final BState s in buttonStates.where(where ?? (BState _) => true)) {
          final Color? v = (read ?? (ButtonStyle s) => s.backgroundColor)(
              b.resolveStyle(ctx, disabled: s.disabled, pressed: s.pressed, focused: s.focused));
          expect(v, variant(eight, e), reason: '$what ${envName(e)}/${stateName(s)}');
          expect(v, isNot(isA<CupertinoDynamicColor>()));
        }
        // The chain the widget resolves from holds no dynamic value.
        expectNoDynamicValues(StyleResolver<ButtonField>(buttonStyle)
            .debugChain(StyleTheme.peekNode(ctx), b.callSiteRules()));
      }
    }

    Widget button({Color? color, Color? foregroundColor, Color? disabledColor, Color? focusColor,
            List<ButtonRule> states = const <ButtonRule>[]}) =>
        Button(
          key: const ValueKey<String>('b'),
          appearance: ButtonAppearance.filled,
          color: color,
          foregroundColor: foregroundColor,
          disabledColor: disabledColor,
          focusColor: focusColor,
          states: states,
          onPressed: save,
          child: const Text('b'),
        );

    testWidgets('constructor parameters take dynamic colors and expand them per environment', (WidgetTester tester) async {
      await expectExpanded(tester, (ResolvedEnvironment e) => inEnvironment(e, button(color: eight)),
          what: 'color', where: (BState s) => !s.disabled);
      await expectExpanded(tester, (ResolvedEnvironment e) => inEnvironment(e, button(disabledColor: eight)),
          what: 'disabledColor', where: (BState s) => s.disabled);
      await expectExpanded(tester, (ResolvedEnvironment e) => inEnvironment(e, button(foregroundColor: eight)),
          what: 'foregroundColor', read: (ButtonStyle s) => s.foregroundColor);
      await expectExpanded(tester, (ResolvedEnvironment e) => inEnvironment(e, button(focusColor: eight)),
          what: 'focusColor', read: (ButtonStyle s) => s.focusColor);
      // Painted, no resolveFrom in user code.
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(inEnvironment(e, button(color: eight)));
        expect(paintedBackground(tester, 'b'), variant(eight, e));
      }
    });

    testWidgets('rule styles take dynamic colors (theme, scope, states:) and expand them per environment',
        (WidgetTester tester) async {
      await expectExpanded(
          tester, (ResolvedEnvironment e) => inEnvironment(e, StyleTheme(rules: const <Rule>[eightBackground], child: button())),
          what: 'theme');
      await expectExpanded(
          tester,
          (ResolvedEnvironment e) =>
              inEnvironment(e, StyleTheme(child: StyleScope(rules: const <Rule>[eightBackground], child: button()))),
          what: 'scope');
      await expectExpanded(
          tester, (ResolvedEnvironment e) => inEnvironment(e, button(states: const <ButtonRule>[eightBackground])),
          what: 'states:');
    });

    testWidgets('overriding one environment leaves every other environment unchanged (theme rule and states:)',
        (WidgetTester tester) async {
      const Color override = Color(0xFF00FF00);
      const ButtonRule darkHc = ButtonRule(
          ButtonWhen(brightness: <Brightness>{Brightness.dark}, highContrast: true),
          style: ButtonStyle(backgroundColor: override));
      Widget base(ResolvedEnvironment e, {List<Rule> extraTheme = const <Rule>[], bool viaStates = false}) => inEnvironment(
          e,
          StyleTheme(
              rules: <Rule>[eightBackground, ...extraTheme],
              child: button(states: <ButtonRule>[if (viaStates) darkHc])));
      final List<Probe> plain = await probeButtons(tester, base, ids: <String>['b']);
      for (final bool viaStates in <bool>[false, true]) {
        final List<Probe> over = await probeButtons(
            tester,
            (ResolvedEnvironment e) => base(e, extraTheme: viaStates ? const <Rule>[] : const <Rule>[darkHc], viaStates: viaStates),
            ids: <String>['b']);
        forPairs(over, plain, (Probe x, Probe y) {
          if (isDark(x.env) && x.env.highContrast) {
            expect(x.style.backgroundColor, override, reason: x.name);
            expect(blank(x.style, background: true), blank(y.style, background: true), reason: x.name);
          } else {
            expect(x.style, y.style, reason: '${x.name} (via ${viaStates ? 'states:' : 'theme'})');
            expect(x.style.backgroundColor, variant(eight, x.env));
          }
        });
      }
    });

    testWidgets('omitting environment dims in the When of a rule with a dynamic color covers all 8 slots',
        (WidgetTester tester) async {
      await expectExpanded(
          tester, (ResolvedEnvironment e) => inEnvironment(e, StyleTheme(rules: const <Rule>[eightBackground], child: button())),
          what: 'env-free When');
    });

    testWidgets(
        'specifying an environment condition in When takes only the dynamic color\'s slots inside that condition',
        (WidgetTester tester) async {
      const ButtonRule darkEight = ButtonRule(ButtonWhen(brightness: <Brightness>{Brightness.dark}),
          style: ButtonStyle(backgroundColor: eight));
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(inEnvironment(e, StyleTheme(rules: const <Rule>[darkEight], child: button())));
        expect(tester.takeException(), isNull);
        final Finder f = find.byKey(const ValueKey<String>('b'));
        final ButtonStyle s = tester.widget<Button>(f).resolveStyle(tester.element(f));
        expect(s.backgroundColor, isDark(e) ? variant(eight, e) : variant(CupertinoColors.systemBlue, e), reason: envName(e));
      }
    });
  });

  // -------------------------------------------------------------------------
  // FAQ: Will `WidgetStateProperty` in the framework be deprecated?
  //
  // This proposal does not modify `flutter/framework`. Individual component constructors can choose
  // whether to accept map-backed `WidgetStateProperty` instances (`WidgetStateProperty.fromMap`, excluding
  // opaque `resolveWith` closures) as a shorthand to avoid passing five or six separate parameters for
  // a single color; the framework expands the map into rules. Theme `style` objects do not accept `WidgetStateProperty`.
  group('FAQ: WidgetStateProperty', () {
    final WidgetStateMouseCursor cursorMap = WidgetStateMouseCursor.fromMap(<WidgetStatesConstraint, MouseCursor>{
      WidgetState.disabled: SystemMouseCursors.forbidden,
      WidgetState.pressed: SystemMouseCursors.grabbing,
      WidgetState.any: SystemMouseCursors.click,
    });

    testWidgets('a constructor parameter takes a fromMap value and expands it into rules', (WidgetTester tester) async {
      final Button b = Button(key: const ValueKey<String>('b'), mouseCursor: cursorMap, onPressed: save, child: const Text('b'));
      final List<ButtonRule> rules = b.callSiteRules();
      expect(rules.length, greaterThan(1), reason: 'one rule per merged state cube');
      for (final ButtonRule r in rules) {
        expect(r.style.mouseCursor, isNot(isA<WidgetStateProperty<Object?>>()));
      }
      final List<Probe> probes = await probeButtons(tester, (ResolvedEnvironment e) => inEnvironment(e, b), ids: <String>['b']);
      for (final Probe p in probes) {
        expect(
            p.style.mouseCursor,
            p.state.disabled
                ? SystemMouseCursors.forbidden
                : p.state.pressed
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.click,
            reason: p.name);
      }
      // The switch takes map-form colors through its helper.
      await tester.pumpWidget(inEnvironment(allEnvironments.first, const SizedBox()));
      final BuildContext ctx = tester.element(find.byType(SizedBox));
      final Switch sw = Switch(
        value: true,
        onChanged: (bool _) {},
        states: switchRulesFromWidgetStates(
          trackOutlineColor: WidgetStateProperty<Color?>.fromMap(<WidgetStatesConstraint, Color?>{
            WidgetState.selected & WidgetState.focused: const Color(0xFF00FF00),
            WidgetState.selected: const Color(0xFFFF0000),
          }),
        ),
      );
      expect(sw.resolveStyle(ctx, selected: true).trackOutlineColor, const Color(0xFFFF0000));
      expect(sw.resolveStyle(ctx, selected: true, focused: true).trackOutlineColor, const Color(0xFF00FF00));
    });

    testWidgets('a resolveWith closure is rejected', (WidgetTester tester) async {
      expect(
          () => Button(
                  mouseCursor: WidgetStateMouseCursor.resolveWith((Set<WidgetState> _) => SystemMouseCursors.click),
                  onPressed: save,
                  child: const Text('b'))
              .callSiteRules(),
          throwsArgumentError);
      expect(
          () => switchRulesFromWidgetStates(
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> _) => const Color(0xFF000000))),
          throwsArgumentError);
    });

    testWidgets('a theme style does not take it', (WidgetTester tester) async {
      final WidgetStateColor colorMap =
          WidgetStateColor.fromMap(<WidgetStatesConstraint, Color>{WidgetState.any: const Color(0xFFFF0000)});
      expect(() => ButtonStyle(backgroundColor: colorMap), throwsAssertionError);
      expect(() => ButtonStyle(foregroundColor: colorMap), throwsAssertionError);
      expect(() => ButtonStyle(mouseCursor: cursorMap), throwsAssertionError);
      expect(() => SwitchStyle(trackColor: colorMap), throwsAssertionError);
    });

    testWidgets('per component: Button\'s color parameters do not take a WidgetStateColor (only mouseCursor takes fromMap)',
        (WidgetTester tester) async {
      final WidgetStateColor colorMap =
          WidgetStateColor.fromMap(<WidgetStatesConstraint, Color>{WidgetState.any: const Color(0xFFFF0000)});
      expect(
          () => Button(appearance: ButtonAppearance.filled, color: colorMap, onPressed: save, child: const Text('b'))
              .callSiteRules(),
          throwsAssertionError);
      expect(() => Button(foregroundColor: colorMap, onPressed: save, child: const Text('b')).callSiteRules(),
          throwsAssertionError);
    });
  });

  // -------------------------------------------------------------------------
  // FAQ: What about existing `ThemeExtension` usage?
  //
  // Global settings let developers register custom token groups for brand colors, semantic colors, and
  // other app-specific tokens. You can reference these groups inside component `derive` blocks or read
  // them directly outside components, and configure them by brightness or other environment dimensions—covering
  // the use cases of `ThemeExtension`.
  group('FAQ: custom token groups', () {
    testWidgets('a custom group: referenced in a derive, read outside components, configured per brightness',
        (WidgetTester tester) async {
      final List<Rule> rules = <Rule>[
        brandTeal,
        TokenRule.group(brandGroup, BrandPalettes.purple, when: const TokenWhen(brightness: <Brightness>{Brightness.dark})),
        themeEnabledRule,
      ];
      for (final ResolvedEnvironment e in allEnvironments) {
        await tester.pumpWidget(docTree(e, theme: rules, scope: null));
        final Color expected = variant(isDark(e) ? purpleAccent : tealAccent, e);
        expect(paintedBackground(tester, CheckoutPanel.plain), expected, reason: envName(e));
        final BuildContext outside = tester.element(find.byType(Column));
        expect(StyleTheme.tokenOf(outside, Brand.accent), expected);
        expect(StyleTheme.tokenOf(outside, Brand.cornerRadius), isDark(e) ? 18.0 : 6.0);
      }
    });
  });
}

/// Holds a StyleScope whose rules a test changes, above a const panel.
class _ScopeHost extends StatefulWidget {
  const _ScopeHost({super.key, required this.initial});
  final List<Rule> initial;
  @override
  State<_ScopeHost> createState() => _ScopeHostState();
}

class _ScopeHostState extends State<_ScopeHost> {
  late List<Rule> _rules = widget.initial;
  void setRules(List<Rule> r) => setState(() => _rules = r);
  @override
  Widget build(BuildContext context) => StyleScope(rules: _rules, child: const CheckoutPanel());
}
