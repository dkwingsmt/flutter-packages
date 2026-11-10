// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// CupertinoDynamicColor in styles: a way of writing one plain color per
// environment. When a chain is built, every rule holding one is expanded
// into environment-conditioned sub-rules with plain colors (cached per
// authored rule); token values in the global channel likewise. Flat
// parameters, theme rules and token values take the same path, checked in
// all 8 environment combinations. Users may override any environment with
// environment-conditioned rules (plain or dynamic colors); derives follow
// their source per environment, also with an opacity and through a token
// derived per environment (tintedFill). Debug check: a dynamic color
// nested where expansion can't reach fails.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc/src/engine/engine.dart'
    show Dimension, FlatRule, RawRule, Style, Tokens, When, replaceAlpha;
import 'package:cupertino_ui/cupertino_ui.dart' as orig;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoDynamicColor, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/resolve_own.dart';

/// Eight distinct variants.
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

Color variant(CupertinoDynamicColor c, ResolvedEnvironment e) {
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

/// A const theme rule list holding a dynamic color: still const.
const List<Rule> themeWithDynamicColor = <Rule>[
  SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: eight)),
];

ResolvedEnvironment env(Brightness b, {bool hc = false, bool elevated = false}) => ResolvedEnvironment(
    brightness: b,
    highContrast: hc,
    interfaceLevel: elevated ? CupertinoUserInterfaceLevelData.elevated : CupertinoUserInterfaceLevelData.base);

Minterm buttonAt(ResolvedEnvironment e,
        {ButtonAppearance appearance = ButtonAppearance.filled, bool pressed = false}) =>
    buttonMinterm(
        disabled: false,
        pressed: pressed,
        focused: false,
        appearance: appearance,
        sizeStyle: ButtonSize.large,
        env: e);

Map<ButtonField, Object> button(StyleNode node, ResolvedEnvironment e,
        {ButtonAppearance appearance = ButtonAppearance.filled,
        bool pressed = false,
        List<ButtonRule> callSite = const <ButtonRule>[]}) =>
    StyleResolver<ButtonField>(buttonStyle)
        .resolve(node, callSite, buttonAt(e, appearance: appearance, pressed: pressed));

bool isDark(ResolvedEnvironment e) => e.brightness == Brightness.dark;

/// No value in [flat] is environment-dependent after expansion.
void expectNoDynamicValues<F extends Enum>(List<FlatRule<F>> flat) {
  for (final FlatRule<F> r in flat) {
    for (final Object v in <Object>[...r.style.values.values, ...r.sub.values]) {
      expect(cupertinoEnvSplitter.varies(v), isFalse, reason: '${r.label}: $v');
    }
  }
}

void main() {
  test('splitter: picks the variant for every slot, also inside TextStyle, IconThemeData, BorderSide', () {
    const CupertinoEnvSplitter r = cupertinoEnvSplitter;
    expect(r.slots, hasLength(8));
    for (final ResolvedEnvironment e in allEnvironments) {
      final Minterm m = Minterm(EnvDims.all, e.values);
      expect(r.resolve(eight, m), variant(eight, e), reason: envName(e));
      expect((r.resolve(const TextStyle(color: eight, backgroundColor: eight), m) as TextStyle).color, variant(eight, e));
      expect((r.resolve(const IconThemeData(color: eight), m) as IconThemeData).color, variant(eight, e));
      expect((r.resolve(const BorderSide(color: eight, width: 2), m) as BorderSide).color, variant(eight, e));
    }
    expect(r.varies(eight), isTrue);
    expect(r.varies(const TextStyle(color: eight)), isTrue);
    // A plain Color is the ground truth: nothing to expand.
    expect(r.varies(const Color(0xFF000000)), isFalse);
    expect(r.varies(const TextStyle(color: Color(0xFF000000))), isFalse);
  });

  test('the chain holds plain-color sub-rules of the authored rule; the node keeps the authored list', () {
    final StyleNode node = StyleNode.root(rules: themeWithDynamicColor);
    final List<FlatRule<SwitchField>> flat =
        StyleResolver<SwitchField>(switchStyle).debugChain(node, const <SwitchRule>[]);
    expectNoDynamicValues(flat);
    final RawRule<SwitchField> authored = (themeWithDynamicColor.single as SwitchRule).toRaw();
    final List<FlatRule<SwitchField>> theme =
        flat.where((FlatRule<SwitchField> r) => r.provider == 1).toList();
    // eight has eight distinct variants: one sub-rule per slot, all at the
    // authored rule's position, all pointing to it.
    expect(theme, hasLength(8));
    for (final FlatRule<SwitchField> r in theme) {
      expect(r.source, same(authored));
      expect(r.position, theme.first.position);
      expect(r.isExpanded, isTrue);
      expect(r.condition.constraints[SwitchDims.selected], <Object>{true});
      for (final Dimension<Object> d in EnvDims.all) {
        expect(r.condition.constraints[d], hasLength(1), reason: '${r.condition}');
      }
    }
    expect(<Object?>{for (final FlatRule<SwitchField> r in theme) r.style.values[SwitchField.trackColor]},
        <Object?>{for (final ResolvedEnvironment e in allEnvironments) variant(eight, e)});
    // Every default rule is still there (some expanded).
    expect(<int>{for (final FlatRule<SwitchField> r in flat) if (r.provider == 0) r.indexInProvider},
        hasLength(switchStyle.defaults.length));
    expect(identical(node.rules, themeWithDynamicColor), isTrue);
    // The global channel holds plain values only, too.
    expectNoDynamicValues(node.tokens.global.flat);
  });

  test('expansion is cached per authored rule: a second chain build reuses the sub-rules', () {
    final StyleNode a = StyleNode.root(rules: themeWithDynamicColor);
    final StyleNode b = StyleNode.root(rules: themeWithDynamicColor);
    List<FlatRule<SwitchField>> chainOf(StyleNode n) =>
        StyleResolver<SwitchField>(switchStyle).debugChain(n, const <SwitchRule>[]);
    final List<FlatRule<SwitchField>> fa = chainOf(a);
    final List<FlatRule<SwitchField>> fb = chainOf(b);
    expect(identical(fa, fb), isFalse); // two chains (two links)
    expect(fa.length, fb.length);
    for (int i = 0; i < fa.length; i++) {
      // Same expanded condition and style objects: computed once.
      expect(identical(fa[i].condition, fb[i].condition), isTrue, reason: fa[i].label);
      expect(identical(fa[i].style, fb[i].style), isTrue, reason: fa[i].label);
      // The defaults list is flattened once: the same FlatRule objects.
      if (fa[i].provider == 0) {
        expect(identical(fa[i], fb[i]), isTrue, reason: fa[i].label);
      }
    }
  });

  test('one const rule resolves per environment; token values are resolved too', () {
    final Tokens tokens = buildTokens(const <TokenGroup>[], const <TokenRule>[]);
    final ComponentStyle<SwitchField> c = switchStyle;
    final StyleNode node = StyleNode.root(rules: themeWithDynamicColor);
    for (final ResolvedEnvironment e in allEnvironments) {
      final Minterm m = switchMinterm(
          disabled: false, selected: true, pressed: false, focused: false, hovered: false, env: e);
      final Map<SwitchField, Object> v =
          StyleResolver<SwitchField>(c).resolve(node, const <SwitchRule>[], m);
      expect(v[SwitchField.trackColor], variant(eight, e), reason: envName(e));
    }
    for (final ResolvedEnvironment e in allEnvironments) {
      final Color p = tokens.read(CupertinoToken.primaryColor, env: Minterm(EnvDims.all, e.values));
      expect(p, variant(orig.CupertinoColors.systemBlue, e));
      expect(p, isNot(isA<CupertinoDynamicColor>()));
    }
  });

  test('opacity on a dynamic token applies per slot, in the global channel and in a component; per-environment '
      'opacity through environment-conditioned token rules', () {
    final Tokens tokens = buildTokens(<TokenGroup>[Brand.group], <TokenRule>[
      ...BrandRule.teal,
      // Internal references inside the global channel, with an opacity.
      Brand.pressedAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.5)),
      // A per-environment opacity is written as token rules per
      // environment (the way tintedFill is defined).
      Brand.onAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.2),
          when: const TokenWhen(brightness: Brightness.light)),
      Brand.onAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.4),
          when: const TokenWhen(brightness: Brightness.dark)),
      Brand.onAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.9),
          when: const TokenWhen(brightness: Brightness.dark, highContrast: true,
              interfaceLevel: CupertinoUserInterfaceLevelData.elevated)),
    ]);
    final CupertinoDynamicColor accent = brandTealAccent;
    double opacityAt(ResolvedEnvironment e) => switch ((isDark(e), e.highContrast, e.interfaceLevel)) {
          (true, true, CupertinoUserInterfaceLevelData.elevated) => 0.9,
          (true, _, _) => 0.4,
          (false, _, _) => 0.2,
        };
    for (final ResolvedEnvironment e in allEnvironments) {
      final Minterm m = Minterm(EnvDims.all, e.values);
      // The accent variants are opaque: multiplying the alpha equals
      // replacing it.
      expect(tokens.read(Brand.pressedAccent, env: m), replaceAlpha(variant(accent, e), 0.5), reason: envName(e));
      expect(tokens.read(Brand.onAccent, env: m), replaceAlpha(variant(accent, e), opacityAt(e)), reason: envName(e));
    }
    // A component derive through the tintedFill token (the tinted default
    // background: one rule, 0.12 light / 0.26 dark in the token rules).
    final StyleNode node = StyleNode.root();
    for (final ResolvedEnvironment e in allEnvironments) {
      final double a = isDark(e) ? 0.26 : 0.12;
      expect(button(node, e, appearance: ButtonAppearance.tinted)[ButtonField.backgroundColor],
          replaceAlpha(variant(orig.CupertinoColors.systemBlue, e), a),
          reason: envName(e));
    }
    // Equal code gives equal (non-const) token rules; the opacity takes
    // part in equality.
    TokenRule pressed(double o) => Brand.pressedAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), o));
    expect(pressed(0.1), pressed(0.1));
    expect(pressed(0.1).hashCode, pressed(0.1).hashCode);
    expect(pressed(0.1), isNot(pressed(0.2)));
    expect(pressed(0.1), isNot(Brand.pressedAccent.setFrom(.fromCustomToken(Brand.accent))));
  });

  test('provenance names the authored rule and, for an expanded sub-rule, the dynamic color and the slot', () {
    const List<Rule> rules = <Rule>[
      ButtonRule(ButtonWhen(), style: ButtonStyle(minimumSize: Size(50, 50))),
      ButtonRule(ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.filled}),
          style: ButtonStyle(backgroundColor: orig.CupertinoColors.systemBlue)),
    ];
    final StyleNode root = StyleNode.root(rules: rules);
    final StyleNode scope = StyleNode.scope(root, rules: const <Rule>[
      ButtonRule(ButtonWhen(), style: ButtonStyle(padding: EdgeInsets.zero)),
    ]);
    final StyleResolver<ButtonField> r = StyleResolver<ButtonField>(buttonStyle);
    final Map<ButtonField, String> dark = r.debugSources(scope, <ButtonRule>[
      const ButtonRule(ButtonWhen(), style: ButtonStyle(focusColor: eight)),
    ], buttonAt(env(Brightness.dark)));
    expect(dark[ButtonField.backgroundColor], 'rule #1 (theme), systemBlue dark normal-contrast slot');
    expect(dark[ButtonField.minimumSize], 'rule #0 (theme)');
    expect(dark[ButtonField.padding], 'rule #0 (scope 1)');
    expect(dark[ButtonField.focusColor], 'rule #0 (call site), eight dark normal-contrast base slot');
    // primaryContrastingColor is plain white: no slot to report.
    expect(dark[ButtonField.foregroundColor],
        'rule #6 "rest" (defaults) <- token primaryContrastingColor: rule #0 "Cupertino defaults" (global)');
    final Map<ButtonField, String> plain =
        r.debugSources(StyleNode.root(), const <ButtonRule>[], buttonAt(env(Brightness.light, hc: true),
            appearance: ButtonAppearance.plain));
    expect(plain[ButtonField.foregroundColor],
        'rule #4 "rest" (defaults) <- token primaryColor: rule #0 "Cupertino defaults" (global), '
        'systemBlue light high-contrast slot');
    // The tinted default: one derive rule reading the tintedFill token,
    // which the dark token rule sets.
    final Map<ButtonField, String> tinted = r.debugSources(StyleNode.root(), const <ButtonRule>[],
        buttonAt(env(Brightness.dark), appearance: ButtonAppearance.tinted));
    expect(tinted[ButtonField.backgroundColor],
        'rule #7 "rest" (defaults) <- token tintedFill: rule #2 "Cupertino derived tokens" (global)');
    // An opacity on a token reference is named.
    final Map<ButtonField, String> withOpacity = r.debugSources(
        StyleNode.root(),
        const <ButtonRule>[
          ButtonRule(ButtonWhen(), style: ButtonStyleSpec(focusColor: ButtonColorSource.opacity(.fromToken(.primaryColor), 0.5))),
        ],
        buttonAt(env(Brightness.dark)));
    expect(withOpacity[ButtonField.focusColor],
        'rule #0 (call site) <- (opacity 0.5) <- token primaryColor: rule #0 "Cupertino defaults" (global), '
        'systemBlue dark normal-contrast slot');
    // A default rule expanded from tertiaryLabel (disabled foreground).
    final Map<ButtonField, String> disabled = r.debugSources(
        StyleNode.root(),
        const <ButtonRule>[],
        buttonMinterm(
            disabled: true,
            pressed: false,
            focused: false,
            appearance: ButtonAppearance.plain,
            sizeStyle: ButtonSize.large,
            env: env(Brightness.dark, elevated: true)));
    expect(disabled[ButtonField.foregroundColor], startsWith('rule #5 "disabled" (defaults), tertiaryLabel dark'));
  });

  group('overriding environments with environment-conditioned rules', () {
    const Color plain = Color(0xFF123456);
    final StyleNode base = StyleNode.root();

    void expectOnly(StyleNode node, bool Function(ResolvedEnvironment) overridden,
        {ButtonAppearance appearance = ButtonAppearance.filled}) {
      for (final ResolvedEnvironment e in allEnvironments) {
        final Map<ButtonField, Object> want = button(base, e, appearance: appearance);
        final Map<ButtonField, Object> got = button(node, e, appearance: appearance);
        if (overridden(e)) {
          expect(got[ButtonField.backgroundColor], plain, reason: envName(e));
          expect(<ButtonField, Object>{...got}..remove(ButtonField.backgroundColor),
              <ButtonField, Object>{...want}..remove(ButtonField.backgroundColor),
              reason: envName(e));
        } else {
          expect(got, want, reason: 'unchanged in ${envName(e)}');
        }
      }
    }

    test('dark only, with a plain Color: every other environment unchanged (all 8 checked)', () {
      expectOnly(
          StyleNode.root(rules: const <Rule>[
            ButtonRule(ButtonWhen(brightness: Brightness.dark),
                style: ButtonStyle(backgroundColor: plain)),
          ]),
          isDark);
    });

    test('dark + high contrast only, with a plain Color: every other environment unchanged', () {
      expectOnly(
          StyleNode.root(rules: const <Rule>[
            ButtonRule(ButtonWhen(brightness: Brightness.dark, highContrast: true),
                style: ButtonStyle(backgroundColor: plain)),
          ]),
          (ResolvedEnvironment e) => isDark(e) && e.highContrast);
      // The same through a rule in rules: on the call site.
      for (final ResolvedEnvironment e in allEnvironments) {
        final Map<ButtonField, Object> got = button(base, e, callSite: const <ButtonRule>[
          ButtonRule(ButtonWhen(brightness: Brightness.dark, highContrast: true),
              style: ButtonStyle(backgroundColor: plain)),
        ]);
        expect(got[ButtonField.backgroundColor],
            isDark(e) && e.highContrast ? plain : button(base, e)[ButtonField.backgroundColor],
            reason: envName(e));
      }
    });

    test('a dynamic color in an environment-conditioned rule takes only the slots inside the condition', () {
      const ButtonRule darkEight = ButtonRule(ButtonWhen(brightness: Brightness.dark),
          style: ButtonStyle(backgroundColor: eight));
      final StyleNode node = StyleNode.root(rules: const <Rule>[darkEight]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(button(node, e)[ButtonField.backgroundColor],
            isDark(e) ? variant(eight, e) : button(base, e)[ButtonField.backgroundColor],
            reason: envName(e));
      }
      final List<FlatRule<ButtonField>> theme = StyleResolver<ButtonField>(buttonStyle)
          .debugChain(node, const <ButtonRule>[])
          .where((FlatRule<ButtonField> r) => r.provider == 1)
          .toList();
      expect(theme, hasLength(4)); // the four dark slots
      for (final FlatRule<ButtonField> r in theme) {
        expect(r.condition.constraints[EnvDims.brightness], <Object>{Brightness.dark});
      }
      // .any: the pressed condition takes all 8 slots, the dark one 4.
      final StyleNode any = StyleNode.root(rules: const <Rule>[
        ButtonRule.whenAny(<ButtonWhen>[
          ButtonWhen(pressed: true),
          ButtonWhen(brightness: Brightness.dark),
        ], style: ButtonStyle(focusColor: eight)),
      ]);
      expect(
          StyleResolver<ButtonField>(buttonStyle)
              .debugChain(any, const <ButtonRule>[])
              .where((FlatRule<ButtonField> r) => r.provider == 1),
          hasLength(12));
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(button(any, e)[ButtonField.focusColor], isDark(e) ? variant(eight, e) : null, reason: envName(e));
        expect(button(any, e, pressed: true)[ButtonField.focusColor], variant(eight, e), reason: envName(e));
      }
      // rules: with a high-contrast condition and a TextStyle color.
      for (final ResolvedEnvironment e in allEnvironments) {
        final TextStyle? t = button(base, e, callSite: const <ButtonRule>[
          ButtonRule(ButtonWhen(highContrast: true), style: ButtonStyle(textStyle: TextStyle(color: eight))),
        ])[ButtonField.textStyle] as TextStyle?;
        // The call-site rule comes after the default text-color derive.
        expect(t?.color, e.highContrast ? variant(eight, e) : button(base, e)[ButtonField.foregroundColor],
            reason: envName(e));
      }
      // Token rules: an environment-conditioned dynamic token value.
      final StyleNode tok = StyleNode.root(rules: <Rule>[
        const TokenRule.raw(TokenWhen(highContrast: true), values: <Token<Object>, Object>{CupertinoToken.primaryColor: eight}),
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(tok.tokens.read(CupertinoToken.primaryColor, env: Minterm(EnvDims.all, e.values)),
            e.highContrast ? variant(eight, e) : variant(orig.CupertinoColors.systemBlue, e),
            reason: envName(e));
      }
    });
  });

  group('derived fields follow their source per environment', () {
    const Color plain = Color(0xFF123456);

    test('textStyle.color and iconTheme.color <- foregroundColor, also when the source is overridden in one environment',
        () {
      final StyleNode node = StyleNode.root(rules: const <Rule>[
        ButtonRule(ButtonWhen(brightness: Brightness.dark, highContrast: true),
            style: ButtonStyle(foregroundColor: plain)),
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        for (final ButtonAppearance a in ButtonAppearance.values) {
          final Map<ButtonField, Object> v = button(node, e, appearance: a);
          final Color fg = v[ButtonField.foregroundColor]! as Color;
          expect((v[ButtonField.textStyle]! as TextStyle).color, fg, reason: '${a.name} ${envName(e)}');
          expect((v[ButtonField.iconTheme]! as IconThemeData).color, fg, reason: '${a.name} ${envName(e)}');
          if (isDark(e) && e.highContrast) {
            expect(fg, plain);
          } else if (a != ButtonAppearance.filled) {
            expect(fg, variant(orig.CupertinoColors.systemBlue, e), reason: '${a.name} ${envName(e)}');
          }
        }
      }
    });

    test('token references with an opacity follow their token per environment, also when the token is overridden in one', () {
      // The tinted default background, with primaryColor overridden in
      // dark + high contrast only.
      final StyleNode node = StyleNode.root(rules: <Rule>[
        const TokenRule.raw(TokenWhen(brightness: Brightness.dark, highContrast: true),
            values: <Token<Object>, Object>{CupertinoToken.primaryColor: plain}),
        // A user derive with an opacity on the switch track.
        const SwitchRule(SwitchWhen(selected: true),
            style: SwitchStyleSpec(trackColor: SwitchColorSource.opacity(.fromToken(.primaryColor), 0.5))),
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final Color primary = isDark(e) && e.highContrast ? plain : variant(orig.CupertinoColors.systemBlue, e);
        expect(button(node, e, appearance: ButtonAppearance.tinted)[ButtonField.backgroundColor],
            replaceAlpha(primary, isDark(e) ? 0.26 : 0.12),
            reason: envName(e));
        final Map<SwitchField, Object> sw = StyleResolver<SwitchField>(switchStyle).resolve(
            node,
            const <SwitchRule>[],
            switchMinterm(disabled: false, selected: true, pressed: false, focused: false, hovered: false, env: e));
        expect(sw[SwitchField.trackColor], replaceAlpha(primary, 0.5), reason: envName(e));
      }
    });
  });

  testWidgets('flat parameter and theme rule: same path, all 8 environments, pixels equal the original with the plain variant',
      (WidgetTester tester) async {
    for (final ResolvedEnvironment e in allEnvironments) {
      final Color plain = variant(eight, e);
      final Pixels reference = await pumpAndCapture(
          tester, (FocusNode f) => orig.CupertinoSwitch(value: true, activeTrackColor: plain, focusNode: f, onChanged: (bool _) {}),
          Interaction.rest, env: e);
      final Pixels flat = await pumpAndCapture(
          tester, (FocusNode f) => Switch(value: true, activeTrackColor: eight, focusNode: f, onChanged: (bool _) {}),
          Interaction.rest, env: e);
      final Pixels themed = await pumpAndCapture(
          tester,
          (FocusNode f) => StyleTheme(
              rules: themeWithDynamicColor,
              child: Switch(value: true, focusNode: f, onChanged: (bool _) {})),
          Interaction.rest,
          env: e);
      expect(samePixels(flat, reference), isTrue, reason: 'flat ${envName(e)}');
      expect(samePixels(themed, reference), isTrue, reason: 'theme ${envName(e)}');
    }
  });

  testWidgets('a dynamic Brand token resolves per environment through a derive', (WidgetTester tester) async {
    for (final ResolvedEnvironment e in allEnvironments) {
      late SwitchStyle s;
      final Switch sw = Switch(value: true, onChanged: (bool _) {});
      await tester.pumpWidget(inEnvironment(
          e,
          StyleTheme(
            groups: <TokenGroup>[Brand.group],
            rules: <Rule>[
              ...BrandRule.teal,
              const SwitchRule(SwitchWhen(selected: true), style: SwitchStyleSpec(trackColor: .fromCustomToken(Brand.accent))),
            ],
            child: Builder(builder: (BuildContext context) {
              s = sw.resolveOwn(context, selected: true);
              return sw;
            }),
          )));
      expect(s.trackColor, variant(brandTealAccent, e), reason: envName(e));
    }
  });

  test('styles reject closure-style values (debug assert)', () {
    final WidgetStateColor mapped = WidgetStateColor.fromMap(<WidgetStatesConstraint, Color>{WidgetState.any: const Color(0xFF000000)});
    final WidgetStateColor closure = WidgetStateColor.resolveWith((Set<WidgetState> _) => const Color(0xFF000000));
    expect(() => SwitchStyle(trackColor: mapped), throwsAssertionError);
    expect(() => ButtonStyle(backgroundColor: closure), throwsAssertionError);
    expect(() => ButtonStyle(mouseCursor: WidgetStateMouseCursor.resolveWith((Set<WidgetState> _) => MouseCursor.defer)),
        throwsAssertionError);
    // Dynamic colors are data.
    expect(const SwitchStyle(trackColor: eight).trackColor, eight);
  });

  test('the const rule list with a dynamic color is canonicalised (really const)', () {
    const List<Rule> again = <Rule>[
      SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: eight)),
    ];
    expect(identical(again, themeWithDynamicColor), isTrue);
    final RawRule<SwitchField> raw = (themeWithDynamicColor.single as SwitchRule).toRaw();
    expect(identical(raw, (again.single as SwitchRule).toRaw()), isTrue);
  });


  group('debug check: dynamic colors nested where expansion does not reach', () {
    test('the splitter finds them by path', () {
      const CupertinoEnvSplitter r = cupertinoEnvSplitter;
      expect(r.debugUnresolved(const <BoxShadow>[BoxShadow(color: Color(0xFF000000)), BoxShadow(color: eight)]),
          'List<BoxShadow>[1].color');
      expect(r.debugUnresolved(const LinearGradient(colors: <Color>[Color(0xFF000000), eight])), 'LinearGradient.colors[1]');
      expect(r.debugUnresolved(const RoundedRectangleBorder(side: BorderSide(color: eight))),
          'RoundedRectangleBorder.side.color');
      expect(r.debugUnresolved(const TextStyle(color: eight, shadows: <Shadow>[Shadow(color: eight)])),
          'TextStyle.shadows[0].color');
      expect(r.debugUnresolved(const BoxDecoration(border: Border(left: BorderSide(color: eight)))),
          'BoxDecoration.border.left.color');
      // Places expansion handles, and plain colors anywhere.
      expect(r.debugUnresolved(eight), isNull);
      expect(r.debugUnresolved(const TextStyle(color: eight, decorationColor: eight, backgroundColor: eight)), isNull);
      expect(r.debugUnresolved(const IconThemeData(color: eight)), isNull);
      expect(r.debugUnresolved(const BorderSide(color: eight)), isNull);
      expect(r.debugUnresolved(const <BoxShadow>[BoxShadow(color: Color(0xFF000000))]), isNull);
    });

    test('a style value with one fails at chain build, with or without an environment condition', () {
      expect(
          () => StyleResolver<ButtonField>(buttonStyle).resolve(
              StyleNode.root(rules: const <Rule>[
                ButtonRule(ButtonWhen(),
                    style: ButtonStyle(textStyle: TextStyle(shadows: <Shadow>[Shadow(color: eight)]))),
              ]),
              const <ButtonRule>[],
              buttonAt(env(Brightness.light))),
          throwsA(isA<AssertionError>().having((AssertionError e) => '${e.message}', 'message',
              allOf(contains('rule #0 (theme)'), contains('textStyle'), contains('TextStyle.shadows[0].color')))));
      expect(
          () => StyleResolver<ButtonField>(buttonStyle).resolve(
              StyleNode.root(),
              const <ButtonRule>[
                ButtonRule(ButtonWhen(),
                    style: ButtonStyle(iconTheme: IconThemeData(shadows: <Shadow>[Shadow(color: eight)]))),
              ],
              buttonAt(env(Brightness.light))),
          throwsA(isA<AssertionError>().having(
              (AssertionError e) => '${e.message}', 'message', contains('IconThemeData.shadows[0].color'))));
    });

    test('defaults, the global channel and a widget build are checked too', () {
      Matcher fails(List<String> parts) => throwsA(isA<AssertionError>().having(
          (AssertionError e) => '${e.message}', 'message', allOf(<Matcher>[for (final String p in parts) contains(p)])));
      final ComponentStyle<ButtonField> badDefaults = ComponentStyle<ButtonField>(
        channel: ButtonRule,
        spec: buttonStyle.spec,
        defaults: <RawRule<ButtonField>>[
          ...buttonStyle.defaults,
          RawRule<ButtonField>(When(<Dimension<Object>, Object>{EnvDims.brightness: <Brightness>{Brightness.dark}}),
              style: const Style<ButtonField>(<ButtonField, Object>{
                ButtonField.textStyle: TextStyle(shadows: <Shadow>[Shadow(color: eight)]),
              }),
              label: 'dark shadow'),
        ],
      );
      expect(
          () => StyleResolver<ButtonField>(badDefaults)
              .resolve(StyleNode.root(), const <ButtonRule>[], buttonAt(env(Brightness.light))),
          fails(<String>['rule #${buttonStyle.defaults.length} "dark shadow" (defaults)', 'TextStyle.shadows[0].color']));
      expect(
          () => StyleNode.root(rules: <Rule>[
                const TokenRule.raw(TokenWhen(), values: <Token<Object>, Object>{
                  CupertinoToken.textStyle: TextStyle(shadows: <Shadow>[Shadow(color: eight)]),
                }),
              ]),
          // The library's token rules come first (rules #0 to #2).
          fails(<String>['rule #3 (global)', 'textStyle', 'TextStyle.shadows[0].color']));
    });

    testWidgets('a widget build reports the failure', (WidgetTester tester) async {
      await tester.pumpWidget(inEnvironment(
          env(Brightness.dark),
          const StyleTheme(
            rules: <Rule>[
              ButtonRule(ButtonWhen(),
                  style: ButtonStyle(textStyle: TextStyle(shadows: <Shadow>[Shadow(color: eight)]))),
            ],
            child: Button(onPressed: null, child: SizedBox()),
          )));
      expect(tester.takeException(), isA<AssertionError>());
    });
  });
}
