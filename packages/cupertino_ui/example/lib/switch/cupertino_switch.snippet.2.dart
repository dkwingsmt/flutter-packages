// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:cupertino_ui/cupertino_ui.dart';

/// Flutter code sample for [CupertinoSwitch].

class CupertinoSwitchExample extends StatelessWidget {
  const CupertinoSwitchExample({super.key, required this.onChanged});

  final ValueChanged<bool>? onChanged;

  ValueChanged<bool>? get _nullableOnChanged => onChanged;
  bool get _value => true;

  @override
  Widget build(BuildContext context) {
    return
    // #region body
    CupertinoSwitch(
      value: _value,
      // If `onChanged` is null, this switch is disabled.
      // If `onChanged` is not null, this switch is enabled.
      onChanged: _nullableOnChanged,
      trackOutlineWidth: WidgetStateProperty.resolveWith<double?>((
        Set<WidgetState> states,
      ) {
        if (states.contains(WidgetState.disabled)) {
          return 5.0;
        }
        return null; // Use the default width.
      }),
    )
    // #endregion body
    ;
  }
}
