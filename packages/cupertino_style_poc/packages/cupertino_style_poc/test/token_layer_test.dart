// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The token layer: rule forms (the generated `CupertinoTokenRule` with its
// flat-value and `.derive` constructors, the hand-written `BrandRule`
// (TokenValueRule) and a hand-written TokenSourceRule, single tokens with
// `set` / `setFrom`), typed reads (`token.of(context)`), the
// default-coverage check, and the per-token theme animation.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc/src/engine/engine.dart' show Dimension, lerpTokenValue;
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoColors, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const Color purple = Color(0xFF7B1FA2);
const Color green = Color(0xFF43A047);

Color variant(Color c, ResolvedEnvironment e) =>
    cupertinoEnvSplitter.resolve(c, Minterm(EnvDims.all, e.values)) as Color;

Minterm envOf(ResolvedEnvironment e) => Minterm(EnvDims.all, e.values);

double fillOf(ResolvedEnvironment e) => e.brightness == Brightness.light ? 0.12 : 0.26;

Tokens tokensFor(List<TokenRule> rules, {List<TokenGroup> groups = const <TokenGroup>[]}) =>
    buildTokens(groups, rules);

/// [tokens] with a theme environment (light or dark), as a StyleTheme
/// would bind it.
Tokens inTheme(Tokens tokens, Brightness b) => Tokens(tokens.global, env: <Dimension<Object>, Object>{
      EnvDims.brightness: b,
      EnvDims.highContrast: false,
      EnvDims.interfaceLevel: CupertinoUserInterfaceLevelData.base,
    });

/// A hand-written TokenSourceRule over the Brand group (the doc's
/// "full source" form): literals need `.value(...)`, derives sit next to
/// them.
final class BrandSourceRule extends TokenSourceRule {
  const BrandSourceRule({this.accent, this.onAccent, this.pressedAccent, this.cornerRadius, super.when});

  final CupertinoTokenColorSource? accent;
  final CupertinoTokenColorSource? onAccent;
  final CupertinoTokenColorSource? pressedAccent;
  final CupertinoTokenSource<double>? cornerRadius;

  @override
  Map<Token<Object>, DeriveSource> get sources => <Token<Object>, DeriveSource>{
        Brand.accent: ?accent,
        Brand.onAccent: ?onAccent,
        Brand.pressedAccent: ?pressedAccent,
        Brand.cornerRadius: ?cornerRadius,
      };
}

/// A group whose tokens bring their own theme-animation lerp.
enum Lerped<T extends Object> with GroupTokenMixin<T> {
  stepped<double>(lerp: discrete),
  custom<double>(lerp: _alwaysMax),
  plain<double>();

  const Lerped({this.lerp});

  @override
  final T? Function(T? a, T? b, double t)? lerp;

  static const TokenGroup group = TokenGroup('Lerped', values);

  static double? _alwaysMax(double? a, double? b, double t) => a == null || b == null ? null : (a > b ? a : b);
}

final class LerpedRule extends TokenValueRule {
  const LerpedRule(this.v);

  final double v;

  @override
  Map<Token<Object>, Object> get values => <Token<Object>, Object>{Lerped.stepped: v, Lerped.custom: v, Lerped.plain: v};
}

void main() {
  group('group rule classes', () {
    test('CupertinoTokenRule(primaryColor: x) sets only primary; tintedFill keeps deriving in every environment', () {
      final Tokens t = tokensFor(const <TokenRule>[CupertinoTokenRule(primaryColor: purple)]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(t.read(CupertinoToken.primaryColor, env: envOf(e)), purple);
        expect(t.read(CupertinoToken.tintedFill, env: envOf(e)), applyOpacity(purple, fillOf(e)), reason: envName(e));
        // The other tokens keep their defaults.
        expect(t.read(CupertinoToken.primaryContrastingColor, env: envOf(e)), CupertinoColors.white);
      }
      // A dynamic color is expanded per environment, and tintedFill follows
      // each variant.
      final Tokens d = tokensFor(const <TokenRule>[CupertinoTokenRule(primaryColor: CupertinoColors.systemPink)]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(d.read(CupertinoToken.tintedFill, env: envOf(e)),
            applyOpacity(variant(CupertinoColors.systemPink, e), fillOf(e)), reason: envName(e));
      }
    });

    test('CupertinoTokenRule is const, takes a condition, and compares by value', () {
      const TokenRule a = CupertinoTokenRule(primaryColor: purple, when: TokenWhen(brightness: Brightness.dark));
      const TokenRule b = CupertinoTokenRule(primaryColor: purple, when: TokenWhen(brightness: Brightness.dark));
      expect(identical(a, b), isTrue);
      expect(a, isNot(const CupertinoTokenRule(primaryColor: purple)));
      final Tokens t = tokensFor(const <TokenRule>[a]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(t.read(CupertinoToken.primaryColor, env: envOf(e)),
            e.brightness == Brightness.dark ? purple : variant(CupertinoColors.systemBlue, e), reason: envName(e));
      }
    });

    test('BrandRule (hand-written, same shape) sets only the given tokens', () {
      final Tokens t = tokensFor(<TokenRule>[
        ...BrandRule.teal,
        const BrandRule(accent: purple, cornerRadius: 3),
      ], groups: <TokenGroup>[Brand.group]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(t.read(Brand.accent, env: envOf(e)), purple);
        expect(t.read(Brand.cornerRadius, env: envOf(e)), 3.0);
        expect(t.read(Brand.pressedAccent, env: envOf(e)), variant(brandTealPressedAccent, e), reason: envName(e));
        expect(t.read(Brand.onAccent, env: envOf(e)), CupertinoColors.white);
      }
      expect(const BrandRule(accent: purple), const BrandRule(accent: purple));
      expect(const BrandRule(accent: purple).values, <Token<Object>, Object>{Brand.accent: purple});
    });
  });

  group('CupertinoTokenRule constructors and TokenSourceRule', () {
    test('the flat-value constructor sets every token given', () {
      const CupertinoTokenRule rule = CupertinoTokenRule(
        primaryColor: purple,
        primaryContrastingColor: green,
        barBackgroundColor: CupertinoColors.systemYellow,
        scaffoldBackgroundColor: CupertinoColors.systemGrey,
        textStyle: TextStyle(fontSize: 11, color: purple),
        actionTextStyle: TextStyle(fontSize: 12, color: green),
        actionSmallTextStyle: TextStyle(fontSize: 13, color: green),
      );
      final Tokens t = tokensFor(const <TokenRule>[rule]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final Minterm m = envOf(e);
        expect(t.read(CupertinoToken.primaryColor, env: m), purple);
        expect(t.read(CupertinoToken.primaryContrastingColor, env: m), green);
        expect(t.read(CupertinoToken.barBackgroundColor, env: m), variant(CupertinoColors.systemYellow, e));
        expect(t.read(CupertinoToken.scaffoldBackgroundColor, env: m), variant(CupertinoColors.systemGrey, e));
        expect(t.read(CupertinoToken.textStyle, env: m).fontSize, 11);
        expect(t.read(CupertinoToken.actionTextStyle, env: m).fontSize, 12);
        expect(t.read(CupertinoToken.actionSmallTextStyle, env: m).fontSize, 13);
        // tintedFill is not given: it keeps deriving.
        expect(t.read(CupertinoToken.tintedFill, env: m), applyOpacity(purple, fillOf(e)));
      }
    });

    test('.derive takes sources: literals are split from derives, and equal content gives equal rules', () {
      const CupertinoTokenRule rule = CupertinoTokenRule.derive(
        primaryColor: .value(purple),
        primaryContrastingColor: .opacity(.fromToken(.primaryColor), 0.5),
        actionTextStyle: .fromToken(.textStyle),
      );
      expect(rule.literals, <Token<Object>, Object>{CupertinoToken.primaryColor: purple});
      expect(rule.derives.keys, <Token<Object>>{CupertinoToken.primaryContrastingColor, CupertinoToken.actionTextStyle});
      final Tokens t = tokensFor(const <TokenRule>[rule]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final Minterm m = envOf(e);
        expect(t.read(CupertinoToken.primaryContrastingColor, env: m), applyOpacity(purple, 0.5));
        expect(t.read(CupertinoToken.actionTextStyle, env: m).fontSize, t.read(CupertinoToken.textStyle, env: m).fontSize);
      }
      // A literal via .derive equals the flat-value form.
      expect(const CupertinoTokenRule.derive(primaryColor: .value(purple)), const CupertinoTokenRule(primaryColor: purple));
      expect(const CupertinoTokenRule.derive(primaryColor: .value(purple)).hashCode,
          const CupertinoTokenRule(primaryColor: purple).hashCode);
      expect(const CupertinoTokenRule.derive(primaryColor: .fromToken(.barBackgroundColor)),
          isNot(const CupertinoTokenRule(primaryColor: purple)));
    });

    test('a hand-written TokenSourceRule mixes literals and derives in one const rule', () {
      final Tokens t = tokensFor(const <TokenRule>[
        BrandSourceRule(
          onAccent: .opacity(.fromCustomToken(Brand.accent), 0.6),
          pressedAccent: .fromToken(.primaryColor),
        ),
        BrandSourceRule(accent: .value(purple), cornerRadius: .value(12)),
        BrandSourceRule(when: TokenWhen(brightness: Brightness.dark), accent: .value(green)),
      ], groups: <TokenGroup>[Brand.group]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final Minterm m = envOf(e);
        final Color accent = e.brightness == Brightness.dark ? green : purple;
        expect(t.read(Brand.accent, env: m), accent, reason: envName(e));
        expect(t.read(Brand.onAccent, env: m), applyOpacity(accent, 0.6), reason: envName(e));
        expect(t.read(Brand.pressedAccent, env: m), variant(CupertinoColors.systemBlue, e), reason: envName(e));
        expect(t.read(Brand.cornerRadius, env: m), 12.0);
      }
      // A later rule that sets only the source re-derives; one that sets
      // the derived token pins it.
      final Tokens o = tokensFor(const <TokenRule>[
        ...BrandRule.teal,
        BrandSourceRule(onAccent: .opacity(.fromCustomToken(Brand.accent), 0.6)),
        BrandRule(accent: purple),
      ], groups: <TokenGroup>[Brand.group]);
      expect(o.read(Brand.onAccent, env: envOf(allEnvironments.first)), applyOpacity(purple, 0.6));
      final Tokens pinned = tokensFor(const <TokenRule>[
        ...BrandRule.teal,
        BrandSourceRule(onAccent: .opacity(.fromCustomToken(Brand.accent), 0.6)),
        BrandRule(accent: purple, onAccent: green),
      ], groups: <TokenGroup>[Brand.group]);
      expect(pinned.read(Brand.onAccent, env: envOf(allEnvironments.first)), green);
    });
  });

  group('single tokens', () {
    test('Brand.accent.set and setFrom with opacity / opaque', () {
      final Tokens t = tokensFor(<TokenRule>[
        ...BrandRule.teal,
        Brand.accent.set(purple),
        Brand.pressedAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.5)),
        Brand.onAccent.setFrom(.opaque(.opacity(.fromToken(.primaryColor), 0.1))),
        Brand.cornerRadius.setFrom(.value(9.0)),
      ], groups: <TokenGroup>[Brand.group]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final Minterm m = envOf(e);
        expect(t.read(Brand.accent, env: m), purple);
        expect(t.read(Brand.pressedAccent, env: m), applyOpacity(purple, 0.5));
        expect(t.read(Brand.onAccent, env: m), applyOpaque(variant(CupertinoColors.systemBlue, e)), reason: envName(e));
        expect(t.read(Brand.cornerRadius, env: m), 9.0);
      }
      // Equal code gives equal rules (not const, but change detection
      // still works).
      expect(Brand.accent.set(purple), Brand.accent.set(purple));
      expect(Brand.accent.set(purple).hashCode, Brand.accent.set(purple).hashCode);
      expect(Brand.accent.set(purple), isNot(Brand.accent.set(green)));
      expect(Brand.accent.set(purple), const BrandRule(accent: purple), reason: 'equal maps, equal rules');
      // A setFrom with a dynamic literal inside a transform is expanded per
      // environment.
      final Tokens d = tokensFor(<TokenRule>[
        ...BrandRule.teal,
        Brand.accent.setFrom(.opacity(.value(CupertinoColors.systemRed), 0.5)),
      ], groups: <TokenGroup>[Brand.group]);
      for (final ResolvedEnvironment e in allEnvironments) {
        expect(d.read(Brand.accent, env: envOf(e)), applyOpacity(variant(CupertinoColors.systemRed, e), 0.5),
            reason: envName(e));
      }
    });

    test('a component reads a token set by setFrom', () {
      final StyleNode node = StyleNode.root(groups: <TokenGroup>[Brand.group], rules: <Rule>[
        ...BrandRule.teal,
        Brand.pressedAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.5)),
        const ButtonRule.when(pressed: true, style: .derive(backgroundColor: .fromCustomToken(Brand.pressedAccent))),
      ]);
      for (final ResolvedEnvironment e in allEnvironments) {
        final Map<ButtonField, Object> v = StyleResolver<ButtonField>(buttonStyle).resolve(
            node,
            const <ButtonRule>[],
            buttonMinterm(
                disabled: false, pressed: true, focused: false, appearance: ButtonAppearance.plain, sizeStyle: ButtonSize.large, env: e));
        expect(v[ButtonField.backgroundColor], applyOpacity(variant(brandTealAccent, e), 0.5), reason: envName(e));
      }
    });
  });

  group('reads', () {
    test('a single-token read is non-null and typed by the token; an unset token is an error', () {
      final Tokens t = inTheme(
          tokensFor(<TokenRule>[...BrandRule.teal], groups: <TokenGroup>[Brand.group]),
          Brightness.light);
      final Color accent = t.read(Brand.accent);
      final double radius = t.read(Brand.cornerRadius);
      final TextStyle style = t.read(CupertinoToken.actionTextStyle);
      expect(accent, isA<Color>());
      expect(radius, 6);
      expect(style.color, isNotNull);
      final Tokens unset = inTheme(tokensFor(const <TokenRule>[], groups: <TokenGroup>[Brand.group]), Brightness.light);
      expect(() => unset.read(Brand.accent),
          throwsA(isA<RuleError>().having((RuleError e) => e.message, 'message', contains('token Brand.accent has no value'))));
    });

    testWidgets('token.of(context) reads at the environment of the context; a group read is a Record',
        (WidgetTester tester) async {
      late Color accent;
      late Color primary;
      late ({Color accent, double radius}) brand;
      await tester.pumpWidget(inEnvironment(
          allEnvironments.last,
          StyleTheme(
            groups: <TokenGroup>[Brand.group],
            rules: <Rule>[...BrandRule.teal],
            child: Builder(builder: (BuildContext context) {
              accent = Brand.accent.of(context);
              primary = CupertinoToken.primaryColor.of(context);
              brand = (accent: Brand.accent.of(context), radius: Brand.cornerRadius.of(context));
              return const SizedBox();
            }),
          )));
      expect(accent, variant(brandTealAccent, allEnvironments.last));
      expect(primary, variant(CupertinoColors.systemBlue, allEnvironments.last));
      expect(brand, (accent: accent, radius: 6.0));
    });

    testWidgets('reading a token of an unregistered group names the group and the token', (WidgetTester tester) async {
      Object? error;
      await tester.pumpWidget(StyleTheme(
        rules: const <Rule>[],
        child: Builder(builder: (BuildContext context) {
          try {
            Brand.accent.of(context);
          } on RuleError catch (e) {
            error = e;
          }
          return const SizedBox();
        }),
      ));
      expect(error, isA<RuleError>().having((RuleError e) => e.message, 'message', allOf(contains('Brand.accent'), contains('StyleTheme(groups:'))));
      // A rule that references an unregistered group fails at chain build,
      // naming the group too.
      expect(() => tokensFor(const <TokenRule>[CupertinoTokenRule.derive(primaryColor: .fromCustomToken(Brand.accent))]),
          throwsA(isA<RuleError>().having((RuleError e) => e.message, 'message', contains('Brand.accent'))));
    });

    test('every token has a default rule in every environment', () {
      // The library defaults cover the Cupertino group.
      expect(debugMissingTokenDefaults(tokensFor(const <TokenRule>[])), isEmpty);
      // The app's defaults cover its group.
      expect(
          debugMissingTokenDefaults(tokensFor(<TokenRule>[...BrandRule.teal],
              groups: <TokenGroup>[Brand.group])),
          isEmpty);
      // The check finds a group without defaults (4 tokens x 8 environments).
      final List<(Enum, Minterm)> missing =
          debugMissingTokenDefaults(tokensFor(const <TokenRule>[], groups: <TokenGroup>[Brand.group]));
      expect(missing, hasLength(Brand.values.length * allEnvironments.length));
      expect(missing.map(((Enum, Minterm) x) => x.$1).toSet(), Brand.values.toSet());
    });
  });

  group('theme animation', () {
    test('tintedFill lerps continuously across a light-to-dark change (per-token lerp of the two final values)', () {
      final Tokens base = tokensFor(const <TokenRule>[]);
      final Tokens light = inTheme(base, Brightness.light);
      final Tokens dark = inTheme(base, Brightness.dark);
      final Color from = light.read(CupertinoToken.tintedFill);
      final Color to = dark.read(CupertinoToken.tintedFill);
      expect((from.a * 255).round(), (0.12 * 255).round());
      expect((to.a * 255).round(), (0.26 * 255).round());
      double? previous;
      for (int i = 0; i <= 20; i++) {
        final double t = i / 20;
        final Color c = Tokens.lerp(light, dark, t).read(CupertinoToken.tintedFill);
        expect(c, Color.lerp(from, to, t), reason: 't = $t');
        if (previous != null) {
          expect(c.a, greaterThanOrEqualTo(previous), reason: 'alpha rises monotonically');
          expect(c.a - previous, lessThan(0.02), reason: 'no jump at t = $t');
        }
        previous = c.a;
      }
    });

    test('a token pinned on one side lerps against the other side\'s derived value', () {
      final Tokens a = inTheme(tokensFor(const <TokenRule>[]), Brightness.light);
      final Tokens b = inTheme(tokensFor(<TokenRule>[CupertinoToken.tintedFill.set(green)]), Brightness.light);
      final Color derived = a.read(CupertinoToken.tintedFill);
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(Tokens.lerp(a, b, t).read(CupertinoToken.tintedFill), Color.lerp(derived, green, t), reason: 't = $t');
      }
    });

    test('values lerp by type (built-in table); anything else switches at 0.5', () {
      final Tokens a = inTheme(
          tokensFor(<TokenRule>[...BrandRule.teal], groups: <TokenGroup>[Brand.group]),
          Brightness.light);
      final Tokens b = inTheme(
          tokensFor(<TokenRule>[
            ...BrandRule.purple,
            const CupertinoTokenRule(actionTextStyle: TextStyle(fontSize: 40)),
          ], groups: <TokenGroup>[Brand.group]),
          Brightness.light);
      final Tokens mid = Tokens.lerp(a, b, 0.5);
      expect(mid.read(Brand.cornerRadius), 12);
      expect(mid.read(Brand.accent), Color.lerp(a.read(Brand.accent), b.read(Brand.accent), 0.5));
      expect(mid.read(CupertinoToken.actionTextStyle),
          TextStyle.lerp(a.read(CupertinoToken.actionTextStyle), b.read(CupertinoToken.actionTextStyle), 0.5));
      expect(lerpTokenValue(MouseCursor.defer, SystemMouseCursors.click, 0.49), MouseCursor.defer);
      expect(lerpTokenValue(MouseCursor.defer, SystemMouseCursors.click, 0.5), SystemMouseCursors.click);
      // The rest of the table.
      expect(lerpTokenValue(const EdgeInsets.all(2), const EdgeInsets.all(4), 0.5), const EdgeInsets.all(3));
      expect(lerpTokenValue(BorderRadius.circular(2), BorderRadius.circular(4), 0.5), BorderRadius.circular(3));
      expect(lerpTokenValue(Alignment.topLeft, Alignment.bottomRight, 0.5), Alignment.center);
      expect(lerpTokenValue(const Size(2, 2), const Size(4, 4), 0.5), const Size(3, 3));
      expect(lerpTokenValue(const Offset(2, 2), const Offset(4, 4), 0.5), const Offset(3, 3));
      expect(lerpTokenValue(const BorderSide(width: 2), const BorderSide(width: 4), 0.5), const BorderSide(width: 3));
      expect(lerpTokenValue(const IconThemeData(size: 2), const IconThemeData(size: 4), 0.5), const IconThemeData(size: 3));
      expect(
          lerpTokenValue(const RoundedRectangleBorder(), const RoundedRectangleBorder(side: BorderSide(width: 2)), 0.5),
          isA<RoundedRectangleBorder>().having((RoundedRectangleBorder b) => b.side.width, 'side.width', 1));
      expect(lerpTokenValue(const <BoxShadow>[BoxShadow(blurRadius: 2)], const <BoxShadow>[BoxShadow(blurRadius: 4)], 0.5),
          const <BoxShadow>[BoxShadow(blurRadius: 3)]);
      expect(lerpTokenValue(const <Shadow>[Shadow(blurRadius: 2)], const <Shadow>[Shadow(blurRadius: 4)], 0.5),
          const <Shadow>[Shadow(blurRadius: 3)]);
    });

    test("a token's own lerp: comes first (discrete, a custom function), then the table", () {
      final Tokens a = inTheme(tokensFor(const <TokenRule>[LerpedRule(2)], groups: <TokenGroup>[Lerped.group]), Brightness.light);
      final Tokens b = inTheme(tokensFor(const <TokenRule>[LerpedRule(4)], groups: <TokenGroup>[Lerped.group]), Brightness.light);
      final Tokens early = Tokens.lerp(a, b, 0.25);
      expect(early.read(Lerped.stepped), 2);
      expect(early.read(Lerped.custom), 4);
      expect(early.read(Lerped.plain), 2.5);
      expect(Tokens.lerp(a, b, 0.75).read(Lerped.stepped), 4);
      expect(Lerped.custom.lerpObject(1.0, 3.0, 0), 3.0);
    });
  });
}
