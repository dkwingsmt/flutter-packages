// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Control for test/type_safety_test.dart: the correctly typed versions of
// the snippets under type_errors/ compile without errors or warnings.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:flutter/widgets.dart';

EdgeInsets padding(ButtonView s) => const EdgeInsets.all(8);
Color color(ButtonView s) => s.token(.primaryColor);
Color fromField(ButtonView s) => s.field(.foregroundColor) ?? const Color(0xFF000000);
Color fromBrand(ButtonView s) => s.customToken(Brand.accent);

const List<ButtonStyleSpec> ok = <ButtonStyleSpec>[
  ButtonStyleSpec(padding: .fromField(.padding)),
  ButtonStyleSpec(backgroundColor: .opacity(.fromField(.foregroundColor), 0.5)),
  ButtonStyleSpec(backgroundColor: .opacity(.fromToken(.primaryColor), 0.5)),
  ButtonStyleSpec(backgroundColor: .opacity(.fromCustomToken(Brand.accent), 0.5)),
  ButtonStyleSpec(backgroundColor: .opacity(.value(Color(0xFF000000)), 0.5)),
  ButtonStyleSpec(backgroundColor: .opacity(.opaque(.computed(color)), 0.5)),
  ButtonStyleSpec(backgroundColor: .value(Color(0xFF000000))),
  ButtonStyleSpec(backgroundColor: .fromField(.focusColor)),
  ButtonStyleSpec(textStyle: .parts(color: .fromField(.foregroundColor))),
  ButtonStyleSpec(textStyle: .parts(decorationColor: .opacity(.fromToken(.primaryColor), 0.3))),
  ButtonStyleSpec(iconTheme: .parts(color: .fromCustomToken(Brand.accent))),
  ButtonStyleSpec(side: .parts(color: .value(Color(0xFF000000)))),
  ButtonStyleSpec(side: .value(BorderSide(width: 2))),
  ButtonStyleSpec(textStyle: .fromToken(.actionTextStyle)),
  ButtonStyleSpec(backgroundColor: .fromCustomToken(Brand.accent)),
  ButtonStyleSpec(backgroundColor: .fromToken(.tintedFill)),
  ButtonStyleSpec(padding: .computed(padding), backgroundColor: .computed(color), focusColor: .computed(fromField)),
  ButtonStyleSpec(foregroundColor: .computed(fromBrand)),
  ButtonStyleSpec(padding: .value(EdgeInsets.all(1))),
  ButtonStyleSpec.derive(pressedOpacity: .value(0.5)),
  ButtonStyleSpec.values(backgroundColor: Color(0xFF000000)),
  ButtonStyle(backgroundColor: Color(0xFF000000)),
];

const List<Rule> okRules = <Rule>[
  ButtonRule(ButtonWhen(pressed: true), style: .values(backgroundColor: Color(0xFF000000))),
  ...<ButtonRule>[
    .when(pressed: true, appearance: {.tinted}, style: .values(backgroundColor: Color(0xFF000000))),
    .always(style: .derive(iconTheme: .parts(color: .fromField(.foregroundColor)))),
    .whenAny([ButtonWhen(pressed: true), ButtonWhen(focused: true)], style: .values(padding: EdgeInsets.zero)),
    .backgroundColor(tintedEnabled: Color(0xFF000000)),
  ],
  ...<SwitchRule>[
    .when(selected: true, style: .derive(trackColor: .opaque(.fromField(.thumbColor)))),
    .always(style: .values(opacity: 1.0)),
  ],
  BrandRule(accent: Color(0xFF000000), cornerRadius: 4),
  CupertinoTokenRule(primaryColor: Color(0xFF000000)),
];

final List<TokenRule> okTokenRules = <TokenRule>[
  Brand.accent.set(const Color(0xFF000000)),
  Brand.cornerRadius.set(4),
  Brand.pressedAccent.setFrom(.opacity(.fromCustomToken(Brand.accent), 0.5)),
  Brand.onAccent.setFrom(.opaque(.fromToken(.primaryContrastingColor))),
  Brand.cornerRadius.setFrom(.value(4.0)),
  CupertinoToken.tintedFill.setFrom(.opacity(.fromToken(.primaryColor), 0.2)),
  ...BrandRule.teal,
];

Color readAccent(Tokens t) => t.read(Brand.accent);
Color readAccentOf(BuildContext context) => Brand.accent.of(context);
double readRadiusOf(BuildContext context) => Brand.cornerRadius.of(context);
Color readPrimaryOf(BuildContext context) => CupertinoToken.primaryColor.of(context);
const CupertinoTokenRule okDerive = CupertinoTokenRule.derive(
    tintedFill: .opacity(.fromToken(.primaryColor), 0.2), textStyle: .fromToken(.actionTextStyle));

const SwitchStyleSpec okSwitch = SwitchStyleSpec(trackColor: .fromField(.thumbColor));
const ButtonStyleSpec okVariable = ButtonStyleSpec(backgroundColor: fg);
const ButtonColorSource fg = .fromField(.foregroundColor);
