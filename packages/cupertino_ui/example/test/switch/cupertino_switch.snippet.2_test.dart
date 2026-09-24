// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:cupertino_ui_examples/switch/cupertino_switch.snippet.2.dart'
    as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Switch track outline width is affected by whether it is enabled',
    (WidgetTester tester) async {
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
      final CupertinoSwitch enabledSwitch = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(enabledSwitch.trackOutlineWidth?.resolve(<WidgetState>{}), isNull);

      await tester.pumpWidget(buildApp(onChanged: null));
      await tester.pumpAndSettle();
      final CupertinoSwitch disabledSwitch = tester.widget<CupertinoSwitch>(
        find.byType(CupertinoSwitch),
      );
      expect(
        disabledSwitch.trackOutlineWidth?.resolve(<WidgetState>{
          WidgetState.disabled,
        }),
        5.0,
      );
    },
  );
}
