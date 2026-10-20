// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Widget tests of the demo app: one group per section.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_style_poc_example/main.dart';
import 'package:cupertino_ui/cupertino_ui.dart' hide CupertinoButton, CupertinoSwitch;
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpDemo(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const DemoApp());
  await tester.pumpAndSettle();
}

Future<void> goDark(WidgetTester tester) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('brightness')), matching: find.text('Dark')));
  await tester.pumpAndSettle();
}

ShapeDecoration decorationOf(WidgetTester tester, Finder button) => tester
    .widget<DecoratedBox>(find.descendant(of: button, matching: find.byType(DecoratedBox)).first)
    .decoration as ShapeDecoration;

Color? backgroundOf(WidgetTester tester, String key) => decorationOf(tester, find.byKey(Key(key))).color;

BorderRadiusGeometry radiusOf(WidgetTester tester, String key) =>
    (decorationOf(tester, find.byKey(Key(key))).shape as RoundedSuperellipseBorder).borderRadius;

Color? textColorOf(WidgetTester tester, String key) {
  final Element text = tester.element(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text)).first);
  return DefaultTextStyle.of(text).style.color;
}

Color? iconColorOf(WidgetTester tester, String key) {
  final Element icon = tester.element(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Icon)));
  return IconTheme.of(icon).color;
}

int argb(Color? c) => c!.toARGB32();

void main() {
  group('1. call site', () {
    testWidgets('dynamic colors resolve per brightness, including the switch outline and track', (WidgetTester tester) async {
      await pumpDemo(tester);
      final Finder sw = find.byKey(const Key('green-switch'));
      SwitchStyle style() => tester.widget<Switch>(sw).resolveStyle(tester.element(sw), selected: true);
      expect(argb(style().trackColor), argb(CupertinoColors.systemGreen.color));
      expect(argb(style().trackOutlineColor), argb(CupertinoColors.label.color));
      expect(argb(backgroundOf(tester, 'red-button')), argb(CupertinoColors.systemRed.color));
      expect(argb(textColorOf(tester, 'red-button')), argb(CupertinoColors.label.color));

      await goDark(tester);
      expect(argb(style().trackColor), argb(CupertinoColors.systemGreen.darkColor));
      expect(argb(style().trackOutlineColor), argb(CupertinoColors.label.darkColor));
      expect(argb(backgroundOf(tester, 'red-button')), argb(CupertinoColors.systemRed.darkColor));
      expect(argb(textColorOf(tester, 'red-button')), argb(CupertinoColors.label.darkColor));
    });

    testWidgets('states: [pressed] changes only the pressed look', (WidgetTester tester) async {
      await pumpDemo(tester);
      final Color? rest = backgroundOf(tester, 'pressed-tweak');
      final Color? disabledRest = backgroundOf(tester, 'pressed-tweak-disabled');
      // Rest: the default tinted background (primary at 12%).
      expect(argb(rest), argb(CupertinoColors.systemBlue.color.withAlpha(31)));
      expect(argb(disabledRest), argb(CupertinoColors.tertiarySystemFill.color));

      final TestGesture g = await tester.startGesture(tester.getCenter(find.byKey(const Key('pressed-tweak'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(argb(backgroundOf(tester, 'pressed-tweak')), argb(CupertinoColors.systemOrange.color));
      await g.up();
      await tester.pumpAndSettle();
      expect(backgroundOf(tester, 'pressed-tweak'), rest);

      // The disabled twin can't be pressed; its look never changes.
      final TestGesture g2 = await tester.startGesture(tester.getCenter(find.byKey(const Key('pressed-tweak-disabled'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(backgroundOf(tester, 'pressed-tweak-disabled'), disabledRest);
      await g2.up();
      await tester.pumpAndSettle();
    });
  });

  group('2. theme + scope + dialog', () {
    testWidgets('the scope overrides only the background; theme radius and dark-pressed rule survive', (WidgetTester tester) async {
      await pumpDemo(tester);
      await goDark(tester);
      // Theme: Brand accent (teal, dark variant) and radius 8.
      expect(argb(backgroundOf(tester, 'theme-button')), argb((BrandPalettes.teal.accent as CupertinoDynamicColor).darkColor));
      expect(radiusOf(tester, 'theme-button'), const BorderRadius.all(Radius.circular(8)));
      // Scope: orange background, radius from the theme.
      expect(argb(backgroundOf(tester, 'scope-button')), argb(CupertinoColors.systemOrange.darkColor));
      expect(radiusOf(tester, 'scope-button'), const BorderRadius.all(Radius.circular(8)));
      // Dark + pressed (theme rule) still applies inside the scope.
      final TestGesture g = await tester.startGesture(tester.getCenter(find.byKey(const Key('scope-button'))));
      await tester.pump(const Duration(milliseconds: 300));
      expect(argb(textColorOf(tester, 'scope-button')), argb(CupertinoColors.systemYellow.darkColor));
      expect(argb(backgroundOf(tester, 'scope-button')), argb(CupertinoColors.systemOrange.darkColor));
      await g.up();
      await tester.pumpAndSettle();
      // The switch in the same scope keeps the theme's Brand track.
      final Finder themeSwitch = find.descendant(of: find.byKey(const Key('theme-switch')), matching: find.byType(Switch));
      final Finder scopeSwitch = find.descendant(of: find.byKey(const Key('scope-switch')), matching: find.byType(Switch));
      final SwitchStyle a = tester.widget<Switch>(themeSwitch).resolveStyle(tester.element(themeSwitch), selected: true);
      final SwitchStyle b = tester.widget<Switch>(scopeSwitch).resolveStyle(tester.element(scopeSwitch), selected: true);
      expect(argb(b.trackColor), argb((BrandPalettes.teal.accent as CupertinoDynamicColor).darkColor));
      expect(b, a);
    });

    testWidgets('the dialog inherits the scope chain of the caller', (WidgetTester tester) async {
      await pumpDemo(tester);
      await tester.tap(find.byKey(const Key('open-dialog')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dialog-button')), findsOneWidget);
      expect(argb(backgroundOf(tester, 'dialog-button')), argb(CupertinoColors.systemOrange.color));
      expect(radiusOf(tester, 'dialog-button'), const BorderRadius.all(Radius.circular(8)));
      // The theme rules reach the dialog too (theme switch rule: Brand
      // track). Liveness of the theme part is tested in the package tests.
      final Finder dialogSwitch = find.descendant(of: find.byKey(const Key('dialog-switch')), matching: find.byType(Switch));
      expect(argb(tester.widget<Switch>(dialogSwitch).resolveStyle(tester.element(dialogSwitch), selected: true).trackColor),
          argb((BrandPalettes.teal.accent as CupertinoDynamicColor).color));
    });
  });

  group('3. derive', () {
    testWidgets('icon follows the foreground; a plain rule breaks it for the icon only', (WidgetTester tester) async {
      await pumpDemo(tester);
      final int pink = argb(CupertinoColors.systemPink.color);
      expect(argb(iconColorOf(tester, 'derive-follow')), pink);
      expect(argb(textColorOf(tester, 'derive-follow')), pink);
      expect(argb(iconColorOf(tester, 'derive-break')), argb(CupertinoColors.systemGrey.color));
      expect(argb(textColorOf(tester, 'derive-break')), pink);
      await goDark(tester);
      expect(argb(iconColorOf(tester, 'derive-follow')), argb(CupertinoColors.systemPink.darkColor));
      expect(argb(iconColorOf(tester, 'derive-break')), argb(CupertinoColors.systemGrey.darkColor));
    });
  });

  group('4. channel isolation', () {
    testWidgets('changing the scope button rule rebuilds the button and not the switch', (WidgetTester tester) async {
      await pumpDemo(tester);
      final int button0 = isolationBuildCounts[isolationButtonKey] ?? 0;
      final int switch0 = isolationBuildCounts[isolationSwitchKey] ?? 0;
      final Color? before = backgroundOf(tester, 'iso-button');
      await tester.tap(find.byKey(const Key('toggle-rule')));
      await tester.pumpAndSettle();
      expect(isolationBuildCounts[isolationButtonKey], greaterThan(button0));
      expect(isolationBuildCounts[isolationSwitchKey] ?? 0, switch0, reason: 'the switch must not rebuild');
      expect(backgroundOf(tester, 'iso-button'), isNot(before));
      expect(argb(backgroundOf(tester, 'iso-button')), argb(CupertinoColors.systemGreen.color));
      expect(find.textContaining('switch $switch0'), findsOneWidget);

      // A global change (brand tokens) reaches both.
      await tester.tap(find.descendant(of: find.byKey(const Key('brand')), matching: find.text('Brand: purple')));
      await tester.pumpAndSettle();
      expect(isolationBuildCounts[isolationSwitchKey], greaterThan(switch0));
    });
  });
}
