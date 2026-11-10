// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Compute sources (`ButtonSource.compute`): per-field callback derives with
// a lazy view of the same instance at the same minterm. Theme level and call site, chains through
// other derives, cycles, static analyses, provenance, equality / const,
// and caching across token and environment changes.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc/src/engine/engine.dart'
    show FlatRule, RawRule, Resolved, ShadowedRule, SymbolicStyle, chain, findShadowed, resolveSymbolic;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/resolve_own.dart';

const Color black = Color(0xFF000000);
const Color white = Color(0xFFFFFFFF);
const Color navy = Color(0xFF102040);
const Color yellow = Color(0xFFFDD835);

// Callbacks as top-level functions: their tear-offs are constants.
Color halfForeground(ButtonView s) => s.field(.foregroundColor)!.withAlpha(128);
Color backgroundFromForeground(ButtonView s) => s.field(.foregroundColor)!.withAlpha(60);
Color contrastOn(ButtonView s) => (s.field(.backgroundColor)?.computeLuminance() ?? 1) > 0.5 ? black : white;
Color foregroundFromIcon(ButtonView s) => s.field(.iconTheme)?.color ?? black;
Color backgroundFromFocus(ButtonView s) => s.field(.focusColor) ?? black;
Color thumbFromTrack(SwitchView s) => s.field(.trackColor)!.withAlpha(200);

Color variant(Color c, ResolvedEnvironment e) =>
    cupertinoEnvSplitter.resolve(c, Minterm(EnvDims.all, e.values)) as Color;

Minterm at(ResolvedEnvironment env,
        {ButtonAppearance appearance = ButtonAppearance.plain, bool disabled = false, bool pressed = false, bool focused = false}) =>
    buttonMinterm(
        disabled: disabled, pressed: pressed, focused: focused, appearance: appearance, sizeStyle: ButtonSize.large, env: env);

ButtonStyle resolveButton(StyleNode node, List<ButtonRule> callSite, Minterm m) =>
    ButtonStyle.fromValues(StyleResolver<ButtonField>(buttonStyle).resolve(node, callSite, m));

const List<Rule> halfIconTheme = <Rule>[
  ButtonRule(ButtonWhen(), style: ButtonStyleSpec(iconTheme: .parts(color: .computed(halfForeground)))),
];

/// Counts component builds by key.
final Map<Key, int> builds = <Key, int>{};

class _ConstButton extends StatelessWidget {
  const _ConstButton();
  @override
  Widget build(BuildContext context) =>
      Button(key: const Key('b'), onPressed: () {}, child: const Text('b'));
}

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

  test('theme level: a callback follows the foreground (a TokenRef) in every environment and across theme switches', () {
    StyleNode node = StyleNode.root(rules: halfIconTheme);
    for (final ResolvedEnvironment e in allEnvironments) {
      for (final ButtonAppearance a in ButtonAppearance.values) {
        for (final bool disabled in <bool>[false, true]) {
          final ButtonStyle s = resolveButton(node, const <ButtonRule>[], at(e, appearance: a, disabled: disabled));
          expect(s.iconTheme!.color, s.foregroundColor!.withAlpha(128), reason: '${a.name} disabled=$disabled ${envName(e)}');
        }
      }
      // plain enabled: foreground <- primaryColor (systemBlue) in this environment.
      expect(resolveButton(node, const <ButtonRule>[], at(e)).iconTheme!.color,
          variant(CupertinoColors.systemBlue, e).withAlpha(128));
    }
    // Theme switch: a new token channel re-runs the callback.
    node = StyleNode.root(rules: <Rule>[
      ...halfIconTheme,
      const CupertinoTokenRule(primaryColor: CupertinoColors.systemRed),
    ], previous: node);
    for (final ResolvedEnvironment e in allEnvironments) {
      expect(resolveButton(node, const <ButtonRule>[], at(e)).iconTheme!.color,
          variant(CupertinoColors.systemRed, e).withAlpha(128), reason: envName(e));
    }
    node = StyleNode.root(rules: halfIconTheme, previous: node);
    expect(resolveButton(node, const <ButtonRule>[], at(allEnvironments.first)).iconTheme!.color,
        variant(CupertinoColors.systemBlue, allEnvironments.first).withAlpha(128));
  });

  test('chains: callback <- callback <- TokenRef, FieldRef <- callback, sub-property target <- callback', () {
    final StyleNode node = StyleNode.root();
    const List<ButtonRule> callSite = <ButtonRule>[
      // backgroundColor <- callback reading foregroundColor <- primaryColor.
      ButtonRule(ButtonWhen(), style: ButtonStyleSpec(backgroundColor: .computed(backgroundFromForeground))),
      // focusColor <- callback reading backgroundColor (itself a callback).
      ButtonRule(ButtonWhen(), style: ButtonStyleSpec(focusColor: .computed(defaultButtonFocusColor))),
    ];
    for (final ResolvedEnvironment e in allEnvironments) {
      final ButtonStyle s = resolveButton(node, callSite, at(e, focused: true));
      final Color primary = variant(CupertinoColors.systemBlue, e);
      expect(s.backgroundColor, primary.withAlpha(60), reason: envName(e));
      expect(s.focusColor, cupertinoFocusRingColor(primary.withAlpha(60)), reason: envName(e));
    }
    // foregroundColor <- callback (reading the call site's background);
    // text and icon (default FieldRefs) follow the callback's result.
    for (final (Color bg, Color expected) in <(Color, Color)>[(navy, white), (yellow, black)]) {
      final List<ButtonRule> rules = <ButtonRule>[
        ...Button.filled(color: bg, onPressed: () {}, child: const SizedBox()).callSiteRules(),
        const ButtonRule(ButtonWhen(), style: ButtonStyleSpec(foregroundColor: .computed(contrastOn))),
      ];
      final ButtonStyle s = resolveButton(node, rules, at(allEnvironments.first, appearance: ButtonAppearance.filled));
      expect(s.foregroundColor, expected);
      expect(s.textStyle!.color, expected);
      expect(s.iconTheme!.color, expected);
    }
    // textStyle.color (a sub-property target) <- callback.
    final ButtonStyle s = resolveButton(
        node,
        const <ButtonRule>[ButtonRule(ButtonWhen(), style: ButtonStyleSpec(textStyle: .parts(color: .computed(halfForeground))))],
        at(allEnvironments.first));
    expect(s.textStyle!.color, s.foregroundColor!.withAlpha(128));
    expect(s.textStyle!.fontSize, 17.0, reason: 'the rest of the text style is kept');
  });

  test('a cycle through callbacks and/or field references throws a RuleError naming it', () {
    final StyleNode node = StyleNode.root();
    // foregroundColor <- callback reading iconTheme; iconTheme.color <-
    // FieldRef(foregroundColor) (the default follow derive).
    expect(
        () => resolveButton(node,
            const <ButtonRule>[ButtonRule(ButtonWhen(), style: ButtonStyleSpec(foregroundColor: .computed(foregroundFromIcon)))],
            at(allEnvironments.first)),
        throwsA(isA<RuleError>().having((RuleError e) => e.message, 'message',
            allOf(contains('derive cycle'), contains('foregroundColor'), contains('iconTheme')))));
    // Callbacks only: backgroundColor <- focusColor <- backgroundColor.
    expect(
        () => resolveButton(
            node,
            const <ButtonRule>[
              ButtonRule(ButtonWhen(), style: ButtonStyleSpec(backgroundColor: .computed(backgroundFromFocus))),
              ButtonRule(ButtonWhen(), style: ButtonStyleSpec(focusColor: .computed(defaultButtonFocusColor))),
            ],
            at(allEnvironments.first)),
        throwsA(isA<RuleError>().having((RuleError e) => e.message, 'message',
            allOf(contains('derive cycle'), matches(RegExp(r'(backgroundColor <- focusColor <- backgroundColor|'
                r'focusColor <- backgroundColor <- focusColor)'))))));
  });

  test('static analyses treat a compute source as a derive on its field under its condition', () {
    final List<FlatRule<ButtonField>> flat = chain<ButtonField>(<List<RawRule<ButtonField>>>[
      buttonStyle.defaults,
      const ButtonRule(ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.tinted}),
              label: 'contrast', style: ButtonStyleSpec(foregroundColor: .computed(contrastOn)))
          .toRaws(),
    ], spec: buttonStyle.spec, splitter: cupertinoEnvSplitter);
    final Map<Minterm, Resolved<ButtonField>> table = <Minterm, Resolved<ButtonField>>{};
    for (final Minterm m in buttonStyle.spec.minterms()) {
      final SymbolicStyle<ButtonField> s =
          resolveSymbolic(flat, m, buttonStyle.spec.fields, composites: buttonStyle.spec.composites);
      table[m] = Resolved<ButtonField>(const <ButtonField, Object>{}, s.winners, s.contributors);
      final bool tinted = m[ButtonDims.appearance] == ButtonAppearance.tinted;
      expect(s.winners[ButtonField.foregroundColor]!.label == 'contrast', tinted, reason: '$m');
    }
    // Still not shadowed: each default foreground rule wins outside tinted.
    expect(findShadowed(buttonStyle.spec, flat, table), isEmpty);
    // Under ButtonWhen() the callback always writes the field: every
    // default foreground rule is shadowed (no fall-through).
    final List<FlatRule<ButtonField>> all = chain<ButtonField>(<List<RawRule<ButtonField>>>[
      buttonStyle.defaults,
      const ButtonRule(ButtonWhen(), style: ButtonStyleSpec(foregroundColor: .computed(contrastOn))).toRaws(),
    ], spec: buttonStyle.spec, splitter: cupertinoEnvSplitter);
    final Map<Minterm, Resolved<ButtonField>> allTable = <Minterm, Resolved<ButtonField>>{
      for (final Minterm m in buttonStyle.spec.minterms())
        m: () {
          final SymbolicStyle<ButtonField> s =
              resolveSymbolic(all, m, buttonStyle.spec.fields, composites: buttonStyle.spec.composites);
          return Resolved<ButtonField>(const <ButtonField, Object>{}, s.winners, s.contributors);
        }(),
    };
    final List<ShadowedRule<ButtonField>> shadowed = findShadowed(buttonStyle.spec, all, allTable);
    expect(shadowed.map((ShadowedRule<ButtonField> r) => r.field).toSet(), <ButtonField>{ButtonField.foregroundColor});
    expect(shadowed.map((ShadowedRule<ButtonField> r) => r.rule.provider).toSet(), <int>{0});
  });

  test('provenance names the compute source\'s rule (provider + rule)', () {
    final StyleNode node = StyleNode.root(rules: halfIconTheme);
    final Map<ButtonField, String> src = StyleResolver<ButtonField>(buttonStyle).debugSources(
        node,
        const <ButtonRule>[ButtonRule(ButtonWhen(), style: ButtonStyleSpec(backgroundColor: .computed(backgroundFromForeground)))],
        at(allEnvironments.first));
    expect(src[ButtonField.backgroundColor], 'computed rule #0 (call site)');
    expect(src[ButtonField.iconTheme], contains('<- color: computed rule #0 (theme)'));
  });

  test('equality: a static tear-off keeps a rule const and equal; an inline closure does not', () {
    const List<Rule> a = <Rule>[
      ButtonRule(ButtonWhen(), style: ButtonStyleSpec(focusColor: .computed(defaultButtonFocusColor))),
    ];
    const List<Rule> b = <Rule>[
      ButtonRule(ButtonWhen(), style: ButtonStyleSpec(focusColor: .computed(defaultButtonFocusColor))),
    ];
    expect(identical(a, b), isTrue, reason: 'const lists with the same tear-off are canonicalized');
    List<Rule> tearOff() => <Rule>[
          ButtonRule(const ButtonWhen(), style: ButtonStyleSpec(focusColor: ButtonColorSource.computed(defaultButtonFocusColor))),
        ];
    expect(rulesEqual(tearOff(), tearOff()), isTrue);
    expect(rulesEqual(tearOff(), a), isTrue);
    List<Rule> inline(Color c) => <Rule>[
          ButtonRule(const ButtonWhen(), style: ButtonStyleSpec(focusColor: ButtonColorSource.computed((ButtonView s) => c))),
        ];
    expect(rulesEqual(inline(black), inline(black)), isFalse);
  });

  testWidgets('a theme rebuilt with an inline callback loses change detection; a tear-off keeps it', (WidgetTester tester) async {
    late StateSetter rebuild;
    Color captured = black;
    bool useInline = false;
    await tester.pumpWidget(inEnvironment(
        allEnvironments.first,
        StatefulBuilder(builder: (BuildContext context, StateSetter set) {
          rebuild = set;
          final Color c = captured;
          return StyleTheme(
            rules: useInline
                ? <Rule>[ButtonRule(const ButtonWhen(), style: ButtonStyleSpec(focusColor: ButtonColorSource.computed((ButtonView s) => c)))]
                : <Rule>[
                    ButtonRule(const ButtonWhen(), style: ButtonStyleSpec(focusColor: ButtonColorSource.computed(defaultButtonFocusColor))),
                  ],
            child: const _ConstButton(),
          );
        })));
    expect(builds[const Key('b')], 1);
    for (int i = 0; i < 3; i++) {
      rebuild(() {});
      await tester.pump();
    }
    expect(builds[const Key('b')], 1, reason: 'equal theme rules: same node, the button is not notified');
    rebuild(() => useInline = true);
    await tester.pump();
    final int afterSwitch = builds[const Key('b')]!;
    for (int i = 0; i < 3; i++) {
      rebuild(() => captured = black);
      await tester.pump();
    }
    expect(builds[const Key('b')], afterSwitch + 3, reason: 'an inline closure is a new rule on every theme build');
  });

  testWidgets('a theme callback on foregroundColor: pixels equal the same button with the computed color passed directly', (WidgetTester tester) async {
    for (final ResolvedEnvironment env in <ResolvedEnvironment>[allEnvironments.first, allEnvironments[2]]) {
      for (final Interaction i in <Interaction>[Interaction.rest, Interaction.pressed, Interaction.focused]) {
        final Pixels a = await pumpAndCapture(
            tester,
            (FocusNode f) => StyleTheme(
                rules: const <Rule>[ButtonRule(ButtonWhen(), style: ButtonStyleSpec(foregroundColor: .computed(contrastOn)))],
                child: Button.filled(color: navy, focusNode: f, onPressed: () {}, child: const Text('b'))),
            i,
            env: env);
        final Pixels b = await pumpAndCapture(
            tester,
            (FocusNode f) => Button.filled(color: navy, foregroundColor: white, focusNode: f, onPressed: () {}, child: const Text('b')),
            i,
            env: env);
        expect(samePixels(a, b), isTrue, reason: '${i.name} ${envName(env)}');
      }
    }
  });

  testWidgets('the default focus ring written as a theme callback rule gives the default pixels', (WidgetTester tester) async {
    int compared = 0;
    for (final ResolvedEnvironment env in allEnvironments) {
      for (final ButtonAppearance a in ButtonAppearance.values) {
        Widget button(FocusNode f) => Button(appearance: a, focusNode: f, onPressed: () {}, child: const Text('b'));
        final Pixels plain = await pumpAndCapture(tester, button, Interaction.focused, env: env);
        final Pixels themed = await pumpAndCapture(
            tester,
            (FocusNode f) => StyleTheme(rules: const <Rule>[
                  ButtonRule(ButtonWhen(), style: ButtonStyleSpec(focusColor: .computed(defaultButtonFocusColor))),
                ], child: button(f)),
            Interaction.focused,
            env: env);
        expect(samePixels(plain, themed), isTrue, reason: '${a.name} ${envName(env)}');
        compared++;
      }
    }
    expect(compared, 24);
  });

  testWidgets('call site: a Switch callback rule in rules: (both selected ends)', (WidgetTester tester) async {
    await tester.pumpWidget(inEnvironment(allEnvironments.first, const SizedBox()));
    final BuildContext ctx = tester.element(find.byType(SizedBox));
    final Switch sw = Switch(
      value: true,
      onChanged: (bool _) {},
      rules: const <SwitchRule>[SwitchRule(SwitchWhen(), style: SwitchStyleSpec(thumbColor: .computed(thumbFromTrack)))],
    );
    for (final bool selected in <bool>[false, true]) {
      final SwitchStyle s = sw.resolveOwn(ctx, selected: selected);
      expect(s.thumbColor, s.trackColor!.withAlpha(200), reason: 'selected=$selected');
    }
    expect(sw.resolveOwn(ctx, selected: true).thumbColor, variant(CupertinoColors.systemGreen, allEnvironments.first).withAlpha(200));
  });

  testWidgets('a widget with a callback follows theme and environment changes', (WidgetTester tester) async {
    Color iconColor() => IconTheme.of(tester.element(find.byKey(const Key('icon')))).color!;
    Widget app(ResolvedEnvironment env, Color primary) => inEnvironment(
        env,
        StyleTheme(
          rules: <Rule>[
            ...halfIconTheme,
            CupertinoTokenRule(primaryColor: primary),
          ],
          child: Button(onPressed: () {}, child: const SizedBox(key: Key('icon'))),
        ));
    final ResolvedEnvironment light = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.light);
    final ResolvedEnvironment dark = allEnvironments.firstWhere((ResolvedEnvironment e) => e.brightness == Brightness.dark);
    await tester.pumpWidget(app(light, CupertinoColors.systemBlue));
    expect(iconColor(), variant(CupertinoColors.systemBlue, light).withAlpha(128));
    await tester.pumpWidget(app(dark, CupertinoColors.systemBlue));
    expect(iconColor(), variant(CupertinoColors.systemBlue, dark).withAlpha(128));
    await tester.pumpWidget(app(dark, CupertinoColors.systemPink));
    expect(iconColor(), variant(CupertinoColors.systemPink, dark).withAlpha(128));
  });
}
