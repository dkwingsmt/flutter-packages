// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The hand-written region constants (button.g.dart / switch.g.dart, "should
// be generated") against the defaults: on every possible minterm, exactly
// one constant of a field matches; a constant covers the states of exactly
// one default rule label ('unset' when none) per appearance, and a rule
// (per appearance) belongs to one constant. Names describe the region
// (naming rules of 2026-10-20): every constant's name is
// `regionName(...)` of its condition and its doc comment `regionDoc(...)`
// (test/support/region_names.dart), checked against the source text.
//
// Regions are computed by authored rule: the defaults are expanded the way
// a chain is built (dynamic colors into environment-conditioned sub-rules),
// and every sub-rule counts as its authored rule. So a region is "where one
// authored default rule wins the field", never split by environment: each
// constant covers exactly one authored rule (per appearance), and no
// constant constrains an environment dimension.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'dart:io';

import 'package:cupertino_style_poc/src/engine/engine.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart' show Brightness, Color, EdgeInsets;
import 'package:flutter_test/flutter_test.dart';

import 'support/region_names.dart';

/// Region constants inside a const rule list: the list is a compile-time
/// constant.
const List<Rule> themeFromRegions = <Rule>[
  ButtonRule(ButtonBackgroundColorRegions.filledEnabled,
      style: ButtonStyle(backgroundColor: CupertinoColors.systemOrange)),
  ButtonRule.any(
      <ButtonWhen>[ButtonForegroundColorRegions.plainEnabled, ButtonForegroundColorRegions.tintedEnabled],
      style: ButtonStyle(foregroundColor: CupertinoColors.systemPink)),
  ButtonRule(ButtonPaddingRegions.anyState, style: ButtonStyle(padding: EdgeInsets.all(4))),
  SwitchRule(SwitchTrackColorRegions.selected,
      style: SwitchStyle(trackColor: CupertinoColors.systemIndigo)),
];

void check<F extends Enum>(ComponentStyle<F> c, Map<F, Map<String, Condition>> regions) {
  final List<FlatRule<F>> flat = chain<F>(<List<RawRule<F>>>[c.defaults], spec: c.spec, splitter: cupertinoEnvSplitter);
  final Dimension<Object>? appearance =
      c.spec.dimensions.where((Dimension<Object> d) => d.name == 'appearance').firstOrNull;
  // field -> constant -> non-environment state -> authored winners
  // (null: unset); field -> (authored winner, appearance) -> constants.
  final Map<F, Map<String, Map<String, Set<RawRule<F>?>>>> byState = <F, Map<String, Map<String, Set<RawRule<F>?>>>>{};
  final Map<F, Map<(RawRule<F>?, Object?), Set<String>>> owners = <F, Map<(RawRule<F>?, Object?), Set<String>>>{};
  // field -> constant -> (winning label, appearance).
  final Map<F, Map<String, Set<(String, Object?)>>> labels = <F, Map<String, Set<(String, Object?)>>>{};
  int checked = 0;
  for (final Minterm m in c.spec.minterms()) {
    if (c.spec.isImpossible(m)) {
      continue;
    }
    final String state = <String>[
      for (final Dimension<Object> d in c.spec.dimensions)
        if (!d.environment) '${d.name}=${m[d]}',
    ].join(',');
    final SymbolicStyle<F> s = resolveSymbolic(flat, m, c.spec.fields, composites: c.spec.composites);
    regions.forEach((F field, Map<String, Condition> constants) {
      final String expected = s.winners[field]?.label ?? 'unset';
      final List<String> matching = <String>[
        for (final MapEntry<String, Condition> e in constants.entries)
          if (e.value.matches(m)) e.key,
      ];
      expect(matching.length, 1, reason: '${field.name} at $m: matching $matching');
      ((labels.putIfAbsent(field, () => <String, Set<(String, Object?)>>{})[matching.single] ??= <(String, Object?)>{})
          .add((expected, appearance == null ? null : m[appearance])));
      final RawRule<F>? winner = s.winners[field]?.source;
      ((byState.putIfAbsent(field, () => <String, Map<String, Set<RawRule<F>?>>>{})[matching.single] ??=
              <String, Set<RawRule<F>?>>{})[state] ??= <RawRule<F>?>{})
          .add(winner);
      (owners.putIfAbsent(field, () => <(RawRule<F>?, Object?), Set<String>>{})[
              (winner, appearance == null ? null : m[appearance])] ??= <String>{})
          .add(matching.single);
      checked++;
    });
  }
  expect(checked, greaterThan(0));
  regions.forEach((F field, Map<String, Condition> constants) {
    constants.forEach((String name, Condition when) {
      // No region constrains the environment ...
      for (final Dimension<Object> d in EnvDims.all) {
        expect(when.constrains(d), isFalse, reason: '${field.name} $name constrains ${d.name}');
      }
      // ... and within a region, one authored rule wins in every
      // environment of a state, even where it was expanded into several
      // environment-conditioned sub-rules.
      byState[field]![name]!.forEach((String state, Set<RawRule<F>?> winners) {
        expect(winners, hasLength(1), reason: '${field.name} $name at $state: split by environment');
      });
    });
    // A constant is one region: the states of one rule label (the region
    // identity, 'unset' when no rule sets the field) ...
    labels[field]!.forEach((String name, Set<(String, Object?)> ls) {
      expect(ls.map(((String, Object?) l) => l.$1).toSet(), hasLength(1), reason: '${field.name} $name covers $ls');
    });
    // ... and a region is never split: one authored rule (per appearance)
    // belongs to one constant.
    owners[field]!.forEach(((RawRule<F>?, Object?) k, Set<String> names) {
      expect(names, hasLength(1), reason: '${field.name}: ${k.$2} split over $names');
    });
  });
}

Condition _b(ButtonWhen x) => x.toCondition();
Condition _s(SwitchWhen x) => x.toCondition();

/// Every region constant, per field: identifier -> condition. The test
/// below checks the identifiers against the source of the .g.dart files.
final Map<ButtonField, Map<String, Condition>> buttonRegions = <ButtonField, Map<String, Condition>>{
  ButtonField.backgroundColor: <String, Condition>{
    'plainAnyState': _b(ButtonBackgroundColorRegions.plainAnyState),
    'tintedEnabled': _b(ButtonBackgroundColorRegions.tintedEnabled),
    'tintedDisabled': _b(ButtonBackgroundColorRegions.tintedDisabled),
    'filledEnabled': _b(ButtonBackgroundColorRegions.filledEnabled),
    'filledDisabled': _b(ButtonBackgroundColorRegions.filledDisabled),
  },
  ButtonField.foregroundColor: <String, Condition>{
    'plainEnabled': _b(ButtonForegroundColorRegions.plainEnabled),
    'plainDisabled': _b(ButtonForegroundColorRegions.plainDisabled),
    'tintedEnabled': _b(ButtonForegroundColorRegions.tintedEnabled),
    'tintedDisabled': _b(ButtonForegroundColorRegions.tintedDisabled),
    'filledAnyState': _b(ButtonForegroundColorRegions.filledAnyState),
  },
  ButtonField.padding: <String, Condition>{'anyState': _b(ButtonPaddingRegions.anyState)},
  ButtonField.borderRadius: <String, Condition>{'anyState': _b(ButtonBorderRadiusRegions.anyState)},
  ButtonField.minimumSize: <String, Condition>{'anyState': _b(ButtonMinimumSizeRegions.anyState)},
  ButtonField.alignment: <String, Condition>{'anyState': _b(ButtonAlignmentRegions.anyState)},
  ButtonField.pressedOpacity: <String, Condition>{'anyState': _b(ButtonPressedOpacityRegions.anyState)},
  ButtonField.focusColor: <String, Condition>{'anyState': _b(ButtonFocusColorRegions.anyState)},
  ButtonField.mouseCursor: <String, Condition>{
    'enabled': _b(ButtonMouseCursorRegions.enabled),
    'disabled': _b(ButtonMouseCursorRegions.disabled),
  },
};

final Map<SwitchField, Map<String, Condition>> switchRegions = <SwitchField, Map<String, Condition>>{
  SwitchField.trackColor: <String, Condition>{
    'unselected': _s(SwitchTrackColorRegions.unselected),
    'selected': _s(SwitchTrackColorRegions.selected),
  },
  SwitchField.thumbColor: <String, Condition>{
    'unselected': _s(SwitchThumbColorRegions.unselected),
    'selected': _s(SwitchThumbColorRegions.selected),
  },
  SwitchField.trackOutlineColor: <String, Condition>{'anyState': _s(SwitchTrackOutlineColorRegions.anyState)},
  SwitchField.trackOutlineWidth: <String, Condition>{'anyState': _s(SwitchTrackOutlineWidthRegions.anyState)},
  SwitchField.focusColor: <String, Condition>{'anyState': _s(SwitchFocusColorRegions.anyState)},
  SwitchField.onLabelColor: <String, Condition>{'anyState': _s(SwitchOnLabelColorRegions.anyState)},
  SwitchField.offLabelColor: <String, Condition>{'anyState': _s(SwitchOffLabelColorRegions.anyState)},
  SwitchField.thumbImage: <String, Condition>{'anyState': _s(SwitchThumbImageRegions.anyState)},
  SwitchField.thumbIcon: <String, Condition>{'anyState': _s(SwitchThumbIconRegions.anyState)},
  SwitchField.thumbIconColor: <String, Condition>{'anyState': _s(SwitchThumbIconColorRegions.anyState)},
  SwitchField.thumbIconSize: <String, Condition>{'anyState': _s(SwitchThumbIconSizeRegions.anyState)},
  SwitchField.thumbBackdropColor: <String, Condition>{'anyState': _s(SwitchThumbBackdropColorRegions.anyState)},
  SwitchField.mouseCursor: <String, Condition>{
    'enabled': _s(SwitchMouseCursorRegions.enabled),
    'disabled': _s(SwitchMouseCursorRegions.disabled),
  },
  SwitchField.opacity: <String, Condition>{
    'enabled': _s(SwitchOpacityRegions.enabled),
    'disabled': _s(SwitchOpacityRegions.disabled),
  },
};

const RegionNaming buttonNaming = RegionNaming(
  dimensions: ButtonDims.all,
  disabled: ButtonDims.disabled,
  interaction: <Dimension<Object>>[ButtonDims.pressed, ButtonDims.focused],
  semantic: <Dimension<Object>>[],
);

const RegionNaming switchNaming = RegionNaming(
  dimensions: SwitchDims.all,
  disabled: SwitchDims.disabled,
  interaction: <Dimension<Object>>[SwitchDims.pressed, SwitchDims.focused, SwitchDims.hovered],
  semantic: <Dimension<Object>>[SwitchDims.selected],
);

/// Region constants as written in [path]: class -> name -> doc text.
Map<String, Map<String, String>> parseRegionConstants(String path) {
  final Map<String, Map<String, String>> out = <String, Map<String, String>>{};
  String? cls;
  String? doc;
  final RegExp classRe = RegExp(r'^abstract final class (\w+Regions) \{');
  final RegExp constRe = RegExp(r'^  static const \w+When (\w+) =');
  final RegExp docRe = RegExp(r'^  /// (.*)$');
  for (final String line in File(path).readAsLinesSync()) {
    final RegExpMatch? c = classRe.firstMatch(line);
    if (c != null) {
      cls = c[1];
      out[cls!] = <String, String>{};
      continue;
    }
    if (cls == null) {
      continue;
    }
    if (line == '}') {
      cls = null;
      continue;
    }
    final RegExpMatch? d = docRe.firstMatch(line);
    if (d != null) {
      doc = doc == null ? d[1] : '$doc ${d[1]}';
      continue;
    }
    final RegExpMatch? k = constRe.firstMatch(line);
    if (k != null) {
      expect(out[cls]!.containsKey(k[1]), isFalse, reason: '$cls.${k[1]} twice');
      out[cls]![k[1]!] = doc ?? '';
    }
    doc = null;
  }
  return out;
}

String _cap(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

void checkNames<F extends Enum>(String component, String path, RegionNaming naming, Map<F, Map<String, Condition>> regions) {
  final Map<String, Map<String, String>> source = parseRegionConstants(path);
  expect(source.keys.toSet(), <String>{for (final F f in regions.keys) '$component${_cap(f.name)}Regions'}, reason: path);
  regions.forEach((F field, Map<String, Condition> constants) {
    final String cls = '$component${_cap(field.name)}Regions';
    // The map above names every constant of the class, and nothing else.
    expect(source[cls]!.keys.toSet(), constants.keys.toSet(), reason: cls);
    constants.forEach((String name, Condition when) {
      expect(regionName(naming, <Condition>[when]), name, reason: '$cls.$name: $when');
      expect(source[cls]![name], regionDoc(naming, <Condition>[when]), reason: '$cls.$name doc');
    });
  });
}

void main() {
  test('ButtonRegions match the defaults', () {
    check<ButtonField>(buttonStyle, buttonRegions);
  });

  test('SwitchRegions match the defaults', () {
    check<SwitchField>(switchStyle, switchRegions);
  });

  test('region names and doc comments follow the naming function', () {
    checkNames<ButtonField>('Button', 'lib/src/button.g.dart', buttonNaming, buttonRegions);
    checkNames<SwitchField>('Switch', 'lib/src/switch.g.dart', switchNaming, switchRegions);
  });

  test('naming function: the rules beyond the Cupertino cases', () {
    Condition c(Map<Dimension<Object>, Object> m) => Condition(m);
    const BoolDimension d = SwitchDims.disabled;
    const BoolDimension s = SwitchDims.selected;
    const BoolDimension p = SwitchDims.pressed;
    const BoolDimension f = SwitchDims.focused;
    const BoolDimension h = SwitchDims.hovered;
    String n(List<Map<Dimension<Object>, Object>> cubes) => regionName(switchNaming, <Condition>[for (final m in cubes) c(m)]);
    // Rule 1: positive literals; order-implied negations are dropped.
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{h: true, p: false}]), 'hovered');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{h: true, p: false, s: true}]), 'hoveredSelected');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{d: true, s: true}]), 'disabledSelected');
    // Rule 2: every interaction state off.
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{d: false, p: false, f: false, h: false, s: false}]), 'idle');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{p: false, f: false, h: false, s: true}]), 'idleSelected');
    // Rule 3: not disabled, interaction free (a partial exclusion counts).
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{d: false, s: true}]), 'enabledSelected');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{d: false, f: false}]), 'enabled');
    // Rule 4: `anyState` only without any constraint; else the semantic
    // values, else the false literals.
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{}]), 'anyState');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{s: false}]), 'unselected');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{p: false}]), 'notPressed');
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{p: false, s: true}]), 'selected');
    // Several cubes.
    expect(n(<Map<Dimension<Object>, Object>>[<Dimension<Object>, Object>{p: true}, <Dimension<Object>, Object>{h: false, f: true}]),
        'pressedOrFocused');
    // Appearance prefix, enum set joined with Or.
    expect(
        regionName(buttonNaming, <Condition>[
          c(<Dimension<Object>, Object>{
            ButtonDims.appearance: <Object>{ButtonAppearance.tinted, ButtonAppearance.filled},
            ButtonDims.disabled: true,
          }),
        ]),
        'tintedOrFilledDisabled');
    expect(regionDoc(switchNaming, <Condition>[c(<Dimension<Object>, Object>{h: true, p: false})]),
        'Not pressed, hovered; any disabled / selected / focused.');
  });

  test('the tinted background is one enabled region without brightness, though its default expands per environment', () {
    final Condition tinted = ButtonBackgroundColorRegions.tintedEnabled.toCondition();
    expect(tinted.constraints.keys, unorderedEquals(<Dimension<Object>>[ButtonDims.appearance, ButtonDims.disabled]));
    // One authored default rule sets it (with an EnvAlpha) ...
    final List<RawRule<ButtonField>> authored = <RawRule<ButtonField>>[
      for (final RawRule<ButtonField> r in buttonStyle.defaults)
        if (r.derive.values.containsKey(ButtonField.backgroundColor) &&
            r.whens.single.constraints[ButtonDims.appearance]!.contains(ButtonAppearance.tinted))
          r,
    ];
    expect(authored, hasLength(1));
    expect(authored.single.whens.single.constrains(EnvDims.brightness), isFalse);
    // ... while the disabled one (tertiarySystemFill) expands into several
    // environment-conditioned sub-rules that still form one region each.
    final List<FlatRule<ButtonField>> flat = chain<ButtonField>(
        <List<RawRule<ButtonField>>>[buttonStyle.defaults],
        spec: buttonStyle.spec,
        splitter: cupertinoEnvSplitter);
    final List<FlatRule<ButtonField>> disabledBg = <FlatRule<ButtonField>>[
      for (final FlatRule<ButtonField> r in flat)
        if (r.style.values.containsKey(ButtonField.backgroundColor)) r,
    ];
    expect(disabledBg.length, greaterThan(1));
    expect(disabledBg.map((FlatRule<ButtonField> r) => r.source).toSet(), hasLength(1));
  });

  test('library defaults have no environment-conditioned derive on a color field (group derives)', () {
    for (final ComponentStyle<Enum> c in <ComponentStyle<Enum>>[buttonStyle, switchStyle]) {
      final List<FlatRule<Enum>> flat =
          chain<Enum>(<List<RawRule<Enum>>>[c.defaults], spec: c.spec, splitter: cupertinoEnvSplitter);
      expect(findEnvConditionedColorDerives(c.spec, flat), isEmpty, reason: c.spec.name);
    }
    // The check catches the old per-brightness form of the tinted
    // background, and sub-property derives (textStyle.color).
    final List<FlatRule<ButtonField>> old = chain<ButtonField>(<List<RawRule<ButtonField>>>[
      <RawRule<ButtonField>>[
        for (final ButtonRule r in const <ButtonRule>[
          ButtonRule(
              ButtonWhen(
                  appearance: <ButtonAppearance>{ButtonAppearance.tinted},
                  disabled: false,
                  brightness: <Brightness>{Brightness.light}),
              derive: ButtonDerive(backgroundColor: TokenRef(CupertinoTokens.primaryColor, alpha: 0.12))),
          ButtonRule(ButtonWhen(highContrast: true),
              derive: ButtonDerive(textStyleColor: FieldRef(ButtonField.foregroundColor))),
          // Not a color field: fine under an environment condition.
          ButtonRule(ButtonWhen(highContrast: true),
              derive: ButtonDerive(textStyle: CupertinoTokens.actionTextStyle)),
        ])
          r.toRaw(),
      ],
    ]);
    expect(findEnvConditionedColorDerives(buttonStyle.spec, old).map((EnvConditionedColorDerive<ButtonField> d) => d.target),
        <String>['backgroundColor', 'textStyle.color']);
  });

  test('region constants work in a const rule list and select the region they name', () {
    const List<Rule> again = <Rule>[
      ButtonRule(ButtonBackgroundColorRegions.filledEnabled,
          style: ButtonStyle(backgroundColor: CupertinoColors.systemOrange)),
      ButtonRule.any(
          <ButtonWhen>[ButtonForegroundColorRegions.plainEnabled, ButtonForegroundColorRegions.tintedEnabled],
          style: ButtonStyle(foregroundColor: CupertinoColors.systemPink)),
      ButtonRule(ButtonPaddingRegions.anyState, style: ButtonStyle(padding: EdgeInsets.all(4))),
      SwitchRule(SwitchTrackColorRegions.selected,
          style: SwitchStyle(trackColor: CupertinoColors.systemIndigo)),
    ];
    // Canonicalised: the same compile-time constant.
    expect(identical(again, themeFromRegions), isTrue);
    expect(identical(ButtonBackgroundColorRegions.filledEnabled,
        const ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.filled}, disabled: false)),
        isTrue);

    final StyleNode node = StyleNode.root(rules: themeFromRegions);
    final ResolvedEnvironment light = ResolvedEnvironment(
        brightness: Brightness.light, highContrast: false, interfaceLevel: CupertinoUserInterfaceLevelData.base);
    Map<ButtonField, Object> button(ButtonAppearance a, {bool disabled = false}) =>
        StyleResolver<ButtonField>(buttonStyle).resolve(
            node,
            const <ButtonRule>[],
            buttonMinterm(
                disabled: disabled, pressed: false, focused: false, appearance: a, sizeStyle: ButtonSize.large, env: light));
    final Color orange = CupertinoColors.systemOrange.color;
    expect(button(ButtonAppearance.filled)[ButtonField.backgroundColor], orange);
    expect(button(ButtonAppearance.filled, disabled: true)[ButtonField.backgroundColor], isNot(orange));
    expect(button(ButtonAppearance.tinted)[ButtonField.foregroundColor], CupertinoColors.systemPink.color);
    expect(button(ButtonAppearance.filled)[ButtonField.foregroundColor], isNot(CupertinoColors.systemPink.color));
    expect(button(ButtonAppearance.plain)[ButtonField.padding], const EdgeInsets.all(4));
  });

  test('default rule lists have no shadowed (never-winning) rule', () {
    for (final ComponentStyle<Enum> c in <ComponentStyle<Enum>>[buttonStyle, switchStyle]) {
      final List<FlatRule<Enum>> flat = chain<Enum>(<List<RawRule<Enum>>>[c.defaults], splitter: cupertinoEnvSplitter);
      final Map<Minterm, Resolved<Enum>> table = <Minterm, Resolved<Enum>>{
        for (final Minterm m in c.spec.minterms())
          m: () {
            final SymbolicStyle<Enum> s = resolveSymbolic(flat, m, c.spec.fields, composites: c.spec.composites);
            return Resolved<Enum>(const <Enum, Object>{}, s.winners, s.contributors);
          }(),
      };
      expect(findShadowed(c.spec, flat, table), isEmpty, reason: c.spec.name);
    }
  });
}
