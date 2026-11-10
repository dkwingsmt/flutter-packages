// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// `.parts` over a whole value that is itself derived (a token, a callback
// that depends on the state, a field read inside the callback): the later
// `.parts` replaces only its sub-properties, the rest keeps following the
// derive, per state and per environment, across theme and call site.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/resolve_own.dart';

const Color red = Color(0xFFE53935);
const Color blue = Color(0xFF1E88E5);
const Color green = Color(0xFF43A047);

Color variant(Color c, ResolvedEnvironment e) => cupertinoEnvSplitter.resolve(c, Minterm(EnvDims.all, e.values)) as Color;

Minterm at(ResolvedEnvironment env, {bool pressed = false, bool disabled = false}) => buttonMinterm(
    disabled: disabled,
    pressed: pressed,
    focused: false,
    appearance: ButtonAppearance.plain,
    sizeStyle: ButtonSize.large,
    env: env);

ButtonStyle resolveButton(StyleNode node, List<ButtonRule> callSite, Minterm m) =>
    ButtonStyle.fromValues(StyleResolver<ButtonField>(buttonStyle).resolve(node, callSite, m));

/// A whole side derived per state: the color follows the foreground,
/// pressed is thicker, and it sits outside the shape.
BorderSide sideByState(ButtonView s) => BorderSide(
      color: s.field(.foregroundColor)!,
      width: s.pressed ? 4 : 2,
      strokeAlign: BorderSide.strokeAlignOutside,
    );

TextStyle smallText(ButtonView s) => const TextStyle(fontSize: 12);

const TextStyle appText = TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: green, letterSpacing: 1.5);

void main() {
  group('BorderSide: whole from a callback, then .parts', () {
    final StyleNode theme = StyleNode.root(rules: const <Rule>[
      ButtonRule.always(style: .derive(side: .computed(sideByState))),
    ]);

    test('.parts(color:) replaces the color; width and strokeAlign keep following the callback per state', () {
      for (final ResolvedEnvironment e in allEnvironments) {
        for (final bool pressed in <bool>[false, true]) {
          final BorderSide side = resolveButton(theme, const <ButtonRule>[
            .always(style: .derive(side: .parts(color: .value(blue)))),
          ], at(e, pressed: pressed)).side!;
          expect(side.color, blue, reason: '${envName(e)} pressed $pressed');
          expect(side.width, pressed ? 4 : 2, reason: '${envName(e)} pressed $pressed');
          expect(side.strokeAlign, BorderSide.strokeAlignOutside);
        }
      }
    });

    test('.parts(width:) replaces the width; the color keeps following the foreground per environment and state', () {
      for (final ResolvedEnvironment e in allEnvironments) {
        for (final bool disabled in <bool>[false, true]) {
          final ButtonStyle s = resolveButton(theme, const <ButtonRule>[
            .always(style: .derive(side: .parts(width: .value(1)))),
          ], at(e, pressed: true, disabled: disabled));
          expect(s.side!.width, 1);
          expect(s.side!.color, s.foregroundColor, reason: '${envName(e)} disabled $disabled');
          expect(s.side!.strokeAlign, BorderSide.strokeAlignOutside);
        }
      }
      // The foreground differs between enabled and disabled, so the color
      // really is re-derived per state.
      final Minterm m = at(allEnvironments.first, pressed: true);
      final Minterm d = at(allEnvironments.first, pressed: true, disabled: true);
      const List<ButtonRule> widthOnly = <ButtonRule>[.always(style: .derive(side: .parts(width: .value(1))))];
      expect(resolveButton(theme, widthOnly, m).side!.color, isNot(resolveButton(theme, widthOnly, d).side!.color));
    });

    test('.parts with a derive over the derived whole: color at half the foreground', () {
      for (final ResolvedEnvironment e in allEnvironments) {
        final ButtonStyle s = resolveButton(theme, const <ButtonRule>[
          .always(style: .derive(side: .parts(color: .opacity(.fromField(.foregroundColor), 0.5)))),
        ], at(e));
        expect(s.side!.color, applyOpacity(variant(CupertinoColors.systemBlue, e), 0.5), reason: envName(e));
        expect(s.side!.width, 2);
      }
    });

    test('two .parts rules on different sub-properties both apply; the later one wins on the same one', () {
      final BorderSide side = resolveButton(theme, const <ButtonRule>[
        .always(style: .derive(side: .parts(color: .value(blue), width: .value(5)))),
        .when(pressed: true, style: .derive(side: .parts(width: .value(7)))),
      ], at(allEnvironments.first, pressed: true)).side!;
      expect(side, const BorderSide(color: blue, width: 7, strokeAlign: BorderSide.strokeAlignOutside));
    });

    test('order matters: a derived whole after .parts replaces the parts (BorderSide is replaced whole)', () {
      final ButtonStyle s = resolveButton(StyleNode.root(), const <ButtonRule>[
        .always(style: .derive(side: .parts(color: .value(blue)))),
        .always(style: .derive(side: .computed(sideByState))),
      ], at(allEnvironments.first));
      expect(s.side!.color, s.foregroundColor);
      expect(s.side!.width, 2);
    });

    testWidgets('theme derives the whole, the call site (rules:) patches it', (WidgetTester tester) async {
      await tester.pumpWidget(inEnvironment(
          allEnvironments.first,
          StyleTheme(
            rules: const <Rule>[ButtonRule.always(style: .derive(side: .computed(sideByState)))],
            child: Button(
              rules: const <ButtonRule>[.always(style: .derive(side: .parts(color: .value(blue))))],
              onPressed: () {},
              child: const Text('b'),
            ),
          )));
      final ButtonStyle s = tester.widget<Button>(find.byType(Button)).resolveOwn(tester.element(find.byType(Button)));
      expect(s.side, const BorderSide(color: blue, width: 2, strokeAlign: BorderSide.strokeAlignOutside));
    });

    test('provenance lists the derived whole and the patch', () {
      final Map<ButtonField, String> src = StyleResolver<ButtonField>(buttonStyle).debugSources(
          theme, const <ButtonRule>[.always(label: 'patch', style: .derive(side: .parts(color: .value(blue))))], at(allEnvironments.first));
      // ignore: avoid_print
      print('side provenance: ${src[ButtonField.side]}');
      expect(src[ButtonField.side], contains('patch'));
      expect(src[ButtonField.side], contains('computed'));
    });
  });

  group('TextStyle: whole from a token, then .parts', () {
    final StyleNode themed = StyleNode.root(rules: const <Rule>[
      CupertinoTokenRule(textStyle: appText),
      ButtonRule.always(style: .derive(textStyle: .fromToken(.textStyle))),
    ]);

    test('.parts(color:) replaces the color; size, weight and spacing come from the token', () {
      for (final ResolvedEnvironment e in allEnvironments) {
        final TextStyle t = resolveButton(themed, const <ButtonRule>[
          .always(style: .derive(textStyle: .parts(color: .value(red)))),
        ], at(e)).textStyle!;
        expect(t.color, red, reason: envName(e));
        expect(t.fontSize, 40);
        expect(t.fontWeight, FontWeight.w700);
        expect(t.letterSpacing, 1.5);
      }
    });

    test('changing the token changes the derived part and keeps the patch', () {
      final StyleNode other = StyleNode.root(rules: const <Rule>[
        CupertinoTokenRule(textStyle: TextStyle(fontSize: 12, color: green)),
        ButtonRule.always(style: .derive(textStyle: .fromToken(.textStyle))),
      ]);
      final TextStyle t = resolveButton(other, const <ButtonRule>[
        .always(style: .derive(textStyle: .parts(color: .value(red)))),
      ], at(allEnvironments.first)).textStyle!;
      expect(t.color, red);
      expect(t.fontSize, 12);
    });

    test('order matters: a derived whole after .parts wins only where it sets the sub-property (TextStyle merges)', () {
      // The token sets a color: it beats the earlier patch.
      final TextStyle withColor = resolveButton(StyleNode.root(rules: const <Rule>[CupertinoTokenRule(textStyle: appText)]),
          const <ButtonRule>[
            .always(style: .derive(textStyle: .parts(color: .value(red)))),
            .always(style: .derive(textStyle: .fromToken(.textStyle))),
          ],
          at(allEnvironments.first)).textStyle!;
      expect(withColor.color, green);
      // A token is never partial: CupertinoTokenRule(textStyle: TextStyle(fontSize: 12))
      // merges over the default token, so the token still has a color and
      // beats the patch too.
      final TextStyle tokenNoColor = resolveButton(
          StyleNode.root(rules: const <Rule>[CupertinoTokenRule(textStyle: TextStyle(fontSize: 12))]),
          const <ButtonRule>[
            .always(style: .derive(textStyle: .parts(color: .value(red)))),
            .always(style: .derive(textStyle: .fromToken(.textStyle))),
          ],
          at(allEnvironments.first)).textStyle!;
      expect(tokenNoColor.color, isNot(red));
      expect(tokenNoColor.color, isNotNull);
      // A derived whole that really has no color (a callback) keeps the
      // earlier patch.
      final TextStyle noColor = resolveButton(StyleNode.root(), const <ButtonRule>[
        .always(style: .derive(textStyle: .parts(color: .value(red)))),
        .always(style: .derive(textStyle: .computed(smallText))),
      ], at(allEnvironments.first)).textStyle!;
      expect(noColor.color, red);
      expect(noColor.fontSize, 12);
    });
  });
}
