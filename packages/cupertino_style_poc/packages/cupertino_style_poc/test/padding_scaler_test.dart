// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// padding + paddingScaler: the base padding and the text-scale policy are
// two plain style fields. Checks the numbers against Material's
// ButtonStyleButton.scaledPadding, the null rule (overriding one field
// keeps the other) and turning the scaling off with .identity().
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/material.dart' show ButtonStyleButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/resolve_own.dart';

// Material 3 elevated / filled / outlined: 24 -> 12 -> 6 horizontally.
const PaddingScaler m3 = PaddingScaler.stops(<(double, double)>[(1, 1), (2, 0.5), (3, 0.25)]);

Widget app(double textScale, List<Rule> rules, Widget button) => inEnvironment(
      allEnvironments.first,
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: StyleTheme(rules: rules, child: button),
        ),
      ),
    );

EdgeInsetsGeometry laidOutPadding(WidgetTester tester) => tester
    .widget<Padding>(find.descendant(of: find.byType(Button), matching: find.byType(Padding)).first)
    .padding;

const List<double> scales = <double>[0.8, 1.0, 1.3, 2.0, 2.5, 3.0, 4.0];

void main() {
  group('matches ButtonStyleButton.scaledPadding (font size 14)', () {
    test('M3 proportional: .stops', () {
      const EdgeInsets base = EdgeInsets.symmetric(horizontal: 24);
      for (final double k in scales) {
        expect(
          m3.apply(base, TextScaler.linear(k), 14),
          ButtonStyleButton.scaledPadding(
              base, const EdgeInsets.symmetric(horizontal: 12), const EdgeInsets.symmetric(horizontal: 6), k),
          reason: 'text scale $k',
        );
      }
    });

    test('M3 icon variant, directional: .stops', () {
      const EdgeInsetsDirectional base = EdgeInsetsDirectional.fromSTEB(16, 0, 24, 0);
      for (final double k in scales) {
        expect(
          m3.apply(base, TextScaler.linear(k), 14),
          ButtonStyleButton.scaledPadding(base, const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
              const EdgeInsetsDirectional.fromSTEB(4, 0, 6, 0), k),
          reason: 'text scale $k',
        );
      }
    });

    test('M2 icon variant, not proportional: .absolute', () {
      const EdgeInsetsDirectional base = EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0);
      const PaddingScaler m2Icon = PaddingScaler.absolute(<(double, EdgeInsetsGeometry)>[
        (2, EdgeInsets.symmetric(horizontal: 8)),
        (3, EdgeInsetsDirectional.fromSTEB(8, 0, 4, 0)),
      ]);
      for (final double k in scales) {
        final EdgeInsetsGeometry ours = m2Icon.apply(base, TextScaler.linear(k), 14);
        final EdgeInsetsGeometry material = ButtonStyleButton.scaledPadding(
            base, const EdgeInsets.symmetric(horizontal: 8), const EdgeInsetsDirectional.fromSTEB(8, 0, 4, 0), k);
        for (final TextDirection d in TextDirection.values) {
          expect(ours.resolve(d), material.resolve(d), reason: 'text scale $k, $d');
        }
      }
    });

    test('a nonlinear scaler is measured on the font size', () {
      // Scales 14 to 28 (x2) but 20 to 30 (x1.5).
      final TextScaler nonlinear = _ClampScaler();
      const EdgeInsets base = EdgeInsets.symmetric(horizontal: 24);
      expect(m3.apply(base, nonlinear, 14), const EdgeInsets.symmetric(horizontal: 12));
      expect(m3.apply(base, nonlinear, 20), const EdgeInsets.symmetric(horizontal: 18));
    });
  });

  group('in rules', () {
    const List<Rule> theme = <Rule>[
      ButtonRule.always(style: ButtonStyle(padding: EdgeInsets.all(10), paddingScaler: m3)),
    ];
    final Widget button = Button(onPressed: () {}, child: const Text('b'));

    testWidgets('the library default is .identity(): Cupertino padding does not scale', (WidgetTester tester) async {
      await tester.pumpWidget(app(2.0, const <Rule>[], button));
      expect(laidOutPadding(tester), const EdgeInsets.symmetric(vertical: 16, horizontal: 20)); // large (default size)
    });

    testWidgets('a theme sets base and scaler; the widget applies them at layout', (WidgetTester tester) async {
      for (final (double k, double expected) in <(double, double)>[(1.0, 10), (1.5, 7.5), (2.0, 5), (3.0, 2.5)]) {
        await tester.pumpWidget(app(k, theme, button));
        expect(laidOutPadding(tester), EdgeInsets.all(expected), reason: 'text scale $k');
      }
    });

    testWidgets('the resolved style holds the base and the scaler, unscaled', (WidgetTester tester) async {
      await tester.pumpWidget(app(2.0, theme, button));
      final ButtonStyle s = tester.widget<Button>(find.byType(Button)).resolveOwn(tester.element(find.byType(Button)));
      expect(s.padding, const EdgeInsets.all(10));
      expect(s.paddingScaler, m3);
    });

    testWidgets('overriding padding keeps the scaler (null = unset)', (WidgetTester tester) async {
      await tester.pumpWidget(app(2.0, theme, Button(padding: const EdgeInsets.all(20), onPressed: () {}, child: const Text('b'))));
      expect(laidOutPadding(tester), const EdgeInsets.all(10));
    });

    testWidgets('.identity() in a later rule turns the scaling off', (WidgetTester tester) async {
      await tester.pumpWidget(app(
          2.0,
          <Rule>[...theme, const ButtonRule.always(style: .values(paddingScaler: .identity()))],
          button));
      expect(laidOutPadding(tester), const EdgeInsets.all(10));
    });

    testWidgets('dot shorthands: .values(paddingScaler: .stops(...)) and .derive(paddingScaler: .value(...))',
        (WidgetTester tester) async {
      const List<Rule> rules = <Rule>[
        ButtonRule.always(style: .values(padding: .all(8), paddingScaler: .stops([(1, 1), (2, 2)]))),
      ];
      await tester.pumpWidget(app(1.5, rules, button));
      expect(laidOutPadding(tester), const EdgeInsets.all(12));
      const List<Rule> derived = <Rule>[
        ButtonRule.always(style: .derive(padding: .value(.all(8)), paddingScaler: .value(.identity()))),
      ];
      await tester.pumpWidget(app(1.5, derived, button));
      expect(laidOutPadding(tester), const EdgeInsets.all(8));
    });
  });

  test('value equality (rules compare payloads)', () {
    expect(const PaddingScaler.identity(), const PaddingScaler.identity());
    expect(m3, PaddingScaler.stops(<(double, double)>[(1, 1), (2, 0.5), (3, 0.25)]));
    expect(m3.hashCode, PaddingScaler.stops(<(double, double)>[(1, 1), (2, 0.5), (3, 0.25)]).hashCode);
    expect(m3 == const PaddingScaler.stops(<(double, double)>[(1, 1), (2, 0.5)]), isFalse);
    // Stops in another order give the same padding but are not == (per spelling, like rules).
    final PaddingScaler reordered = PaddingScaler.stops(<(double, double)>[(3, 0.25), (1, 1), (2, 0.5)]);
    expect(reordered.apply(const EdgeInsets.all(8), const TextScaler.linear(1.5), 14),
        m3.apply(const EdgeInsets.all(8), const TextScaler.linear(1.5), 14));
    expect(m3 == const PaddingScaler.identity(), isFalse);
  });
}

class _ClampScaler extends TextScaler {
  @override
  double scale(double fontSize) => fontSize <= 14 ? fontSize * 2 : fontSize * 1.5;

  @override
  double get textScaleFactor => 2;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) => this;
}
