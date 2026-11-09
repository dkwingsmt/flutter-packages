// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The generated API beyond the rule classes: XStyle.lerp, the static
// X.resolveStyle (design doc 7.6) and the context-free resolve entry.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoApp, CupertinoColors, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ButtonStyle.lerp interpolates paint values and switches the rest at 0.5', () {
    const ButtonStyle a = ButtonStyle(
      backgroundColor: Color(0xFF000000),
      pressedOpacity: 0.2,
      padding: EdgeInsets.all(4),
      mouseCursor: SystemMouseCursors.basic,
      side: BorderSide(width: 1),
    );
    const ButtonStyle b = ButtonStyle(
      backgroundColor: Color(0xFFFFFFFF),
      pressedOpacity: 0.6,
      padding: EdgeInsets.all(8),
      mouseCursor: SystemMouseCursors.click,
      side: BorderSide(width: 3),
    );
    final ButtonStyle mid = ButtonStyle.lerp(a, b, 0.5)!;
    expect(mid.backgroundColor, Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5));
    expect(mid.pressedOpacity, closeTo(0.4, 1e-9));
    expect(mid.padding, const EdgeInsets.all(6));
    expect(mid.side!.width, 2);
    expect(ButtonStyle.lerp(a, b, 0.4)!.mouseCursor, SystemMouseCursors.basic);
    expect(ButtonStyle.lerp(a, b, 0.5)!.mouseCursor, SystemMouseCursors.click);
    expect(ButtonStyle.lerp(a, a, 0.3), same(a));
  });

  test('resolveButtonStyleFromRules needs no widget tree', () {
    final ButtonStyle s = resolveButtonStyleFromRules(
      theme: const <Rule>[ButtonRule.backgroundColor(filledEnabled: Color(0xFF123456))],
      appearance: ButtonAppearance.filled,
      sizeStyle: ButtonSize.large,
      brightness: Brightness.dark,
      highContrast: false,
      interfaceLevel: CupertinoUserInterfaceLevelData.base,
    );
    expect(s.backgroundColor, const Color(0xFF123456));
    // Text follows the foreground (the default derive), dark variant.
    expect(s.textStyle!.color, s.foregroundColor);
    final ButtonStyle disabled = resolveButtonStyleFromRules(
      appearance: ButtonAppearance.filled,
      sizeStyle: ButtonSize.large,
      disabled: true,
      brightness: Brightness.light,
      highContrast: false,
      interfaceLevel: CupertinoUserInterfaceLevelData.base,
    );
    expect(disabled.backgroundColor, CupertinoColors.tertiarySystemFill.color);
  });

  testWidgets('Button.resolveStyle reads the theme at a context, with an environment override', (WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(CupertinoApp(
      home: StyleTheme(
        rules: const <Rule>[
          ButtonRule.when(pressed: true, brightness: Brightness.dark, style: ButtonStyle(backgroundColor: Color(0xFF00FF00))),
        ],
        child: Builder(builder: (BuildContext c) {
          ctx = c;
          return const SizedBox();
        }),
      ),
    ));
    expect(Button.resolveStyle(ctx, pressed: true, brightness: Brightness.dark).backgroundColor, const Color(0xFF00FF00));
    expect(Button.resolveStyle(ctx, pressed: true, brightness: Brightness.light).backgroundColor, isNull);
    // Same as the context-free entry with the theme's rules.
    expect(
      Button.resolveStyle(ctx, appearance: ButtonAppearance.tinted, brightness: Brightness.dark),
      resolveButtonStyleFromRules(
        theme: const <Rule>[
          ButtonRule.when(pressed: true, brightness: Brightness.dark, style: ButtonStyle(backgroundColor: Color(0xFF00FF00))),
        ],
        appearance: ButtonAppearance.tinted,
        sizeStyle: ButtonSize.large,
        brightness: Brightness.dark,
        highContrast: false,
        interfaceLevel: CupertinoUserInterfaceLevelData.base,
      ),
    );
  });
}
