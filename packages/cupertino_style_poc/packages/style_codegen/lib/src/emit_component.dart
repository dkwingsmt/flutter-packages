// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Emits a component's generated part file.
library;

import 'model.dart';
import 'regions.dart';
import 'util.dart';

/// A composite field kind: generated source class suffix, value type,
/// `.parts` sub-properties (name, value type) and the engine composite.
final class _Composite {
  const _Composite(this.sourceSuffix, this.valueType, this.parts, this.engine, this.doc);

  final String sourceSuffix;
  final String valueType;
  final List<(String, String)> parts;
  final String engine;
  final String doc;
}

const Map<FieldKind, _Composite> _composites = <FieldKind, _Composite>{
  FieldKind.textStyle: _Composite('TextStyleSource', 'TextStyle', <(String, String)>[('color', 'Color'), ('decorationColor', 'Color')],
      'textStyleComposite', 'the TextStyle slot: a whole TextStyle, or `.parts(...)`, which sets only the given sub-properties'),
  FieldKind.iconTheme: _Composite('IconStyleSource', 'IconThemeData', <(String, String)>[('color', 'Color')], 'iconThemeComposite',
      "the icon style slot (the design's `IconStyle` value type, IconThemeData in this prototype): a whole value, or `.parts(...)`"),
  FieldKind.borderSide: _Composite('BorderSideSource', 'BorderSide', <(String, String)>[('color', 'Color'), ('width', 'double')],
      'borderSideComposite', 'a BorderSide slot: a whole BorderSide (which replaces everything before it), or `.parts(...)`, which changes only those sub-properties of the side the rules before produced'),
};

/// WidgetStateProperty subclasses a style value of this type could be by
/// mistake (debug asserts).
const Map<String, String> _stateTypes = <String, String>{'Color': 'WidgetStateColor', 'MouseCursor': 'WidgetStateMouseCursor'};

/// Emits the part file of [c].
String emitComponent(LibraryModel lib, ComponentModel c, {required String specRelative}) {
  final _C g = _C(lib, c);
  final Map<String, List<Region>> regions = computeRegions(c);
  final Map<String, List<Region>> ctors = <String, List<Region>>{
    for (final MapEntry<String, List<Region>> e in regions.entries)
      if (e.value.length > 1) e.key: e.value,
  };
  for (final MapEntry<String, List<Region>> e in ctors.entries) {
    for (final Region r in e.value) {
      if (r.cubes.length > 1) {
        throw StateError('${c.name}.${e.key} region ${r.name} needs several cubes; region tables hold one condition each '
            '(not supported yet)');
      }
    }
  }
  final int slots = <int>[1, for (final List<Region> r in ctors.values) r.length].reduce((int a, int b) => a > b ? a : b);

  final Out o = Out();
  o.header(specRelative, partOf: c.partOf, ignores: <String>['library_private_types_in_public_api']);

  // ---- emitted declarations and private helpers ----
  final List<String> expressions = <String>[
    for (final RuleModel r in c.defaults)
      for (final EntryModel e in r.entries) ...<String>[
        ?e.expression,
        ...?e.source?.expressions,
        for (final SourceModel s in e.parts?.values ?? const <SourceModel>[]) ...s.expressions,
      ],
  ];
  if (c.emitted.isNotEmpty) {
    o.section('Declared in the spec');
    for (final String d in c.emitted) {
      o.raw(d);
      o.blank();
    }
  }
  final List<String> helpers = copiedHelpers(c.copied, <String>[...expressions, ...c.emitted]);
  if (helpers.isNotEmpty) {
    o.section('Private helpers of the spec (copied)');
    for (final String h in helpers) {
      o.raw(h);
      o.blank();
    }
  }

  g.fieldEnum(o);
  g.dims(o);
  g.when(o);
  g.sources(o);
  g.view(o);
  g.styleSpec(o);
  g.style(o);
  g.rule(o, ctors, slots);
  g.regionTables(o, ctors);
  g.defaults(o);
  g.componentStyle(o);
  g.minterm(o);
  g.resolveHelpers(o);
  return o.toString();
}

final class _C {
  _C(this.lib, this.c);

  final LibraryModel lib;
  final ComponentModel c;

  String get n => c.name;
  String get lc => lowerFirst(c.name);
  String get field => '${n}Field';
  String get when_ => '${n}When';
  String get rule_ => '${n}Rule';
  String get spec => '${n}StyleSpec';
  String get style_ => '${n}Style';
  String get source => '${n}Source';
  String get colorSource => '${n}ColorSource';
  String get viewName => '${n}View';
  String get dimsClass => '${n}Dims';
  String get token => lib.tokenInterface;

  Iterable<FieldModel> get composites => c.fields.where((FieldModel f) => f.isComposite);

  /// Every dimension of the component's conditions: state dims, then the
  /// library's environment dims. [kind] is `bool`, `scalar` (a two-valued
  /// enum: `T?`) or `set` (`Set<T>?`).
  List<_Dim> get allDims => <_Dim>[
        for (final DimModel d in c.dims)
          _Dim(d.name, d.isBool ? 'bool' : d.type, d.isBool ? 'bool' : (d.isScalar ? 'scalar' : 'set'), '$dimsClass.${d.name}'),
        for (final EnvDimModel d in lib.env)
          _Dim(d.name, d.isBool ? 'bool' : d.type, d.isBool ? 'bool' : (d.isScalar ? 'scalar' : 'set'), 'EnvDims.${d.name}'),
      ];


  String slotType(FieldModel f) => switch (f.kind) {
        FieldKind.plain => '$source<${f.type}>',
        FieldKind.color => colorSource,
        _ => '$n${_composites[f.kind]!.sourceSuffix}',
      };

  void fieldEnum(Out o) {
    o.section('Fields');
    o.doc('The fields of [$n], each typed by its value type. Names a field in\n'
        'a source (`$source.fromField(.${c.fields.first.name})`) and in a callback\n'
        '(`s.field(.${c.fields.first.name})`); a field of another type, or of another\n'
        'component, is a compile-time error.');
    o.line('enum $field<T extends Object> {');
    for (final FieldModel f in c.fields) {
      o.line('  ${f.name}<${f.type}>(),');
    }
    o.line('}');
    o.blank();
  }

  void dims(Out o) {
    o.section('Dimensions');
    o.doc('The dimensions of [$n]: its state dimensions, then the environment\n'
        "dimensions of the ${lib.name} library.");
    o.line('abstract final class $dimsClass {');
    for (final DimModel d in c.dims) {
      if (d.doc != null) {
        o.doc(d.doc!, indent: 2);
      }
      if (d.isBool) {
        o.line("  static const BoolDimension ${d.name} = BoolDimension('${d.name}');");
      } else {
        o.line("  static const Dimension<${d.type}> ${d.name} = Dimension<${d.type}>('${d.name}', ${d.type}.values);");
      }
    }
    o.blank();
    o.line('  static const List<Dimension<Object>> all = <Dimension<Object>>[');
    o.line('    ${<String>[for (final DimModel d in c.dims) d.name].join(', ')},');
    o.line('    ${<String>[for (final EnvDimModel d in lib.env) 'EnvDims.${d.name}'].join(', ')},');
    o.line('  ];');
    o.line('}');
    o.blank();
  }

  void when(Out o) {
    o.section('When');
    o.doc('A condition on [$n] states: null = unconstrained. Bool dimensions are\n'
        'tri-state; enum dimensions take a positive set.');
    o.line('@immutable');
    o.line('final class $when_ {');
    o.line('  const $when_({');
    for (final _Dim d in allDims) {
      o.line('    this.${d.name},');
    }
    o.line('  });');
    o.blank();
    for (final _Dim d in allDims) {
      o.line('  final ${d.whenType} ${d.name};');
    }
    o.blank();
    o.line('  Condition toCondition() => Condition(<Dimension<Object>, Object>{');
    for (final _Dim d in allDims) {
      o.line(d.conditionEntry(d.name));
    }
    o.line('      });');
    o.blank();
    o.line('  @override');
    o.line('  bool operator ==(Object other) =>');
    o.line('      other is $when_ &&');
    final List<String> eqs = <String>[
      for (final _Dim d in allDims) d.kind == 'set' ? 'setEquals(other.${d.name}, ${d.name})' : 'other.${d.name} == ${d.name}',
    ];
    for (int i = 0; i < eqs.length; i++) {
      o.line('      ${eqs[i]}${i == eqs.length - 1 ? ';' : ' &&'}');
    }
    o.blank();
    o.line('  @override');
    o.line('  int get hashCode => Object.hash(${<String>[
      for (final _Dim d in allDims) d.kind == 'set' ? '_setHash(${d.name})' : d.name,
    ].join(', ')});');
    o.blank();
    o.line('  @override');
    o.line('  String toString() => toCondition().toString();');
    o.line('}');
    o.blank();
    o.line('// ignore: unused_element');
    o.line('int? _setHash(Set<Object>? s) => s == null ? null : Object.hashAllUnordered(s);');
    o.blank();
    o.line('// ignore: unused_element');
    o.line('double? _lerpDouble(double? a, double? b, double t) =>');
    o.line('    a == null && b == null ? null : (a ?? 0) + ((b ?? 0) - (a ?? 0)) * t;');
    o.blank();
    o.line('// ignore: unused_element');
    o.line('BorderSide? _lerpBorderSide(BorderSide? a, BorderSide? b, double t) =>');
    o.line('    a == null || b == null ? (t < 0.5 ? a : b) : BorderSide.lerp(a, b, t);');
    o.blank();
  }

  void sources(Out o) {
    o.section('Sources');
    final bool hasComposites = composites.isNotEmpty;
    o.doc('The source of one [$spec] slot whose value type is [T]: a literal\n'
        '([$source.value]), another field of the same ${c.description} ([$source.fromField]),\n'
        'a ${lib.name} token ([$source.fromToken]), an app token\n'
        '([$source.fromCustomToken]) or a callback ([$source.computed]).\n'
        '\n'
        'Only constructors: the engine handles the shared [DeriveSource] (its\n'
        'equality included). The parameter types fix the field enum, the token\n'
        'interface and the view type, so a field, token or result of another\n'
        'type is a compile-time error, and dot shorthands work inside:\n'
        '`.fromField(.${c.fields.first.name})`, `.fromToken(.${lib.tokens.first.name})`.\n'
        '\n'
        'Color slots take [$colorSource], which adds `.opacity` and `.opaque`'
        '${hasComposites ? ';\ncomposite slots take ${<String>[for (final FieldModel f in composites) '[$n${_composites[f.kind]!.sourceSuffix}]'].toSet().join(', ')},\nwhich add `.parts`' : ''}.\n'
        'Constructors are not inherited, so each subclass repeats the plain ones.');
    o.line('base class $source<T extends Object> extends DeriveSource {');
    o.doc('A literal value. Style data, not a WidgetStateProperty.', indent: 2);
    o.line('  const $source.value(T super.literal)');
    o.line("      : assert(literal is! WidgetStateProperty<Object?>, 'a style holds data, not a WidgetStateProperty; write one rule per state'),");
    o.line('        super.value();');
    o.blank();
    o.doc('The final value of [field] of the same ${c.description} in the same state.', indent: 2);
    o.line('  const $source.fromField($field<T> super.field) : super.field();');
    o.blank();
    o.doc("A built-in ${lib.name} token, in the ${c.description}'s environment.", indent: 2);
    o.line('  const $source.fromToken($token<T> super.token) : super.token();');
    o.blank();
    o.doc('Any token that implements the engine\'s [Token] (an app token group\n'
        "such as `Brand`), in the ${c.description}'s environment.", indent: 2);
    o.line('  const $source.fromCustomToken(Token<T> super.token) : super.customToken();');
    o.blank();
    o.doc("`compute(s)`, where `s` reads the ${c.description}'s other final values and\n"
        'tokens in the same state ([$viewName]). Use a top-level or static\n'
        'function: its tear-off is a constant, so the rule stays const and\n'
        'equal across rebuilds. An inline closure is a new object on every\n'
        'build. Must be a pure function of what it reads (results are cached).', indent: 2);
    o.line('  const $source.computed(T Function($viewName s) super.function) : super.compute();');
    o.blank();
    o.line('  // For the subclasses.');
    o.line('  const $source._opacity(super.source, super.opacity) : super.opacity();');
    o.line('  const $source._opaque(super.source) : super.opaque();');
    if (hasComposites) {
      o.line('  const $source._parts(super.layout, super.part0, [super.part1]) : super.parts();');
    }
    o.line('}');
    o.blank();

    o.doc('[$source] for Color slots, with two transforms that wrap another\n'
        'color source (a field, a token, a literal, a callback, or another\n'
        'transform):\n'
        '\n'
        "* `.opacity(source, x)`: the result's alpha is `clamp(sourceAlpha * x,\n"
        "  0, 1)`. `x` must be finite and >= 0; above 1 raises a translucent\n"
        "  source's alpha. A fully transparent source stays transparent.\n"
        "* `.opaque(source)`: alpha 1, the source's color channels (a fully\n"
        '  transparent source becomes opaque too).\n'
        '\n'
        '`.opacity(.opaque(x), 0.5)` is x at 50%. `.opacity(.value(c), 0.5)` is\n'
        'the const way to write a translucent dynamic color.');
    o.line('final class $colorSource extends $source<Color> {');
    _plainCtors(o, colorSource);
    o.line('  const $colorSource.opacity($colorSource super.source, super.opacity) : super._opacity();');
    o.line('  const $colorSource.opaque($colorSource super.source) : super._opaque();');
    o.line('}');
    o.blank();

    final Set<FieldKind> done = <FieldKind>{};
    for (final FieldModel f in composites) {
      if (!done.add(f.kind)) {
        continue;
      }
      final _Composite k = _composites[f.kind]!;
      final String cls = '$n${k.sourceSuffix}';
      o.doc('[$source] for ${k.doc}. Each part competes under "last rule wins"\n'
          'on its own; the other properties keep what the rules before produced.');
      o.line('final class $cls extends $source<${k.valueType}> {');
      _plainCtors(o, cls);
      o.blank();
      o.doc('Only the given sub-properties (at least one).', indent: 2);
      final String params = <String>[
        for (final (String p, String t) in k.parts) '${t == 'Color' ? colorSource : '$source<$t>'}? $p',
      ].join(', ');
      o.line('  const $cls.parts({$params})');
      o.line('      : super._parts(const <SubProp>[${<String>[for (final (String p, String _) in k.parts) 'SubProp.$p'].join(', ')}], '
          '${<String>[for (final (String p, String _) in k.parts) p].join(', ')});');
      o.line('}');
      o.blank();
    }
  }

  void _plainCtors(Out o, String cls) {
    o.line('  const $cls.value(super.literal) : super.value();');
    o.line('  const $cls.fromField(super.field) : super.fromField();');
    o.line('  const $cls.fromToken(super.token) : super.fromToken();');
    o.line('  const $cls.fromCustomToken(super.token) : super.fromCustomToken();');
    o.line('  const $cls.computed(super.function) : super.computed();');
  }

  void view(Out o) {
    o.section('Callback view');
    o.doc('What a [$source.computed] callback sees: the final values of one\n'
        '${c.description} in one state, read lazily ([field]: resolved on demand, derives\n'
        'included, memoized per state), the tokens in its environment ([token],\n'
        '[customToken]) and the state itself. Reading a field whose value is\n'
        'being computed (a cycle) throws a RuleError naming it.');
    o.line('extension type const $viewName(StyleView _view) {');
    o.doc('The final value of [field] in this state, or null when unset.', indent: 2);
    o.line('  T? field<T extends Object>($field<T> field) => _view.read(field) as T?;');
    o.blank();
    o.doc("A built-in ${lib.name} token in this state's environment.", indent: 2);
    o.line('  T token<T extends Object>($token<T> token) => _view.readToken(token) as T;');
    o.blank();
    o.doc("An app token ([Token]) in this state's environment. Every token has a\n"
        'default, so an unset one is an error.', indent: 2);
    o.line('  T customToken<T extends Object>(Token<T> token) =>');
    o.line("      _view.readToken(token) as T? ?? (throw RuleError('custom token \${token.name} has no value'));");
    o.blank();
    for (final _Dim d in allDims) {
      o.line('  ${d.viewType} get ${d.name} => _view.minterm[${d.ref}] as ${d.viewType};');
    }
    o.blank();
    o.doc("[color] in this state's environment (an environment-dependent color\n"
        'picks its variant; a plain color is returned as is).', indent: 2);
    o.line('  Color resolveColor(Color color) => _view.resolveEnv(color) as Color;');
    o.line('}');
    o.blank();
  }

  void styleSpec(Out o) {
    o.section('Style spec');
    final FieldModel f0 = c.fields.first;
    o.doc('The payload of a [$rule_]: each slot takes a source (value, field,\n'
        'token, custom token, computed; color slots also `.opacity` / `.opaque`;\n'
        'composite slots also `.parts`).\n'
        '\n'
        '[$style_] is the all-values form of the same class (same storage),\n'
        "reachable as `.values(...)`, so a rule's `style:` takes either. Typed\n"
        'getters exist only on [$style_].\n'
        '\n'
        'Equality is per spelling: `$style_(${f0.name}: x)` and\n'
        '`$spec(${f0.name}: .value(x))` give the same rule result but are not\n'
        '`==`. The same code compares equal (and const instances are\n'
        'canonicalized), so rebuilding with unchanged rules notifies nothing.\n'
        '`$spec(...)` and `$spec.derive(...)` are the same constructor.');
    o.line('@immutable');
    o.line('base class $spec {');
    o.doc('Same as [$spec.derive].', indent: 2);
    o.line('  const $spec({');
    for (final FieldModel f in c.fields) {
      o.line('    ${slotType(f)}? this._${f.name},');
    }
    o.line('  });');
    o.blank();
    o.doc('Every slot takes a source: `style: .derive(${f0.name}: .fromToken(...))`.', indent: 2);
    o.line('  const $spec.derive({');
    for (final FieldModel f in c.fields) {
      o.line('    ${slotType(f)}? this._${f.name},');
    }
    o.line('  });');
    o.blank();
    o.doc('Plain values only: [$style_], written as `style: .values(...)`.', indent: 2);
    o.line('  const factory $spec.values({');
    for (final FieldModel f in c.fields) {
      o.line('    ${f.type}? ${f.name},');
    }
    o.line('  }) = $style_;');
    o.blank();
    o.doc('For [$style_]: plain values in the same slots.', indent: 2);
    o.line('  const $spec._values(');
    for (final FieldModel f in c.fields) {
      o.line('    this._${f.name},');
    }
    o.line('  );');
    o.blank();
    o.line('  // Each slot holds a plain value ($style_) or a $source');
    o.line('  // ($spec).');
    for (final FieldModel f in c.fields) {
      o.line('  final Object? _${f.name};');
    }
    o.blank();
    o.doc('The engine parts of this payload ([splitSlots]).', indent: 2);
    o.line('  (Style<$field>, Derive<$field>, SubMap<$field>) toEngine() => splitSlots<$field>(');
    o.line('        <$field, Object>{');
    for (final FieldModel f in c.fields) {
      o.line('          $field.${f.name}: ?_${f.name},');
    }
    o.line('        },');
    o.line('      );');
    o.blank();
    o.line('  @override');
    o.line('  bool operator ==(Object other) =>');
    o.line('      other is $spec &&');
    o.line('      other.runtimeType == runtimeType &&');
    for (int i = 0; i < c.fields.length; i++) {
      final String x = c.fields[i].name;
      o.line('      other._$x == _$x${i == c.fields.length - 1 ? ';' : ' &&'}');
    }
    o.blank();
    o.line('  @override');
    o.line('  int get hashCode => Object.hash${c.fields.length + 1 > 20 ? 'All(<Object?>[' : '('}runtimeType, '
        '${<String>[for (final FieldModel f in c.fields) '_${f.name}'].join(', ')}${c.fields.length + 1 > 20 ? '])' : ')'};');
    o.line('}');
    o.blank();
  }

  void style(Out o) {
    o.section('Style');
    o.doc('Every themeable property of [$n], as values: the all-values form of\n'
        '[$spec] (same storage; `style: .values(...)`), and the\n'
        'resolved style. Null = not set by this rule. Values are data:\n'
        'closure-style values (WidgetStateColor, WidgetStateMouseCursor) are\n'
        'rejected in debug; environment-dependent values (a dynamic color) are\n'
        'fine (expanded into one plain value per environment when the chain is\n'
        'built).');
    o.line('final class $style_ extends $spec {');
    o.line('  const $style_({');
    for (final FieldModel f in c.fields) {
      o.line('    ${f.type}? ${f.name},');
    }
    final List<String> asserts = <String>[
      for (final FieldModel f in c.fields)
        if (_stateTypes[f.type] case final String st)
          "assert(${f.name} is! WidgetStateProperty<Object?>, '${f.name}: a style holds data, not a $st; write one rule per state')",
    ];
    final String sup = 'super._values(${<String>[for (final FieldModel f in c.fields) f.name].join(', ')})';
    if (asserts.isEmpty) {
      o.line('  }) : $sup;');
    } else {
      o.line('  })  : ${asserts.first},');
      for (final String a in asserts.skip(1)) {
        o.line('        $a,');
      }
      o.line('        $sup;');
    }
    o.blank();
    for (final FieldModel f in c.fields) {
      if (f.doc != null) {
        o.doc(f.doc!, indent: 2);
      }
      o.line('  ${f.type}? get ${f.name} => _${f.name} as ${f.type}?;');
      if (f.doc != null) {
        o.blank();
      }
    }
    o.blank();
    o.doc('Interpolates two resolved styles field by field (design doc 9.2: an\n'
        'environment transition resolves both ends and lerps them). Colors,\n'
        'numbers, geometry, TextStyle, IconThemeData and BorderSide\n'
        'interpolate; other values switch at t = 0.5.', indent: 2);
    o.line('  static $style_? lerp($style_? a, $style_? b, double t) {');
    o.line('    if (identical(a, b)) {');
    o.line('      return a;');
    o.line('    }');
    o.line('    return $style_(');
    for (final FieldModel f in c.fields) {
      o.line('      ${f.name}: ${_lerpExpr(f.type, 'a?.${f.name}', 'b?.${f.name}')},');
    }
    o.line('    );');
    o.line('  }');
    o.blank();
    o.line('  static $style_ fromValues(Map<$field, Object> v) => $style_(');
    for (final FieldModel f in c.fields) {
      o.line('        ${f.name}: v[$field.${f.name}] as ${f.type}?,');
    }
    o.line('      );');
    o.line('}');
    o.blank();
  }

  /// `_a = null, _b = null, ...` for every rule field not in [except].
  List<String> _nulls(int slots, Set<String> set) => <String>[
        for (final String x in <String>[
          '_when',
          'whens',
          for (final _Dim d in allDims) '_${d.name}',
          'style',
          'label',
          '_field',
          '_regions',
          for (int i = 0; i < slots; i++) '_r$i',
        ])
          if (!set.contains(x)) x == 'style' ? 'style = const $spec()' : '$x = null',
      ];

  void _init(Out o, List<String> asserts, List<String> inits) {
    final List<String> all = <String>[...asserts, ...inits];
    for (int i = 0; i < all.length; i++) {
      o.line('${i == 0 ? '      : ' : '        '}${all[i]}${i == all.length - 1 ? ';' : ','}');
    }
  }

  void rule(Out o, Map<String, List<Region>> ctors, int slots) {
    o.section('Rule');
    final String regionList = ctors.isEmpty
        ? 'Fields whose default is the same in every state'
        : '(${<String>[for (final String f in ctors.keys) '[$rule_.$f]'].join(', ')}). Fields whose default is the same in every state';
    o.doc('A [$n] rule: condition + one payload, `style:` (a [$spec]\n'
        'or its all-values form [$style_]). Goes in StyleTheme / StyleScope\n'
        "rule lists (mixed with other components' rules) and in\n"
        "`$n(rules: ...)`. A typed list spread writes the component name once\n"
        'for a group of rules: `...<$rule_>[.when(...), .always(...)]`.\n'
        '\n'
        'Ways to write one:\n'
        '\n'
        "* With a condition: [$rule_.when] (the condition's dimensions are\n"
        '  named parameters), [$rule_.always] (no condition) or\n'
        '  [$rule_.whenAny] (one of several conditions). Any number of\n'
        '  fields. The full-name form `$rule_($when_(...), style: ...)` is the\n'
        '  same rule as `.when(...)` with the same dimensions (and `==` to it).\n'
        '* Per default region: one constructor per field whose library default\n'
        '  differs between states. Each named argument is one region of that\n'
        '  field, the states where one library default rule (or group of rules\n'
        '  with one label) sets it, so a value replaces exactly that default and\n'
        '  no other state. Values only; for a derive in one region, write the\n'
        "  region's condition with `.when` (listed in each constructor's doc).\n"
        '  ${wrapDoc(regionList, 70, '  ')} has no region\n'
        '  constructor: write `.always(style: ...)`.');
    o.line('final class $rule_ extends ComponentRule<$field> {');
    // Full-name form.
    o.doc('The full-name form of [$rule_.when]: the condition as a\n[$when_] object.', indent: 2);
    o.line('  const $rule_($when_ this._when, {required this.style, this.label})');
    _init(o, const <String>[], _nulls(slots, <String>{'_when', 'style', 'label'}));
    o.blank();
    // .when
    o.doc('[style] in the states that match every given dimension (null =\n'
        'unconstrained; bool dimensions are tri-state, enum dimensions take a\n'
        'set of allowed values).', indent: 2);
    o.line('  const $rule_.when({');
    for (final _Dim d in allDims) {
      o.line('    this._${d.name},');
    }
    o.line('    required this.style,');
    o.line('    this.label,');
    o.line('  })');
    _init(o, const <String>[], _nulls(slots, <String>{for (final _Dim d in allDims) '_${d.name}', 'style', 'label'}));
    o.blank();
    // .always
    o.doc('[style] in every state.', indent: 2);
    o.line('  const $rule_.always({required this.style, this.label})');
    _init(o, const <String>[], <String>['_when = const $when_()', ..._nulls(slots, <String>{'_when', 'style', 'label'})]);
    o.blank();
    // .whenAny
    o.doc('Cross-dimension "or": [style] in the states that match any of\n'
        '[whens] (one engine rule per condition, sharing one position).', indent: 2);
    o.line('  const $rule_.whenAny(List<$when_> this.whens, {required this.style, this.label})');
    _init(o, const <String>[], _nulls(slots, <String>{'whens', 'style', 'label'}));
    o.blank();
    // Region constructors.
    for (final MapEntry<String, List<Region>> e in ctors.entries) {
      final FieldModel f = c.field(e.key);
      final List<Region> rs = e.value;
      o.doc('`${f.name}` per default region. Each argument sets it in its\n'
          'region only; an unset argument leaves its region to the rules before.\n'
          "The regions don't overlap:\n"
          '\n'
          '${<String>[for (final Region r in rs) '* `${r.name}`: ${r.doc}'].join('\n')}\n'
          '\n'
          'Equivalent to one rule per argument that is set (copy one to\n'
          'write a region by hand, e.g. to add a condition or a derive):\n'
          '\n'
          '```dart\n'
          '${<String>[for (final Region r in rs) '$rule_.when(${<String>[...condArgs(cubeCond(r.cubes.single), typedSets: false), 'style: .values(${f.name}: ${r.name})'].join(', ')}),'].join('\n')}\n'
          '```', indent: 2);
      o.line('  const $rule_.${f.name}({');
      for (final Region r in rs) {
        o.line('    ${f.type}? ${r.name},');
      }
      o.line('    this.label,');
      o.line('  })');
      final List<String> asserts = <String>[
        "assert(${<String>[for (final Region r in rs) '${r.name} != null'].join(' || ')}, '$rule_.${f.name}: set at least one region')",
        if (_stateTypes[f.type] case final String st)
          for (final Region r in rs)
            "assert(${r.name} is! WidgetStateProperty<Object?>, '$rule_.${f.name}(${r.name}:): a rule holds data, not a $st')",
      ];
      _init(o, asserts, <String>[
        ..._nulls(slots, <String>{'label', '_field', '_regions', for (int i = 0; i < slots; i++) '_r$i'})
            .where((String x) => !x.startsWith('_r')),
        '_field = $field.${f.name}',
        '_regions = _$lc${upperFirst(f.name)}Regions',
        for (int i = 0; i < slots; i++) '_r$i = ${i < rs.length ? rs[i].name : 'null'}',
      ]);
      o.blank();
    }
    // Legacy.
    o.doc('A legacy `WidgetStateProperty` flat parameter (e.g. a `resolveWith`\n'
        'closure): one rule in every state whose value for [field] is\n'
        "[source]'s, falling through to the rules before it where [source]\n"
        'returns null. Built by [$n] only; not part of the rule API (a\n'
        'theme writes rules with conditions instead). The region slots are\n'
        'reused: [_field] is the field and [_r0] the source.', indent: 2);
    o.line('  const $rule_._legacy($field field, LegacySource source)');
    _init(o, const <String>[], <String>[
      '_when = const $when_()',
      ..._nulls(slots, <String>{'_when', '_field', '_r0'}),
      '_field = field',
      '_r0 = source',
    ]);
    o.blank();
    // when getter
    o.doc('The condition: the [$when_] of the full-name form, or the\n'
        'dimensions of [$rule_.when] as one; `$when_()` for\n'
        '[$rule_.always]. Null for [$rule_.whenAny] and region rules.', indent: 2);
    o.line('  $when_? get when => _regions != null || whens != null');
    o.line('      ? null');
    o.line('      : _when ??');
    o.line('          $when_(');
    for (final _Dim d in allDims) {
      o.line('            ${d.name}: _${d.name},');
    }
    o.line('          );');
    o.blank();
    o.line('  final $when_? _when;');
    o.blank();
    o.line('  // The dimensions of $rule_.when (a const constructor can\'t build the');
    o.line('  // $when_ itself).');
    for (final _Dim d in allDims) {
      o.line('  final ${d.whenType} _${d.name};');
    }
    o.blank();
    o.doc('The conditions of [$rule_.whenAny] (null otherwise).', indent: 2);
    o.line('  final List<$when_>? whens;');
    o.blank();
    o.doc('Empty for region rules: their values live in the region slots.', indent: 2);
    o.line('  final $spec style;');
    o.blank();
    o.doc('Region name of a default rule (`rest`, `disabled`, ...), or a user\n'
        'label for reports; null elsewhere.', indent: 2);
    o.line('  final String? label;');
    o.blank();
    o.line('  // Region rules: the field, its region table and one value slot per');
    o.line('  // region (as many slots as the field with the most regions has).');
    o.line('  final $field? _field;');
    o.line('  final List<(String, $when_)>? _regions;');
    for (int i = 0; i < slots; i++) {
      o.line('  final Object? _r$i;');
    }
    o.blank();
    o.line('  @override');
    o.line('  void addTo(RuleChannels channels) => channels.add<$rule_>(this);');
    o.blank();
    o.line("  static final Expando<RawRule<$field>> _raw = Expando<RawRule<$field>>('raw');");
    o.line("  static final Expando<List<RawRule<$field>>> _raws = Expando<List<RawRule<$field>>>('raws');");
    o.blank();
    o.doc('The engine rule of a rule written with a condition. A region rule\n'
        'expands into several: use [toRaws].', indent: 2);
    o.line('  RawRule<$field> toRaw() {');
    o.line('    if (_regions != null) {');
    o.line("      throw StateError('$rule_.\${_field!.name}(...) is a region rule and expands into one engine rule '");
    o.line("          'per region; use toRaws()');");
    o.line('    }');
    o.line('    if (_r0 case final LegacySource source) {');
    o.line('      return _raw[this] ??= RawRule<$field>(Condition.all,');
    o.line('          derive: Derive<$field>(<$field, DeriveSource>{_field!: source}));');
    o.line('    }');
    o.line('    if (_raw[this] case final RawRule<$field> r) {');
    o.line('      return r;');
    o.line('    }');
    o.line('    final (Style<$field> st, Derive<$field> d, SubMap<$field> sub) = style.toEngine();');
    o.line('    return _raw[this] = whens == null');
    o.line('        ? RawRule<$field>(when!.toCondition(), style: st, derive: d, sub: sub, label: label)');
    o.line('        : RawRule<$field>.any(<Condition>[for (final $when_ w in whens!) w.toCondition()],');
    o.line('            style: st, derive: d, sub: sub, label: label);');
    o.line('  }');
    o.blank();
    o.line('  @override');
    o.line('  List<RawRule<$field>> toRaws() => _raws[this] ??= switch (_regions) {');
    o.line('        null => <RawRule<$field>>[toRaw()],');
    o.line('        final List<(String, $when_)> regions => regionRawRules<$field>(');
    o.line('            _field!,');
    o.line('            <(String, Condition)>[for (final (String n, $when_ w) in regions) (n, w.toCondition())],');
    o.line('            <Object?>[${<String>[for (int i = 0; i < slots; i++) '_r$i'].join(', ')}],');
    o.line('            label: label),');
    o.line('      };');
    o.blank();
    o.line('  @override');
    o.line('  bool operator ==(Object other) =>');
    o.line('      other is $rule_ &&');
    o.line('      other.when == when &&');
    o.line('      listEquals(other.whens, whens) &&');
    o.line('      other.style == style &&');
    o.line('      other.label == label &&');
    o.line('      other._field == _field &&');
    o.line('      identical(other._regions, _regions) &&');
    for (int i = 0; i < slots; i++) {
      o.line('      other._r$i == _r$i${i == slots - 1 ? ';' : ' &&'}');
    }
    o.blank();
    o.line('  @override');
    o.line('  int get hashCode => Object.hash(when, whens == null ? null : Object.hashAll(whens!), style, label, _field,');
    o.line('      ${<String>[for (int i = 0; i < slots; i++) '_r$i'].join(', ')});');
    o.line('}');
    o.blank();
  }

  /// The arguments of a condition on the component's own dimensions, in
  /// spec order: bools as literals, a scalar (two-valued) enum as one value
  /// (omitted when both are allowed), a set as `<T>{T.a, ...}` (or `{T.a}`
  /// with [typedSets] false) in domain order.
  List<String> condArgs(Map<String, Object> cond, {bool typedSets = true}) => <String>[
        for (final DimModel d in c.dims)
          if (cond[d.name] case final Object v)
            if (v is bool)
              '${d.name}: $v'
            else if (d.isScalar)
              if ((v as Set<Object>).length == 1) '${d.name}: ${d.type}.${v.single}' else ...<String>[]
            else
              '${d.name}: ${typedSets ? '<${d.type}>' : ''}{${<String>[for (final Object x in d.domain) if ((v as Set<Object>).contains(x)) '${d.type}.$x'].join(', ')}}',
      ];

  /// A cube as a plain condition map (bools unwrapped).
  Map<String, Object> cubeCond(Map<String, Set<Object>> cube) => <String, Object>{
        for (final MapEntry<String, Set<Object>> e in cube.entries) e.key: c.dim(e.key).isBool ? e.value.single : e.value,
      };

  /// The const `XWhen(...)` of a cube for a region table.
  String whenConst(Map<String, Set<Object>> cube) => '$when_(${condArgs(cubeCond(cube)).join(', ')})';

  void regionTables(Out o, Map<String, List<Region>> ctors) {
    o.section('Rule regions');
    o.comment('The region tables behind the region constructors, computed by the\n'
        'generator from the library defaults (design doc 6.1). A region of a\n'
        'field is the set of states where one library default rule (or group\n'
        'of rules with one label) sets it. Only fields with more than one\n'
        'region get a table and a constructor. Environment dimensions are never\n'
        'constrained.');
    o.blank();
    for (final MapEntry<String, List<Region>> e in ctors.entries) {
      o.line('const List<(String, $when_)> _$lc${upperFirst(e.key)}Regions = <(String, $when_)>[');
      for (final Region r in e.value) {
        o.line("  ('${r.name}', ${whenConst(r.cubes.single)}),");
      }
      o.line('];');
      o.blank();
    }
    o.doc('The region table of every field that has a region constructor, in\n'
        'constructor argument order. For tools and tests; not exported by the\n'
        'package library.');
    o.line('const Map<$field, List<(String, $when_)>> ${lc}RegionTable = <$field, List<(String, $when_)>>{');
    for (final String f in ctors.keys) {
      o.line('  $field.$f: _$lc${upperFirst(f)}Regions,');
    }
    o.line('};');
    o.blank();
  }

  String sourceExpr(SourceModel s) => switch (s.kind) {
        SourceKind.value => '.value(${s.text})',
        SourceKind.field => '.fromField(.${s.text})',
        SourceKind.token => '.fromToken(.${s.text})',
        SourceKind.computed => '.computed(${s.text})',
        SourceKind.opacity => '.opacity(${sourceExpr(s.inner!)}, ${s.text})',
        SourceKind.opaque => '.opaque(${sourceExpr(s.inner!)})',
      };

  String entryExpr(EntryModel e, {required bool values}) {
    if (values) {
      return '${e.field}: ${e.expression}';
    }
    if (e.expression != null) {
      return '${e.field}: .value(${e.expression})';
    }
    if (e.source != null) {
      return '${e.field}: ${sourceExpr(e.source!)}';
    }
    return '${e.field}: .parts(${<String>[for (final MapEntry<String, SourceModel> p in e.parts!.entries) '${p.key}: ${sourceExpr(p.value)}'].join(', ')})';
  }

  void defaults(Out o) {
    o.section('Library defaults');
    o.doc('The library defaults of [$n] (from the spec), as one const rule\n'
        'list. Labels name regions (rules with one label form one region of a\n'
        'field) and show up in provenance (debugSources).');
    o.line('const List<$rule_> ${lc}Defaults = <$rule_>[');
    for (final RuleModel r in c.defaults) {
      final bool values = r.entries.every((EntryModel e) => e.isValue);
      final List<String> head = <String>[
        ...condArgs(<String, Object>{
          for (final MapEntry<String, Object> e in r.when.entries) e.key: e.value is bool ? e.value : <Object>{...(e.value as Set<String>)},
        }),
        if (r.label != null) "label: '${r.label}'",
      ];
      final String style = '${values ? '.values' : '.derive'}(${<String>[for (final EntryModel e in r.entries) entryExpr(e, values: values)].join(', ')})';
      o.line('  .${r.when.isEmpty ? 'always' : 'when'}(${<String>[...head, 'style: $style'].join(', ')}),');
    }
    o.line('];');
    o.blank();
  }

  void componentStyle(Out o) {
    o.section('Component');
    final List<FieldModel> colors = <FieldModel>[for (final FieldModel f in c.fields) if (f.kind == FieldKind.color) f];
    o.doc('Static description of [$n] (spec + defaults).');
    o.line('final ComponentStyle<$field> ${lc}Style = ComponentStyle<$field>(');
    o.line('  channel: $rule_,');
    o.line('  spec: ComponentSpec<$field>(');
    o.line("    name: '$n',");
    o.line('    fields: $field.values,');
    o.line('    dimensions: $dimsClass.all,');
    o.line('    fieldTypes: const <$field, Type>{');
    for (final FieldModel f in colors) {
      o.line('      $field.${f.name}: Color,');
    }
    o.line('    },');
    if (composites.isNotEmpty) {
      o.line('    composites: const <$field, Composite>{');
      for (final FieldModel f in composites) {
        o.line('      $field.${f.name}: ${_composites[f.kind]!.engine},');
      }
      o.line('    },');
    }
    o.line('    impossible: <Condition>[');
    for (final Map<String, Object> w in c.impossible) {
      o.line('      Condition(<Dimension<Object>, Object>{${<String>[
        for (final MapEntry<String, Object> e in w.entries) '$dimsClass.${e.key}: ${e.value is bool ? e.value : '<Object>{${(e.value as Set<String>).map((String x) => '${c.dim(e.key).type}.$x').join(', ')}}'}',
      ].join(', ')}}),');
    }
    o.line('    ],');
    o.line('  ),');
    o.line('  defaults: <RawRule<$field>>[for (final $rule_ r in ${lc}Defaults) r.toRaw()],');
    o.line(');');
    o.blank();
  }

  String _lerpExpr(String type, String a, String b) => switch (type) {
        'Color' => 'Color.lerp($a, $b, t)',
        'double' => '_lerpDouble($a, $b, t)',
        'EdgeInsetsGeometry' => 'EdgeInsetsGeometry.lerp($a, $b, t)',
        'EdgeInsets' => 'EdgeInsets.lerp($a, $b, t)',
        'BorderRadius' => 'BorderRadius.lerp($a, $b, t)',
        'BorderRadiusGeometry' => 'BorderRadiusGeometry.lerp($a, $b, t)',
        'Size' => 'Size.lerp($a, $b, t)',
        'Offset' => 'Offset.lerp($a, $b, t)',
        'AlignmentGeometry' => 'AlignmentGeometry.lerp($a, $b, t)',
        'TextStyle' => 'TextStyle.lerp($a, $b, t)',
        'IconThemeData' => 'IconThemeData.lerp($a, $b, t)',
        'BorderSide' => '_lerpBorderSide($a, $b, t)',
        _ => 't < 0.5 ? $a : $b',
      };

  void resolveHelpers(Out o) {
    o.section('Reading resolved styles');
    final List<String> stateParams = <String>[
      for (final DimModel d in c.dims) d.isBool ? 'bool ${d.name} = false' : 'required ${d.type} ${d.name}',
    ];
    final String stateArgs = <String>[for (final DimModel d in c.dims) '${d.name}: ${d.name}'].join(', ');
    o.doc('The resolved [$style_] at any state (design doc 7.6), without pumping\n'
        'gestures: the library defaults, the StyleTheme and StyleScopes visible\n'
        'at [context], then [rules] (call-site rules, e.g. a widget\'s own).\n'
        'Environment dimensions not given come from the StyleTheme / StyleScope\n'
        'environment, then from [context]. Backs `$n.resolveStyle`.');
    o.line('$style_ resolve${n}Style(');
    o.line('  BuildContext context, {');
    for (final String p in stateParams) {
      o.line('  $p,');
    }
    for (final EnvDimModel d in lib.env) {
      o.line('  ${d.isBool ? 'bool' : d.type}? ${d.name},');
    }
    o.line('  List<$rule_> rules = const <$rule_>[],');
    o.line('}) {');
    o.line('  final StyleNode node = StyleTheme.peekNode(context);');
    o.line('  final ResolvedEnvironment env = node.effectiveEnvironment');
    o.line('      .merge(StyleEnvironment(${<String>[for (final EnvDimModel d in lib.env) '${d.name}: ${d.name}'].join(', ')}))');
    o.line('      .resolve(context);');
    o.line('  return $style_.fromValues(StyleResolver<$field>(${lc}Style).resolve(node, rules, ${lc}Minterm($stateArgs, env: env)));');
    o.line('}');
    o.blank();
    o.doc('[resolve${n}Style] without a widget tree (design doc 7.6): [theme] is\n'
        'a StyleTheme rule list, [rules] the call-site rules, and the\n'
        'environment is given (every environment dimension).');
    o.line('$style_ resolve${n}StyleFromRules({');
    o.line('  List<Rule> theme = const <Rule>[],');
    o.line('  List<$rule_> rules = const <$rule_>[],');
    for (final String p in stateParams) {
      o.line('  $p,');
    }
    for (final EnvDimModel d in lib.env) {
      o.line('  required ${d.isBool ? 'bool' : d.type} ${d.name},');
    }
    o.line('}) {');
    o.line('  final StyleNode node = StyleNode.root(rules: theme);');
    o.line('  final ResolvedEnvironment env = ResolvedEnvironment(${<String>[for (final EnvDimModel d in lib.env) '${d.name}: ${d.name}'].join(', ')});');
    o.line('  return $style_.fromValues(StyleResolver<$field>(${lc}Style).resolve(node, rules, ${lc}Minterm($stateArgs, env: env)));');
    o.line('}');
    o.blank();
  }

  void minterm(Out o) {
    o.doc('The minterm of a [$n] state.');
    o.line('Minterm ${lc}Minterm({');
    for (final DimModel d in c.dims) {
      o.line('  required ${d.isBool ? 'bool' : d.type} ${d.name},');
    }
    o.line('  required ResolvedEnvironment env,');
    o.line('}) =>');
    o.line('    Minterm($dimsClass.all, <Object>[${<String>[for (final DimModel d in c.dims) d.name].join(', ')}, ...env.values]);');
  }
}

/// A dimension as the generated condition classes see it.
final class _Dim {
  _Dim(this.name, this.type, this.kind, this.ref);

  final String name;

  /// The value type (`bool` for a bool dimension).
  final String type;

  /// `bool`, `scalar` or `set`.
  final String kind;

  /// The engine dimension constant (`ButtonDims.disabled`).
  final String ref;

  String get whenType => switch (kind) {
        'set' => 'Set<$type>?',
        _ => '$type?',
      };

  String get viewType => type;

  /// The map entry of `toCondition()` for the field [field].
  String conditionEntry(String field) => kind == 'scalar'
      ? '        if ($field case final $type v) $ref: <Object>{v},'
      : '        $ref: ?$field,';
}
