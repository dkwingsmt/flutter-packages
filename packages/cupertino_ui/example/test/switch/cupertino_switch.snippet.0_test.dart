// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:cupertino_ui_examples/switch/cupertino_switch.snippet.0.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CupertinoSwitch with MergeSemantics toggles on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            middle: Text('CupertinoSwitch Example'),
          ),
          child: SafeArea(child: example.CupertinoSwitchExample()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final CupertinoSwitch switchWidget = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch),
    );
    expect(switchWidget.value, isFalse);

    await tester.tap(find.byType(CupertinoListTile));
    await tester.pumpAndSettle();

    final CupertinoSwitch switchedWidget = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch),
    );
    expect(switchedWidget.value, isTrue);
  });
}
