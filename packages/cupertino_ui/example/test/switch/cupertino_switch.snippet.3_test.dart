// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:cupertino_ui_examples/switch/cupertino_switch.snippet.3.dart'
    as example;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Switch thumb icon is affected by whether it is enabled', (
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

    await tester.pumpWidget(buildApp(onChanged: (bool _) {}));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSwitch), isNot(paints..paragraph()));

    await tester.pumpWidget(buildApp(onChanged: null));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoSwitch), paints..paragraph());

    final CupertinoSwitch disabledSwitch = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch),
    );
    expect(
      disabledSwitch.thumbIcon?.resolve(<WidgetState>{
        WidgetState.disabled,
      })?.icon,
      Icons.close,
    );
  });
}
