// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:cupertino_ui_examples/switch/cupertino_switch.snippet.4.dart'
    as example;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Switch mouse cursor is affected by whether it is enabled', (
    WidgetTester tester,
  ) async {
    Widget buildApp({required ValueChanged<bool>? onChanged}) {
      return CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('CupertinoSwitch Example'),
          ),
          child: SafeArea(
            child: example.CupertinoSwitchExample(onChanged: onChanged),
          ),
        ),
      );
    }

    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 1,
    );

    await tester.pumpWidget(buildApp(onChanged: (bool _) {}));
    await tester.pumpAndSettle();
    await gesture.addPointer(
      location: tester.getCenter(find.byType(CupertinoSwitch)),
    );
    await tester.pump();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.basic,
    );

    await tester.pumpWidget(buildApp(onChanged: null));
    await tester.pumpAndSettle();
    expect(
      RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1),
      SystemMouseCursors.click,
    );
  });
}
