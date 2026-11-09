// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The derive API: typed sources (`ButtonSource`, `ButtonColorSource` with
// the `.opacity` / `.opaque` transforms, the composite source classes with
// `.parts`), the rule entry points (`.when` / `.always` / `.whenAny` and
// the full-name form), the `style:` payload (`.values` / `.derive` and the
// full class names), callbacks reading fields and tokens through
// `ButtonView`, and app tokens through `.fromCustomToken`.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc/src/engine/engine.dart'
    show Derive, RawRule, Style, SubProp, chain, replaceAlpha, resolve;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const Color red = Color(0xFFE53935);
const Color blue = Color(0xFF1E88E5);
const Color green = Color(0xFF43A047);
const Color halfRed = Color(0x80E53935);
const Color clearRed = Color(0x00E53935);

Color variant(Color c, ResolvedEnvironment e) =>
    cupertinoEnvSplitter.resolve(c, Minterm(EnvDims.all, e.values)) as Color;

Minterm at(ResolvedEnvironment env,
        {ButtonAppearance appearance = ButtonAppearance.plain,
        ButtonSize size = ButtonSize.large,
        bool disabled = false,
        bool pressed = false,
        bool focused = false}) =>
    buttonMinterm(disabled: disabled, pressed: pressed, focused: focused, appearance: appearance, sizeStyle: size, env: env);

ButtonStyle resolveButton(StyleNode node, List<ButtonRule> callSite, Minterm m) =>
    ButtonStyle.fromValues(StyleResolver<ButtonField>(buttonStyle).resolve(node, callSite, m));

/// Every button minterm resolves the same for [a] and [b] (call-site rule
/// lists under [node]); returns the number of minterms compared.
int expectSameEverywhere(List<ButtonRule> a, List<ButtonRule> b, {StyleNode? node}) {
  final StyleNode n = node ?? StyleNode.root();
  final StyleResolver<ButtonField> r = StyleResolver<ButtonField>(buttonStyle);
  int compared = 0;
  for (final Minterm m in buttonStyle.spec.minterms()) {
    expect(Map<ButtonField, Object>.of(r.resolve(n, b, m)), Map<ButtonField, Object>.of(r.resolve(n, a, m)), reason: '$m');
    compared++;
  }
  return compared;
}

// ---- "Mostly values, one derive" ---------------------------------------------

const ButtonWhen tintedEnabled = ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.tinted}, disabled: false);
const CupertinoDynamicColor indigo = CupertinoColors.systemIndigo;

/// (a) One ButtonStyleSpec: the literal fields wrapped in `.value`, one
/// derive.
const List<ButtonRule> oneSpec = <ButtonRule>[
  ButtonRule(tintedEnabled,
      style: ButtonStyleSpec(
        foregroundColor: .value(indigo),
        padding: .value(EdgeInsets.all(8)),
        borderRadius: .value(BorderRadius.all(Radius.circular(4))),
        backgroundColor: .opacity(.fromField(.foregroundColor), 0.2),
      )),
];

/// (b) Two rules under the same condition: the derive in a ButtonStyleSpec,
/// the values in a ButtonStyle.
const List<ButtonRule> twoRules = <ButtonRule>[
  ButtonRule(tintedEnabled, style: ButtonStyleSpec(backgroundColor: .opacity(.fromField(.foregroundColor), 0.2))),
  ButtonRule(tintedEnabled,
      style: ButtonStyle(
        foregroundColor: indigo,
        padding: EdgeInsets.all(8),
        borderRadius: BorderRadius.all(Radius.circular(4)),
      )),
];

/// (c) A region constructor for the foreground, then a rule with the other
/// values and the derive.
const List<ButtonRule> regionsAndDerive = <ButtonRule>[
  ButtonRule.foregroundColor(tintedEnabled: indigo),
  ButtonRule(tintedEnabled,
      style: ButtonStyleSpec(
        padding: .value(EdgeInsets.all(8)),
        borderRadius: .value(BorderRadius.all(Radius.circular(4))),
        backgroundColor: .opacity(.fromField(.foregroundColor), 0.2),
      )),
];

/// (a) and (b) in the short spellings: `.when`, `.derive`, `.values`.
const List<ButtonRule> oneSpecShort = <ButtonRule>[
  .when(
      appearance: {.tinted},
      disabled: false,
      style: .derive(
        foregroundColor: .value(indigo),
        padding: .value(.all(8)),
        borderRadius: .value(.all(.circular(4))),
        backgroundColor: .opacity(.fromField(.foregroundColor), 0.2),
      )),
];
const List<ButtonRule> twoRulesShort = <ButtonRule>[
  .when(appearance: {.tinted}, disabled: false, style: .derive(backgroundColor: .opacity(.fromField(.foregroundColor), 0.2))),
  .when(
      appearance: {.tinted},
      disabled: false,
      style: .values(foregroundColor: indigo, padding: .all(8), borderRadius: .all(.circular(4)))),
];

// ---- Callbacks ---------------------------------------------------------------

Color focusFromToken(ButtonView s) => s.token(.primaryColor).withAlpha(10);
Color backgroundFromBrand(ButtonView s) => s.customToken(Brand.accent);
Color backgroundFromFocus(ButtonView s) => s.field(.focusColor) ?? red;
Color iconFromFieldAndToken(ButtonView s) => Color.lerp(s.field(.foregroundColor), s.token(.tintedFill), 0.5)!;
Color translucentRed(ButtonView s) => halfRed;

/// Counts component builds by key.
final Map<Key, int> builds = <Key, int>{};

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

  group('mostly values, one derive', () {
    test('every spelling resolves identically in every minterm and environment', () {
      expect(expectSameEverywhere(oneSpec, twoRules), 576);
      expect(expectSameEverywhere(oneSpec, regionsAndDerive), 576);
      expect(expectSameEverywhere(oneSpec, oneSpecShort), 576);
      expect(expectSameEverywhere(oneSpec, twoRulesShort), 576);
    });

    test('and give the intended values', () {
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle s = resolveButton(StyleNode.root(), oneSpec, at(e, appearance: ButtonAppearance.tinted));
        final Color fg = variant(indigo, e);
        expect(s.foregroundColor, fg, reason: envName(e));
        expect(s.backgroundColor, applyOpacity(fg, 0.2), reason: envName(e));
        expect(s.textStyle!.color, fg, reason: envName(e));
        expect(s.padding, const EdgeInsets.all(8));
        // Outside the condition the defaults stay.
        final ButtonStyle filled = resolveButton(StyleNode.root(), oneSpec, at(e, appearance: ButtonAppearance.filled));
        expect(filled.padding, const EdgeInsets.symmetric(vertical: 16, horizontal: 20));
      }
    });

    test('const rules are canonicalized; equal code is ==; the short spellings equal the full names', () {
      const ButtonRule x = ButtonRule(tintedEnabled,
          style: ButtonStyleSpec(
            padding: .value(EdgeInsets.all(8)),
            backgroundColor: .opacity(.fromField(.foregroundColor), 0.2),
            textStyle: .parts(color: .fromToken(.primaryColor)),
          ));
      const ButtonRule y = ButtonRule(tintedEnabled,
          style: ButtonStyleSpec(
            padding: .value(EdgeInsets.all(8)),
            backgroundColor: .opacity(.fromField(.foregroundColor), 0.2),
            textStyle: .parts(color: .fromToken(.primaryColor)),
          ));
      expect(identical(x, y), isTrue);
      // Built at run time: equal, same hash.
      ButtonRule built(double opacity) => ButtonRule(tintedEnabled,
          style: ButtonStyleSpec(
            padding: const .value(EdgeInsets.all(8)),
            backgroundColor: .opacity(const .fromField(.foregroundColor), opacity),
            textStyle: const .parts(color: .fromToken(.primaryColor)),
          ));
      expect(built(0.2), x);
      expect(built(0.2).hashCode, x.hashCode);
      expect(built(0.3), isNot(x));
      expect(rulesEqual(<Object>[...twoRules], twoRules), isTrue);
      // `.when` with the dimensions == the full-name form with a ButtonWhen.
      const ButtonRule short = ButtonRule.when(
          appearance: {.tinted},
          disabled: false,
          style: .derive(
            padding: .value(.all(8)),
            backgroundColor: .opacity(.fromField(.foregroundColor), 0.2),
            textStyle: .parts(color: .fromToken(.primaryColor)),
          ));
      expect(short, x);
      expect(short.hashCode, x.hashCode);
      expect(rulesEqual(oneSpecShort, oneSpec), isTrue);
      expect(rulesEqual(twoRulesShort, twoRules), isTrue);
      // `.always` == the full-name form with an empty condition.
      expect(const ButtonRule.always(style: .values(padding: .zero)),
          const ButtonRule(ButtonWhen(), style: ButtonStyle(padding: EdgeInsets.zero)));
      // `.values` is a redirect to ButtonStyle: the same const instance.
      expect(identical(const ButtonStyleSpec.values(backgroundColor: red), const ButtonStyle(backgroundColor: red)), isTrue);
      expect(const ButtonStyleSpec.derive(backgroundColor: .value(red)), const ButtonStyleSpec(backgroundColor: .value(red)));
      // Same result, different spelling: need not be ==.
      expect(const ButtonStyle(backgroundColor: red), isNot(const ButtonStyleSpec(backgroundColor: .value(red))));
      // Transforms take part in equality.
      expect(const ButtonColorSource.opacity(.fromField(.foregroundColor), 0.5),
          isNot(const ButtonColorSource.opacity(.fromField(.foregroundColor), 0.6)));
      expect(const ButtonColorSource.opaque(.fromField(.foregroundColor)),
          isNot(const ButtonColorSource.opacity(.fromField(.foregroundColor), 1)));
      // Equality is by kind and payload, not by runtime type.
      expect(const ButtonColorSource.fromField(.foregroundColor), const ButtonSource<Color>.fromField(.foregroundColor));
    });

    testWidgets('rebuilding a theme with equal (non-const) rules does not notify the button', (WidgetTester tester) async {
      late StateSetter rebuild;
      double opacity = 0.2;
      await tester.pumpWidget(inEnvironment(
          allEnvironments.first,
          StatefulBuilder(builder: (BuildContext context, StateSetter set) {
            rebuild = set;
            return StyleTheme(
              rules: <Rule>[
                ...<ButtonRule>[
                  .always(
                      style: .derive(
                    padding: const .value(.all(8)),
                    backgroundColor: .opacity(const .fromField(.foregroundColor), opacity),
                    iconTheme: const .parts(color: .computed(focusFromToken)),
                    side: .parts(color: .opacity(const .value(red), opacity)),
                  )),
                  .when(pressed: true, style: .values(minimumSize: Size(opacity * 100, 40))),
                ],
                Brand.accent.set(Color.lerp(red, blue, opacity)!),
                BrandRule(cornerRadius: opacity * 10),
              ],
              child: const _KeyedButton(),
            );
          })));
      expect(builds[const Key('b')], 1);
      for (int i = 0; i < 3; i++) {
        rebuild(() {});
        await tester.pump();
      }
      expect(builds[const Key('b')], 1, reason: 'equal rules: the button is not notified');
      rebuild(() => opacity = 0.3);
      await tester.pump();
      expect(builds[const Key('b')], 2, reason: 'a changed opacity is a changed rule');
    });
  });

  group('rule entry points', () {
    test('.when / .always / .whenAny in a typed spread resolve like the full-name rules', () {
      const List<ButtonRule> full = <ButtonRule>[
        ButtonRule(ButtonWhen(pressed: true, appearance: <ButtonAppearance>{ButtonAppearance.filled}),
            style: ButtonStyle(backgroundColor: red)),
        ButtonRule(ButtonWhen(), style: ButtonStyleSpec(iconTheme: ButtonIconStyleSource.parts(color: .value(green)))),
        ButtonRule.whenAny(<ButtonWhen>[ButtonWhen(focused: true), ButtonWhen(disabled: true)],
            style: ButtonStyle(padding: EdgeInsets.zero)),
        ButtonRule(ButtonWhen(brightness: Brightness.dark, highContrast: true),
            style: ButtonStyleSpec(foregroundColor: .opacity(.fromToken(.primaryColor), 0.5))),
      ];
      const List<Rule> theme = <Rule>[
        ...<ButtonRule>[
          .when(pressed: true, appearance: {.filled}, style: .values(backgroundColor: red)),
          .always(style: .derive(iconTheme: .parts(color: .value(green)))),
          .whenAny([ButtonWhen(focused: true), ButtonWhen(disabled: true)], style: .values(padding: .zero)),
          .when(brightness: .dark, highContrast: true, style: .derive(foregroundColor: .opacity(.fromToken(.primaryColor), 0.5))),
        ],
      ];
      expect(rulesEqual(theme, full), isTrue);
      expect(expectSameEverywhere(const <ButtonRule>[], const <ButtonRule>[], node: StyleNode.root(rules: theme)), 576);
      final StyleResolver<ButtonField> r = StyleResolver<ButtonField>(buttonStyle);
      final StyleNode a = StyleNode.root(rules: theme);
      final StyleNode b = StyleNode.root(rules: full);
      for (final Minterm m in buttonStyle.spec.minterms()) {
        expect(Map<ButtonField, Object>.of(r.resolve(a, const <ButtonRule>[], m)),
            Map<ButtonField, Object>.of(r.resolve(b, const <ButtonRule>[], m)),
            reason: '$m');
      }
      expect(const ButtonRule.always(style: ButtonStyle()).when, const ButtonWhen());
      expect(full[2].when, isNull);
    });

    test('switch rules have the same entry points', () {
      const List<SwitchRule> short = <SwitchRule>[
        .when(selected: true, style: .derive(trackColor: .opacity(.fromField(.thumbColor), 0.5))),
        .always(style: .values(thumbIconSize: 20)),
        .whenAny([SwitchWhen(pressed: true), SwitchWhen(focused: true)], style: .values(thumbColor: red)),
      ];
      const List<SwitchRule> full = <SwitchRule>[
        SwitchRule(SwitchWhen(selected: true), style: SwitchStyleSpec(trackColor: .opacity(.fromField(.thumbColor), 0.5))),
        SwitchRule(SwitchWhen(), style: SwitchStyle(thumbIconSize: 20)),
        SwitchRule.whenAny(<SwitchWhen>[SwitchWhen(pressed: true), SwitchWhen(focused: true)],
            style: SwitchStyle(thumbColor: red)),
      ];
      expect(rulesEqual(short, full), isTrue);
      final StyleResolver<SwitchField> r = StyleResolver<SwitchField>(switchStyle);
      for (final Minterm m in switchStyle.spec.minterms()) {
        expect(Map<SwitchField, Object>.of(r.resolve(StyleNode.root(), short, m)),
            Map<SwitchField, Object>.of(r.resolve(StyleNode.root(), full, m)),
            reason: '$m');
      }
    });
  });

  group('opacity and opaque', () {
    test('applyOpacity multiplies the alpha and clamps to [0, 1]', () {
      expect(applyOpacity(red, 0.12).toARGB32(), red.withValues(alpha: 31 / 255).toARGB32());
      expect((applyOpacity(halfRed, 0.5).a * 255).round(), 64);
      expect((applyOpacity(halfRed, 1.5).a * 255).round(), 192);
      expect((applyOpacity(halfRed, 3).a * 255).round(), 255);
      expect((applyOpacity(clearRed, 5).a * 255).round(), 0);
      expect(applyOpacity(halfRed, 0).a, 0);
      // A fully opaque source: identical to Color.withOpacity (replace).
      for (final double o in <double>[0.0, 0.12, 0.26, 0.38, 0.5, 1.0]) {
        expect(applyOpacity(red, o).toARGB32(), replaceAlpha(red, o).toARGB32(), reason: '$o');
      }
    });

    test('.opacity multiplies a translucent source; above 1 raises and clamps; transparent stays transparent', () {
      for (final (Color fg, double opacity, int alpha) in <(Color, double, int)>[
        (halfRed, 0.5, 64),
        (halfRed, 1.5, 192),
        (halfRed, 2.0, 255),
        (halfRed, 10.0, 255),
        (clearRed, 4.0, 0),
        (red, 0.38, 97),
      ]) {
        final ButtonStyle s = resolveButton(StyleNode.root(), <ButtonRule>[
          .always(style: .derive(foregroundColor: .value(fg), backgroundColor: .opacity(.fromField(.foregroundColor), opacity))),
        ], at(allEnvironments.first));
        expect((s.backgroundColor!.a * 255).round(), alpha, reason: '$fg x $opacity');
        expect(s.backgroundColor!.toARGB32() & 0xFFFFFF, fg.toARGB32() & 0xFFFFFF, reason: 'rgb kept');
      }
    });

    test('.opaque sets alpha to 1 on translucent and transparent sources; .opacity(.opaque(x), 0.5) is 50%', () {
      for (final Color fg in <Color>[halfRed, clearRed, red]) {
        final ButtonStyle s = resolveButton(StyleNode.root(), <ButtonRule>[
          .always(
              style: .derive(
            foregroundColor: .value(fg),
            backgroundColor: .opaque(.fromField(.foregroundColor)),
            focusColor: .opacity(.opaque(.fromField(.foregroundColor)), 0.5),
          )),
        ], at(allEnvironments.first, focused: true));
        expect(s.backgroundColor!.toARGB32(), 0xFFE53935, reason: '$fg');
        expect(s.focusColor!.toARGB32(), 0x80E53935, reason: '$fg');
      }
      // On a literal (folded when the chain is resolved), a callback and a
      // token (applied at bind time).
      final StyleNode node = StyleNode.root(rules: const <Rule>[CupertinoTokenRule(primaryColor: halfRed)]);
      final ButtonStyle s = resolveButton(node, const <ButtonRule>[
        .always(
            style: .derive(
          backgroundColor: .opaque(.value(clearRed)),
          foregroundColor: .opaque(.computed(translucentRed)),
          focusColor: .opaque(.fromToken(.primaryColor)),
        )),
      ], at(allEnvironments.first, focused: true));
      expect(s.backgroundColor!.toARGB32(), 0xFFE53935);
      expect(s.foregroundColor!.toARGB32(), 0xFFE53935);
      expect(s.focusColor!.toARGB32(), 0xFFE53935);
    });

    test('the filled default makes primary opaque again (the original withOpacity(1.0))', () {
      final StyleNode node = StyleNode.root(rules: const <Rule>[CupertinoTokenRule(primaryColor: halfRed)]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle filled = resolveButton(node, const <ButtonRule>[], at(e, appearance: ButtonAppearance.filled));
        expect(filled.backgroundColor!.toARGB32(), 0xFFE53935, reason: envName(e));
        // The tinted fill keeps multiplying: 0x80 x 0.12 (light), x 0.26 (dark).
        final ButtonStyle tinted = resolveButton(node, const <ButtonRule>[], at(e, appearance: ButtonAppearance.tinted));
        final double fill = e.brightness == Brightness.light ? 0.12 : 0.26;
        expect((tinted.backgroundColor!.a * 255).round(), (255 * (128 / 255 * fill)).round(), reason: envName(e));
      }
    });

    test('a translucent token with .opacity, and a dynamic literal with .opacity per environment', () {
      final StyleNode node = StyleNode.root(rules: const <Rule>[CupertinoTokenRule(primaryColor: halfRed)]);
      for (final (double opacity, int alpha) in <(double, int)>[(0.5, 64), (1.5, 192), (4, 255), (0, 0)]) {
        final ButtonStyle s = resolveButton(node, <ButtonRule>[
          .always(style: .derive(backgroundColor: .opacity(.fromToken(.primaryColor), opacity))),
        ], at(allEnvironments.first));
        expect((s.backgroundColor!.a * 255).round(), alpha, reason: '$opacity');
      }
      // `.opacity(.value(dynamic), x)`: the literal is expanded per
      // environment like any dynamic color, then multiplied.
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle s = resolveButton(StyleNode.root(), const <ButtonRule>[
          .always(
              style: .derive(
            backgroundColor: .opacity(.value(CupertinoColors.systemRed), 0.5),
            side: .parts(color: .opacity(.value(CupertinoColors.systemGreen), 0.25)),
          )),
        ], at(e));
        expect(s.backgroundColor, applyOpacity(variant(CupertinoColors.systemRed, e), 0.5), reason: envName(e));
        expect(s.side!.color, applyOpacity(variant(CupertinoColors.systemGreen, e), 0.25), reason: envName(e));
      }
    });

    test('an infinite, NaN or negative factor trips the assert (component and token layer)', () {
      for (final double bad in <double>[double.infinity, double.negativeInfinity, double.nan, -0.1]) {
        expect(() => ButtonColorSource.opacity(const .fromField(.foregroundColor), bad), throwsAssertionError, reason: '$bad');
        expect(() => SwitchColorSource.opacity(const .fromField(.thumbColor), bad), throwsAssertionError, reason: '$bad');
        expect(() => CupertinoTokenColorSource.opacity(const .fromToken(.primaryColor), bad), throwsAssertionError,
            reason: '$bad');
      }
      // Large finite factors are fine.
      expect(ButtonColorSource.opacity(const .fromField(.foregroundColor), 1e300), isA<ButtonColorSource>());
    });
  });

  group('composite fields: .parts', () {
    test('.parts without a base, split over two rules, equals the old whole-plus-parts-in-one-rule result', () {
      final Tokens tokens = buildTokens(const <TokenGroup>[], const <TokenRule>[]);
      Map<ButtonField, Object> engine(List<RawRule<ButtonField>> rules, Minterm m) => resolve<ButtonField>(
          chain<ButtonField>(<List<RawRule<ButtonField>>>[buttonStyle.defaults, rules],
              spec: buttonStyle.spec, splitter: cupertinoEnvSplitter),
          m,
          buttonStyle.spec.fields,
          tokens: tokens,
          composites: buttonStyle.spec.composites).values;
      const TextStyle whole = TextStyle(color: red, fontSize: 30, decorationColor: green);
      const BorderSide side = BorderSide(color: red, width: 3);
      // The old form: one engine rule with a whole value and parts.
      final List<RawRule<ButtonField>> oneRule = <RawRule<ButtonField>>[
        RawRule<ButtonField>(
          const ButtonWhen(pressed: true).toCondition(),
          style: const Style<ButtonField>(<ButtonField, Object>{ButtonField.textStyle: whole, ButtonField.side: side}),
          derive: const Derive<ButtonField>(),
          sub: const <(ButtonField, SubProp), Object>{
            (ButtonField.textStyle, SubProp.color): FieldRef(ButtonField.backgroundColor),
            (ButtonField.side, SubProp.color): blue,
          },
        ),
      ];
      // The new form: the whole value, then `.parts` in a second rule.
      const List<ButtonRule> twoRulesParts = <ButtonRule>[
        .when(pressed: true, style: .values(textStyle: whole, side: side)),
        .when(pressed: true, style: .derive(textStyle: .parts(color: .fromField(.backgroundColor)), side: .parts(color: .value(blue)))),
      ];
      final List<RawRule<ButtonField>> twoRaw = <RawRule<ButtonField>>[for (final ButtonRule r in twoRulesParts) r.toRaw()];
      int compared = 0;
      for (final Minterm m in buttonStyle.spec.minterms()) {
        expect(engine(twoRaw, m), engine(oneRule, m), reason: '$m');
        compared++;
      }
      expect(compared, 576);
      final ButtonStyle s = resolveButton(
          StyleNode.root(), twoRulesParts, at(allEnvironments.first, appearance: ButtonAppearance.filled, pressed: true));
      expect(s.textStyle!.fontSize, 30);
      expect(s.textStyle!.decorationColor, green);
      expect(s.textStyle!.color, s.backgroundColor);
      expect(s.side, side.copyWith(color: blue));
    });

    test('across rules: a later whole value that sets the sub-property beats an earlier .parts', () {
      const ButtonRule parts = ButtonRule.always(style: .derive(textStyle: .parts(color: .value(blue))));
      final ButtonStyle setsColor = resolveButton(StyleNode.root(), const <ButtonRule>[
        parts,
        ButtonRule.always(style: .values(textStyle: TextStyle(color: green))),
      ], at(allEnvironments.first));
      expect(setsColor.textStyle!.color, green);
      // A later whole value without a color keeps the earlier parts entry.
      final ButtonStyle noColor = resolveButton(StyleNode.root(), const <ButtonRule>[
        parts,
        ButtonRule.always(style: .values(textStyle: TextStyle(fontSize: 30))),
      ], at(allEnvironments.first));
      expect(noColor.textStyle!.color, blue);
      expect(noColor.textStyle!.fontSize, 30);
      // A later .parts beats an earlier whole value, sub-property by
      // sub-property.
      final ButtonStyle laterParts = resolveButton(StyleNode.root(), const <ButtonRule>[
        ButtonRule.always(style: .values(textStyle: TextStyle(color: green, decorationColor: green, fontSize: 30))),
        parts,
      ], at(allEnvironments.first));
      expect(laterParts.textStyle!.color, blue);
      expect(laterParts.textStyle!.decorationColor, green);
      expect(laterParts.textStyle!.fontSize, 30);
    });

    test('.parts takes derives and transforms: an icon at half the foreground, a text color from a token', () {
      const List<ButtonRule> rules = <ButtonRule>[
        .always(
            style: .derive(
          iconTheme: .parts(color: .opacity(.fromField(.foregroundColor), 0.5)),
          textStyle: .parts(decorationColor: .fromToken(.primaryContrastingColor)),
        )),
      ];
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle s = resolveButton(StyleNode.root(), rules, at(e));
        expect(s.iconTheme!.color, applyOpacity(variant(CupertinoColors.systemBlue, e), 0.5), reason: envName(e));
        expect(s.textStyle!.decorationColor, CupertinoColors.white);
      }
    });

    test('BorderSide is an atomic value; side: .parts(color: x) changes only the color', () {
      const BorderSide thick = BorderSide(color: red, width: 3, strokeAlign: BorderSide.strokeAlignCenter);
      final StyleNode theme = StyleNode.root(rules: const <Rule>[ButtonRule.always(style: .values(side: thick))]);
      ButtonStyle resolveAt(List<ButtonRule> callSite, [ResolvedEnvironment? e]) =>
          resolveButton(theme, callSite, at(e ?? allEnvironments.first));
      expect(resolveAt(const <ButtonRule>[]).side, thick);
      expect(resolveAt(const <ButtonRule>[.always(style: .derive(side: .parts(color: .value(blue))))]).side,
          thick.copyWith(color: blue));
      // A later whole value replaces everything, including earlier parts.
      expect(
          resolveAt(const <ButtonRule>[
            .always(style: .derive(side: .parts(color: .value(blue)))),
            .always(style: .values(side: BorderSide(color: green))),
          ]).side,
          const BorderSide(color: green));
      // Parts with a derive: the side follows the foreground in every
      // environment.
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(resolveAt(const <ButtonRule>[.always(style: .derive(side: .parts(color: .fromField(.foregroundColor))))], e).side,
            thick.copyWith(color: variant(CupertinoColors.systemBlue, e)),
            reason: envName(e));
      }
      // Parts alone start from BorderSide's defaults.
      expect(
          resolveButton(StyleNode.root(), const <ButtonRule>[.always(style: .derive(side: .parts(color: .value(blue))))],
              at(allEnvironments.first)).side,
          const BorderSide(color: blue));
    });

    test('.parts() with no sub-property fails its assert at run time too', () {
      expect(() => ButtonTextStyleSource.parts(), throwsAssertionError);
      expect(() => ButtonIconStyleSource.parts(), throwsAssertionError);
      expect(() => ButtonBorderSideSource.parts(), throwsAssertionError);
    });

    testWidgets('the resolved side is painted, and the focus ring replaces it while focused', (WidgetTester tester) async {
      ShapeDecoration decoration() => tester.widget<DecoratedBox>(find.byType(DecoratedBox)).decoration as ShapeDecoration;
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      await tester.pumpWidget(inEnvironment(
          allEnvironments.first,
          StyleTheme(
            rules: const <Rule>[
              ...<ButtonRule>[
                .always(style: .values(side: BorderSide(color: red, width: 2))),
                .always(style: .derive(side: .parts(color: .value(blue)))),
              ],
            ],
            child: Button(focusNode: focus, onPressed: () {}, child: const Text('b')),
          )));
      expect((decoration().shape as RoundedSuperellipseBorder).side, const BorderSide(color: blue, width: 2));
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect((decoration().shape as RoundedSuperellipseBorder).side.width, 3.5);
    });
  });

  group('callbacks', () {
    test('s.field and s.token read the same instance and the tokens of its environment', () {
      const List<ButtonRule> rules = <ButtonRule>[
        .always(
            style: .derive(
          focusColor: .computed(focusFromToken),
          iconTheme: .parts(color: .computed(iconFromFieldAndToken)),
        )),
      ];
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle s = resolveButton(StyleNode.root(), rules, at(e, focused: true));
        final Color primary = variant(CupertinoColors.systemBlue, e);
        expect(s.focusColor, primary.withAlpha(10), reason: envName(e));
        final double fill = e.brightness == Brightness.light ? 0.12 : 0.26;
        expect(s.iconTheme!.color, Color.lerp(primary, applyOpacity(primary, fill), 0.5), reason: envName(e));
      }
    });

    test('s.customToken reads an app token; an app token without a default is an error', () {
      const ButtonRule rule = ButtonRule.always(style: .derive(backgroundColor: .computed(backgroundFromBrand)));
      final StyleNode withBrand = StyleNode.root(groups: <TokenGroup>[Brand.group], rules: <Rule>[
        ...BrandRule.teal,
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(resolveButton(withBrand, const <ButtonRule>[rule], at(e)).backgroundColor,
            variant(brandTealAccent, e), reason: envName(e));
      }
      final StyleNode groupOnly = StyleNode.root(groups: <TokenGroup>[Brand.group]);
      expect(() => resolveButton(groupOnly, const <ButtonRule>[rule], at(allEnvironments.first)),
          throwsA(isA<RuleError>().having((RuleError e) => e.message, 'message', contains('custom token accent'))));
    });

    test('a cycle through a callback and a transformed field reference still throws, naming the cycle', () {
      expect(
          () => resolveButton(StyleNode.root(), const <ButtonRule>[
                .always(
                    style: .derive(
                  focusColor: .opacity(.fromField(.backgroundColor), 0.5),
                  backgroundColor: .computed(backgroundFromFocus),
                )),
              ], at(allEnvironments.first)),
          throwsA(isA<RuleError>().having((RuleError e) => e.message, 'message',
              allOf(contains('derive cycle'), contains('backgroundColor'), contains('focusColor')))));
    });

    test('provenance names computed rules, transforms, fields, tokens and custom tokens', () {
      final StyleResolver<ButtonField> r = StyleResolver<ButtonField>(buttonStyle);
      final StyleNode node = StyleNode.root(groups: <TokenGroup>[Brand.group], rules: <Rule>[
        ...BrandRule.teal,
      ]);
      final Map<ButtonField, String> src = r.debugSources(
          node,
          const <ButtonRule>[
            .always(label: 'ring', style: .derive(focusColor: .computed(focusFromToken))),
            .always(style: .derive(backgroundColor: .opacity(.fromField(.foregroundColor), 0.5))),
            .always(style: .derive(foregroundColor: .opaque(.fromCustomToken(Brand.accent)))),
          ],
          at(allEnvironments.first));
      expect(src[ButtonField.focusColor], 'computed rule #0 "ring" (call site)');
      expect(src[ButtonField.backgroundColor], startsWith('rule #1 (call site) <- field .foregroundColor (opacity 0.5) <- (opaque) <- custom token accent: '));
      expect(src[ButtonField.foregroundColor], startsWith('rule #2 (call site) <- (opaque) <- custom token accent: '));
      expect(src[ButtonField.iconTheme], startsWith('rule #12 "rest" (defaults)'));
      final Map<ButtonField, String> filled =
          r.debugSources(StyleNode.root(), const <ButtonRule>[], at(allEnvironments.first, appearance: ButtonAppearance.filled));
      expect(filled[ButtonField.backgroundColor], startsWith('rule #8 "rest" (defaults) <- (opaque) <- token primaryColor: '));
      // Source descriptions (errors) use the same words.
      expect(const ButtonColorSource.opacity(.fromField(.foregroundColor), 0.5).toString(), 'opacity(field .foregroundColor, 0.5)');
      expect(const ButtonColorSource.opaque(.fromCustomToken(Brand.accent)).toString(), 'opaque(custom token accent)');
      expect(const ButtonTextStyleSource.parts(color: .fromToken(.primaryColor)).toString(), 'parts(color: token primaryColor)');
      expect(const ButtonColorSource.computed(focusFromToken).toString(), startsWith('computed('));
    });
  });

  group('custom tokens', () {
    test('.fromCustomToken(Brand.x) with transforms, per environment', () {
      final StyleNode node = StyleNode.root(groups: <TokenGroup>[Brand.group], rules: <Rule>[
        ...BrandRule.purple,
        const ButtonRule.always(
            style: .derive(
          backgroundColor: .opacity(.fromCustomToken(Brand.accent), 0.5),
          foregroundColor: .fromCustomToken(Brand.onAccent),
          textStyle: .parts(decorationColor: .opacity(.fromCustomToken(Brand.pressedAccent), 0.3)),
        )),
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle s = resolveButton(node, const <ButtonRule>[], at(e));
        expect(s.backgroundColor, applyOpacity(variant(brandPurpleAccent, e), 0.5), reason: envName(e));
        expect(s.foregroundColor, CupertinoColors.white);
        expect(s.textStyle!.decorationColor, applyOpacity(variant(brandPurplePressedAccent, e), 0.3));
      }
    });

    test('a library token passed to .fromCustomToken resolves like .fromToken', () {
      expect(
          expectSameEverywhere(
            const <ButtonRule>[.always(style: .derive(backgroundColor: .fromCustomToken(CupertinoToken.primaryColor)))],
            const <ButtonRule>[.always(style: .derive(backgroundColor: .fromToken(.primaryColor)))],
          ),
          576);
    });

    test('a theme can override the derived tintedFill token like any token', () {
      final StyleNode node = StyleNode.root(rules: const <Rule>[CupertinoTokenRule(tintedFill: green)]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(resolveButton(node, const <ButtonRule>[], at(e, appearance: ButtonAppearance.tinted)).backgroundColor, green);
      }
      final StyleNode set = StyleNode.root(rules: <Rule>[CupertinoToken.tintedFill.set(green)]);
      expect(resolveButton(set, const <ButtonRule>[], at(allEnvironments.first, appearance: ButtonAppearance.tinted)).backgroundColor,
          green);
    });

    test('setting primaryColor keeps tintedFill derived', () {
      final StyleNode node = StyleNode.root(rules: const <Rule>[
        CupertinoTokenRule(primaryColor: CupertinoColors.systemPink),
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final double fill = e.brightness == Brightness.light ? 0.12 : 0.26;
        expect(resolveButton(node, const <ButtonRule>[], at(e, appearance: ButtonAppearance.tinted)).backgroundColor,
            applyOpacity(variant(CupertinoColors.systemPink, e), fill), reason: envName(e));
      }
    });
  });
}

class _KeyedButton extends StatelessWidget {
  const _KeyedButton();
  @override
  Widget build(BuildContext context) => Button(key: const Key('b'), onPressed: () {}, child: const Text('b'));
}
