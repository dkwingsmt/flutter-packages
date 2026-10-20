// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Shared helpers for the tests: environment wrappers and pixel capture.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoTheme, CupertinoThemeData, CupertinoUserInterfaceLevel, CupertinoUserInterfaceLevelData;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// RGBA pixels and size of a capture.
typedef Pixels = (Size, Uint8List);

/// The 8 environment combinations.
final List<ResolvedEnvironment> allEnvironments = <ResolvedEnvironment>[
  for (final Brightness b in Brightness.values)
    for (final bool hc in <bool>[false, true])
      for (final CupertinoUserInterfaceLevelData l in CupertinoUserInterfaceLevelData.values)
        ResolvedEnvironment(brightness: b, highContrast: hc, interfaceLevel: l),
];

const Key captureKey = ValueKey<String>('capture');

/// [child] in environment [env] the way an app sets it up today
/// (CupertinoTheme brightness, MediaQuery highContrast,
/// CupertinoUserInterfaceLevel), inside a capture boundary.
Widget inEnvironment(ResolvedEnvironment env, Widget child, {bool onOffLabels = false}) {
  return MediaQuery(
    data: MediaQueryData(highContrast: env.highContrast, onOffSwitchLabels: onOffLabels),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: CupertinoTheme(
        data: CupertinoThemeData(brightness: env.brightness),
        child: CupertinoUserInterfaceLevel(
          data: env.interfaceLevel,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: captureKey,
              child: Padding(padding: const EdgeInsets.all(8), child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The pixels (RGBA) and size of the capture boundary.
Future<(Size, Uint8List)> capture(WidgetTester tester) async {
  final RenderRepaintBoundary rb = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
  final (Size, Uint8List)? out = await tester.runAsync(() async {
    final ui.Image img = await rb.toImage();
    final ByteData? bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final Size size = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return (size, bd!.buffer.asUint8List());
  });
  return out!;
}

bool samePixels((Size, Uint8List) a, (Size, Uint8List) b) {
  if (a.$1 != b.$1 || a.$2.length != b.$2.length) {
    return false;
  }
  for (int i = 0; i < a.$2.length; i++) {
    if (a.$2[i] != b.$2[i]) {
      return false;
    }
  }
  return true;
}

/// Interaction state to drive before capturing.
enum Interaction { rest, disabled, pressed, focused, hovered }

/// Pumps [build] (given a focus node), drives [interaction], captures,
/// and releases the gesture.
Future<(Size, Uint8List)> pumpAndCapture(
  WidgetTester tester,
  Widget Function(FocusNode focusNode) build,
  Interaction interaction, {
  required ResolvedEnvironment env,
  bool onOffLabels = false,
}) async {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  final FocusNode focusNode = FocusNode();
  await tester.pumpWidget(inEnvironment(env, build(focusNode), onOffLabels: onOffLabels));
  TestGesture? gesture;
  switch (interaction) {
    case Interaction.rest:
    case Interaction.disabled:
      break;
    case Interaction.focused:
      focusNode.requestFocus();
      await tester.pump();
    case Interaction.pressed:
      gesture = await tester.startGesture(tester.getCenter(find.byKey(captureKey)));
      await tester.pump(const Duration(milliseconds: 500));
    case Interaction.hovered:
      gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byKey(captureKey)));
      await tester.pump(const Duration(milliseconds: 500));
  }
  await tester.pumpAndSettle();
  final (Size, Uint8List) pixels = await capture(tester);
  if (gesture != null) {
    if (interaction == Interaction.hovered) {
      await gesture.removePointer();
    } else {
      await gesture.up();
    }
  }
  // Reset the tree so the next case starts fresh (new State).
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  focusNode.dispose();
  return pixels;
}

String envName(ResolvedEnvironment e) =>
    '${e.brightness.name}${e.highContrast ? '+hc' : ''}${e.interfaceLevel == CupertinoUserInterfaceLevelData.elevated ? '+elevated' : ''}';
