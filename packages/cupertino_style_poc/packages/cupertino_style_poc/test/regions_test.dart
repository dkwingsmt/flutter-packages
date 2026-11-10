// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The hand-written region tables and region constructors (button.g.dart /
// switch.g.dart, "should be generated") against the defaults: on every
// possible minterm, exactly one region of a field matches; a region covers
// the states of exactly one default rule label ('unset' when none) per
// appearance, and a rule (per appearance) belongs to one region. Fields
// without a region constructor have the single region "every state".
// Names describe the region (naming rules of 2026-10-20): every region's
// name is `regionName(...)` of its condition (test/support/region_names.dart),
// and the constructor doc spells, per region, the equivalent rule with the
// region's exact `XWhen(...)` (`whenSource`), checked against the source
// text, as are the constructor parameters and value slots. Then the region rules themselves: const lists, expansion,
// equality, and equivalence with rules written with the region conditions.
//
// Regions are computed by authored rule: the defaults are expanded the way
// a chain is built (dynamic colors into environment-conditioned sub-rules),
// and every sub-rule counts as its authored rule. So a region is "where one
// authored default rule wins the field", never split by environment: each
// region covers exactly one authored rule (per appearance), and no region
// constrains an environment dimension.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'dart:io';

import 'package:cupertino_style_poc/src/button.dart' show buttonRegionTable;
import 'package:cupertino_style_poc/src/engine/engine.dart';
import 'package:cupertino_style_poc/src/switch.dart' show switchRegionTable;
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart'
    show Brightness, Color, EdgeInsets, SizedBox, SystemMouseCursors, WidgetState, WidgetStateColor, WidgetStatesConstraint;
import 'package:flutter_test/flutter_test.dart';

import 'support/region_names.dart';

/// Region rules inside a const rule list: the list is a compile-time
/// constant.
const List<Rule> themeFromRegions = <Rule>[
  ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange),
  ButtonRule.foregroundColor(plainEnabled: CupertinoColors.systemPink, tintedEnabled: CupertinoColors.systemPink),
  // One region only (every state): no region constructor.
  ButtonRule(ButtonWhen(), style: ButtonStyle(padding: EdgeInsets.all(4))),
  SwitchRule.trackColor(selected: CupertinoColors.systemIndigo),
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

/// Every region per field: name -> condition. Fields with a region
/// constructor take its table; every other non-composite field has the
/// single region `anyState` (every state), which the test checks against
/// the defaults like any other region.
Map<F, Map<String, Condition>> regionsOf<F extends Enum, W>(
        ComponentSpec<F> spec, Map<F, List<(String, W)>> table, Condition Function(W) cond) =>
    <F, Map<String, Condition>>{
      for (final F f in spec.fields)
        if (!spec.composites.containsKey(f))
          f: table[f] == null
              ? <String, Condition>{'anyState': Condition(const <Dimension<Object>, Object>{})}
              : <String, Condition>{for (final (String n, W w) in table[f]!) n: cond(w)},
    };

final Map<ButtonField, Map<String, Condition>> buttonRegions =
    regionsOf<ButtonField, ButtonWhen>(buttonStyle.spec, buttonRegionTable, (ButtonWhen w) => w.toCondition());

final Map<SwitchField, Map<String, Condition>> switchRegions =
    regionsOf<SwitchField, SwitchWhen>(switchStyle.spec, switchRegionTable, (SwitchWhen w) => w.toCondition());

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

/// A region constructor as written in the source: the equivalent rule of
/// each region in its doc (region name, `XWhen(...)` source, field), its
/// parameters and its slot assignments, in source order.
class ParsedRegionCtor {
  final List<(String, String, String)> docs = <(String, String, String)>[];
  final List<String> params = <String>[];
  final Map<int, String> slots = <int, String>{};
}

/// Region constructors as written in [path]: field -> constructor.
Map<String, ParsedRegionCtor> parseRegionCtors(String path, String rule) {
  final Map<String, ParsedRegionCtor> out = <String, ParsedRegionCtor>{};
  // The doc gives each region's equivalent `.when` rule (design doc 6.1):
  // `XRule.when(<dims>, style: .values(field: region)),`.
  final RegExp docRe = RegExp('^  /// $rule\\.when\\((.*?)(?:, )?style: \\.values\\((\\w+): (\\w+)\\)\\),\$');
  final RegExp ctorRe = RegExp('^  const $rule\\.(\\w+)\\(\\{\$');
  final RegExp paramRe = RegExp(r'^    \w+\? (\w+),$');
  final RegExp slotRe = RegExp(r'^        _r(\d) = (\w+)[,;]$');
  List<(String, String, String)> pending = <(String, String, String)>[];
  ParsedRegionCtor? current;
  for (final String line in File(path).readAsLinesSync()) {
    final RegExpMatch? d = docRe.firstMatch(line);
    if (d != null) {
      pending.add((d[3]!, d[1]!, d[2]!));
      continue;
    }
    final RegExpMatch? c = ctorRe.firstMatch(line);
    // `.when({...})` takes the condition's dimensions, not regions.
    if (c != null && c[1] == 'when') {
      pending = <(String, String, String)>[];
      current = null;
      continue;
    }
    if (c != null) {
      expect(out.containsKey(c[1]), isFalse, reason: '$rule.${c[1]} twice');
      current = out[c[1]!] = ParsedRegionCtor()..docs.addAll(pending);
      pending = <(String, String, String)>[];
      continue;
    }
    if (!line.startsWith('  ///')) {
      pending = <(String, String, String)>[];
    }
    if (current == null) {
      continue;
    }
    final RegExpMatch? p = paramRe.firstMatch(line);
    if (p != null) {
      current.params.add(p[1]!);
      continue;
    }
    final RegExpMatch? sl = slotRe.firstMatch(line);
    if (sl != null) {
      current.slots[int.parse(sl[1]!)] = sl[2]!;
      continue;
    }
    if (line.trim().isEmpty) {
      current = null;
    }
  }
  return out;
}

/// The Dart source of [when] as the doc writes it: `XWhen(dim: value, ...)`
/// in spec dimension order, bools as literals, enum sets as `{Type.value}`
/// in domain order.
String whenSource(String whenClass, List<Dimension<Object>> dims, Condition when) {
  final Map<Dimension<Object>, Set<Object>> c = when.constraints;
  final List<String> args = <String>[
    for (final Dimension<Object> d in dims)
      if (c[d] case final Set<Object> v)
        d.isBool
            ? '${d.name}: ${v.single}'
            : '${d.name}: {${<String>[for (final Object e in d.domain) if (v.contains(e)) '${e.runtimeType}.${(e as Enum).name}'].join(', ')}}',
  ];
  return '$whenClass(${args.join(', ')})';
}

/// Names, docs, parameters and slots of every region constructor against
/// the region table and the naming function; and only fields with more
/// than one region have a constructor.
void checkCtors<F extends Enum>(
    String rule, String path, RegionNaming naming, Map<F, List<String>> table, Map<F, Map<String, Condition>> regions) {
  final Map<String, ParsedRegionCtor> source = parseRegionCtors(path, rule);
  expect(source.keys.toSet(), <String>{for (final F f in table.keys) f.name}, reason: path);
  regions.forEach((F field, Map<String, Condition> rs) {
    expect(table.containsKey(field), rs.length > 1, reason: '${field.name}: ${rs.length} regions');
  });
  table.forEach((F field, List<String> names) {
    final ParsedRegionCtor ctor = source[field.name]!;
    final String where = '$rule.${field.name}';
    expect(names, regions[field]!.keys.toList(), reason: where);
    // Documented, declared and stored in table order: slot k is region k.
    expect(<String>[for (final (String n, String _, String _) in ctor.docs) n], names, reason: '$where docs');
    expect(ctor.params, names, reason: '$where parameters');
    for (int k = 0; k < names.length; k++) {
      expect(ctor.slots[k], names[k], reason: '$where slot $k');
    }
    final String whenClass = '${rule.substring(0, rule.length - 'Rule'.length)}When';
    for (final (String name, String doc, String docField) in ctor.docs) {
      final Condition when = regions[field]![name]!;
      expect(regionName(naming, <Condition>[when]), name, reason: '$where $name: $when');
      expect('$whenClass($doc)', whenSource(whenClass, naming.dimensions, when), reason: '$where $name doc');
      expect(docField, field.name, reason: '$where $name doc field');
    }
  });
}

Map<ButtonField, Object> resolveButton(StyleNode node, List<ButtonRule> callSite, Minterm m) =>
    StyleResolver<ButtonField>(buttonStyle).resolve(node, callSite, m);

const ResolvedEnvironment light =
    ResolvedEnvironment(brightness: Brightness.light, highContrast: false, interfaceLevel: CupertinoUserInterfaceLevelData.base);

void main() {
  test('ButtonRegions match the defaults', () {
    check<ButtonField>(buttonStyle, buttonRegions);
  });

  test('SwitchRegions match the defaults', () {
    check<SwitchField>(switchStyle, switchRegions);
  });

  test('region constructors: names, docs, parameters and slots follow the tables and the naming function', () {
    checkCtors<ButtonField>('ButtonRule', 'lib/src/button.g.dart', buttonNaming, <ButtonField, List<String>>{
      for (final MapEntry<ButtonField, List<(String, ButtonWhen)>> e in buttonRegionTable.entries)
        e.key: <String>[for (final (String n, ButtonWhen _) in e.value) n],
    }, buttonRegions);
    checkCtors<SwitchField>('SwitchRule', 'lib/src/switch.g.dart', switchNaming, <SwitchField, List<String>>{
      for (final MapEntry<SwitchField, List<(String, SwitchWhen)>> e in switchRegionTable.entries)
        e.key: <String>[for (final (String n, SwitchWhen _) in e.value) n],
    }, switchRegions);
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
    final Condition tinted = buttonRegions[ButtonField.backgroundColor]!['tintedEnabled']!;
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
                  brightness: Brightness.light),
              style: ButtonStyleSpec(backgroundColor: ButtonColorSource.opacity(.fromToken(.primaryColor), 0.12))),
          ButtonRule(ButtonWhen(highContrast: true),
              style: ButtonStyleSpec(textStyle: .parts(color: .fromField(.foregroundColor)))),
          // Not a color field: fine under an environment condition.
          ButtonRule(ButtonWhen(highContrast: true), style: ButtonStyleSpec(textStyle: .fromToken(.actionTextStyle))),
          // A literal under an environment condition is not a derive.
          ButtonRule(ButtonWhen(brightness: Brightness.dark),
              style: ButtonStyleSpec(backgroundColor: .value(CupertinoColors.systemRed))),
        ])
          r.toRaw(),
      ],
    ]);
    expect(findEnvConditionedColorDerives(buttonStyle.spec, old).map((EnvConditionedColorDerive<ButtonField> d) => d.target),
        <String>['backgroundColor', 'textStyle.color']);
  });

  test('region rules work in a const rule list and select the region they name', () {
    const List<Rule> again = <Rule>[
      ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange),
      ButtonRule.foregroundColor(plainEnabled: CupertinoColors.systemPink, tintedEnabled: CupertinoColors.systemPink),
      ButtonRule(ButtonWhen(), style: ButtonStyle(padding: EdgeInsets.all(4))),
      SwitchRule.trackColor(selected: CupertinoColors.systemIndigo),
    ];
    // Canonicalised: the same compile-time constant.
    expect(identical(again, themeFromRegions), isTrue);
    expect(identical(themeFromRegions.first, const ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange)),
        isTrue);

    final StyleNode node = StyleNode.root(rules: themeFromRegions);
    Map<ButtonField, Object> button(ButtonAppearance a, {bool disabled = false}) => resolveButton(
        node,
        const <ButtonRule>[],
        buttonMinterm(disabled: disabled, pressed: false, focused: false, appearance: a, sizeStyle: ButtonSize.large, env: light));
    final Color orange = CupertinoColors.systemOrange.color;
    expect(button(ButtonAppearance.filled)[ButtonField.backgroundColor], orange);
    expect(button(ButtonAppearance.filled, disabled: true)[ButtonField.backgroundColor], isNot(orange));
    expect(button(ButtonAppearance.tinted)[ButtonField.foregroundColor], CupertinoColors.systemPink.color);
    expect(button(ButtonAppearance.tinted, disabled: true)[ButtonField.foregroundColor], isNot(CupertinoColors.systemPink.color));
    expect(button(ButtonAppearance.filled)[ButtonField.foregroundColor], isNot(CupertinoColors.systemPink.color));
    expect(button(ButtonAppearance.plain)[ButtonField.padding], const EdgeInsets.all(4));
  });

  test('a region rule expands into one engine rule per region with a value, in table order, slot k = region k', () {
    // Distinct values in every region: each lands under its own region.
    const List<Color> v = <Color>[Color(0xFF000001), Color(0xFF000002), Color(0xFF000003), Color(0xFF000004), Color(0xFF000005)];
    void expectRegions<F extends Enum>(ComponentRule<F> rule, F field, Map<String, Condition> regions, List<Object> values) {
      final List<RawRule<F>> raws = rule.toRaws();
      expect(raws, hasLength(values.length));
      final List<String> names = regions.keys.toList();
      for (int k = 0; k < raws.length; k++) {
        expect('${raws[k].whens.single}', '${regions[names[k]]}', reason: '${field.name}.${names[k]}');
        expect(raws[k].style.values, <F, Object>{field: values[k]});
        expect(raws[k].label, '${field.name}.${names[k]}');
        expect(raws[k].derive.values, isEmpty);
      }
    }

    expectRegions(
        ButtonRule.backgroundColor(
            plainAnyState: v[0], tintedEnabled: v[1], tintedDisabled: v[2], filledEnabled: v[3], filledDisabled: v[4]),
        ButtonField.backgroundColor,
        buttonRegions[ButtonField.backgroundColor]!,
        v);
    expectRegions(
        ButtonRule.foregroundColor(
            plainEnabled: v[0], plainDisabled: v[1], tintedEnabled: v[2], tintedDisabled: v[3], filledAnyState: v[4]),
        ButtonField.foregroundColor,
        buttonRegions[ButtonField.foregroundColor]!,
        v);
    expectRegions(const ButtonRule.mouseCursor(enabled: SystemMouseCursors.click, disabled: SystemMouseCursors.forbidden),
        ButtonField.mouseCursor, buttonRegions[ButtonField.mouseCursor]!,
        <Object>[SystemMouseCursors.click, SystemMouseCursors.forbidden]);
    expectRegions(SwitchRule.trackColor(unselected: v[0], selected: v[1]), SwitchField.trackColor,
        switchRegions[SwitchField.trackColor]!, v.sublist(0, 2));
    expectRegions(SwitchRule.thumbColor(unselected: v[0], selected: v[1]), SwitchField.thumbColor,
        switchRegions[SwitchField.thumbColor]!, v.sublist(0, 2));
    expectRegions(const SwitchRule.mouseCursor(enabled: SystemMouseCursors.click, disabled: SystemMouseCursors.forbidden),
        SwitchField.mouseCursor, switchRegions[SwitchField.mouseCursor]!,
        <Object>[SystemMouseCursors.click, SystemMouseCursors.forbidden]);
    expectRegions(const SwitchRule.opacity(enabled: 0.9, disabled: 0.3), SwitchField.opacity,
        switchRegions[SwitchField.opacity]!, <Object>[0.9, 0.3]);

    // Unset regions produce no engine rule; a label prefixes the region
    // labels.
    final List<RawRule<ButtonField>> one =
        const ButtonRule.backgroundColor(tintedDisabled: Color(0xFF000009), label: 'brand').toRaws();
    expect(one, hasLength(1));
    expect('${one.single.whens.single}', '${buttonRegions[ButtonField.backgroundColor]!['tintedDisabled']}');
    expect(one.single.label, 'brand/backgroundColor.tintedDisabled');
    // Cached per rule.
    const ButtonRule r = ButtonRule.backgroundColor(tintedDisabled: Color(0xFF000009));
    expect(identical(r.toRaws(), r.toRaws()), isTrue);
  });

  test('a region rule has no single engine rule, needs at least one region, and compares by value', () {
    const ButtonRule region = ButtonRule.backgroundColor(filledEnabled: Color(0xFF000001));
    expect(region.toRaw, throwsStateError);
    expect(region.when, isNull);
    expect(region.whens, isNull);
    const ButtonRule plain = ButtonRule(ButtonWhen(disabled: true), style: ButtonStyle());
    expect(plain.toRaws(), <RawRule<ButtonField>>[plain.toRaw()]);

    expect(() => ButtonRule.backgroundColor(), throwsAssertionError);
    expect(() => SwitchRule.opacity(), throwsAssertionError);
    // Region values are data, like style values: a WidgetStateColor is
    // rejected (the region constructor bypasses ButtonStyle's asserts, so
    // it carries its own).
    final WidgetStateColor colorMap =
        WidgetStateColor.fromMap(<WidgetStatesConstraint, Color>{WidgetState.any: const Color(0xFFFF0000)});
    expect(() => ButtonRule.backgroundColor(tintedEnabled: colorMap), throwsAssertionError);
    expect(() => ButtonRule.foregroundColor(filledAnyState: colorMap), throwsAssertionError);
    expect(() => SwitchRule.trackColor(selected: colorMap), throwsAssertionError);

    // Built at runtime (not canonicalised): equal by value, as theme and
    // scope lists are compared when deciding to notify.
    Color c(int v) => Color(v);
    final ButtonRule a = ButtonRule.backgroundColor(filledEnabled: c(0xFF000001), filledDisabled: c(0xFF000002));
    final ButtonRule b = ButtonRule.backgroundColor(filledEnabled: c(0xFF000001), filledDisabled: c(0xFF000002));
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(ButtonRule.backgroundColor(filledEnabled: c(0xFF000001))));
    // Same value in the same-named region of another field: different rule.
    expect(ButtonRule.backgroundColor(tintedEnabled: c(1)), isNot(ButtonRule.foregroundColor(tintedEnabled: c(1))));
    expect(SwitchRule.trackColor(selected: c(1)), isNot(SwitchRule.thumbColor(selected: c(1))));
    // And not equal to the rule written with the region's condition
    // (same effect, different authored rule).
    expect(region,
        isNot(const ButtonRule(ButtonWhen(appearance: <ButtonAppearance>{ButtonAppearance.filled}, disabled: false),
            style: ButtonStyle(backgroundColor: Color(0xFF000001)))));
  });

  test('a region rule resolves like the rules written with its region conditions, on every state', () {
    const Color a = Color(0xFF00AA00);
    const Color b = Color(0xFF0000AA);
    final Map<String, Condition> bg = buttonRegions[ButtonField.backgroundColor]!;
    final StyleNode viaRegions = StyleNode.root(rules: const <Rule>[
      ButtonRule.backgroundColor(tintedEnabled: a, filledDisabled: b),
      ButtonRule.mouseCursor(disabled: SystemMouseCursors.forbidden),
    ]);
    final StyleNode viaConditions = StyleNode.root(rules: <Rule>[
      ButtonRule(buttonRegionTable[ButtonField.backgroundColor]![1].$2, style: const ButtonStyle(backgroundColor: a)),
      ButtonRule(buttonRegionTable[ButtonField.backgroundColor]![4].$2, style: const ButtonStyle(backgroundColor: b)),
      ButtonRule(buttonRegionTable[ButtonField.mouseCursor]![1].$2,
          style: const ButtonStyle(mouseCursor: SystemMouseCursors.forbidden)),
    ]);
    int states = 0;
    for (final Minterm m in buttonStyle.spec.minterms()) {
      if (buttonStyle.spec.isImpossible(m)) {
        continue;
      }
      expect(resolveButton(viaRegions, const <ButtonRule>[], m), resolveButton(viaConditions, const <ButtonRule>[], m),
          reason: '$m');
      final Object? got = resolveButton(viaRegions, const <ButtonRule>[], m)[ButtonField.backgroundColor];
      if (bg['tintedEnabled']!.matches(m)) {
        expect(got, a);
      } else if (bg['filledDisabled']!.matches(m)) {
        expect(got, b);
      } else {
        expect(got, isNot(anyOf(a, b)));
      }
      states++;
    }
    expect(states, greaterThan(0));
  });

  test('a dynamic color in a region rule is expanded per environment, inside its region only', () {
    final StyleNode node =
        StyleNode.root(rules: const <Rule>[ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemRed)]);
    Object? bg(Brightness br, {bool disabled = false}) => resolveButton(
        node,
        const <ButtonRule>[],
        buttonMinterm(
            disabled: disabled,
            pressed: false,
            focused: false,
            appearance: ButtonAppearance.filled,
            sizeStyle: ButtonSize.medium,
            env: ResolvedEnvironment(
                brightness: br, highContrast: false, interfaceLevel: CupertinoUserInterfaceLevelData.base)))[ButtonField.backgroundColor];
    expect(bg(Brightness.light), CupertinoColors.systemRed.color);
    expect(bg(Brightness.dark), CupertinoColors.systemRed.darkColor);
    expect(bg(Brightness.dark, disabled: true), isNot(CupertinoColors.systemRed.darkColor));
  });

  test('call site: a region rule in rules: follows the flat parameters, an explicit rule after it refines a region', () {
    const Color mint = Color(0xFF00C7BE);
    const Color teal = Color(0xFF30B0C7);
    final List<ButtonRule> callSite = const Button.tinted(
      color: CupertinoColors.systemRed,
      onPressed: null,
      rules: <ButtonRule>[
        ButtonRule.backgroundColor(tintedEnabled: mint),
        ButtonRule(ButtonWhen(pressed: true), style: ButtonStyle(backgroundColor: teal)),
      ],
      child: SizedBox(),
    ).callSiteRules();
    final StyleNode root = StyleNode.root(rules: const <Rule>[]);
    Object? bg({bool disabled = false, bool pressed = false}) => resolveButton(
        root,
        callSite,
        buttonMinterm(
            disabled: disabled,
            pressed: pressed,
            focused: false,
            appearance: ButtonAppearance.tinted,
            sizeStyle: ButtonSize.medium,
            env: light))[ButtonField.backgroundColor];
    expect(bg(), mint); // rules: wins over color:
    expect(bg(pressed: true), teal); // the later explicit rule refines the region
    expect(bg(disabled: true), CupertinoColors.tertiarySystemFill.color); // other regions untouched
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
