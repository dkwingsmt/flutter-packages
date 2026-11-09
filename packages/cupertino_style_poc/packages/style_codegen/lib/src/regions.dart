// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Rule regions from the library defaults (design doc 6.1), computed from
/// the structure of the default rules only (conditions, which fields each
/// rule sets, labels, impossible combinations), never from values.
///
/// * A region of a field is the set of reachable states where one default
///   rule, or a group of default rules with the same label, wins the field
///   (`unset` where none does).
/// * A variant dimension (appearance, ...) splits the regions only when the
///   field's partition differs between its values; a region never spans
///   several values of a dimension it was split on.
/// * Impossible combinations are don't-cares when the region's condition
///   is simplified to cubes.
/// * Names: [regionName] (the naming rules of 6.1, as the prototype's
///   `test/support/region_names.dart` implemented them).
/// * Environment dimensions are not part of components' state space here:
///   regions never constrain them.
library;

import 'model.dart';

/// One region: its name, its condition (cubes, OR-ed; a cube maps a
/// dimension to its allowed values, absent = any) and its doc words.
final class Region {
  Region(this.name, this.cubes, this.doc);

  final String name;
  final List<Map<String, Set<Object>>> cubes;
  final String doc;

  @override
  String toString() => '$name $cubes';
}

/// Regions per non-composite field, in field order. A field with one
/// region (every state) maps to a single `anyState` region.
Map<String, List<Region>> computeRegions(ComponentModel c) {
  final _Space space = _Space(c);
  return <String, List<Region>>{
    for (final FieldModel f in c.fields)
      if (!f.isComposite) f.name: _regionsOf(c, space, f.name),
  };
}

typedef _Minterm = List<Object>;

final class _Space {
  _Space(this.c) {
    void build(int i, List<Object> prefix) {
      if (i == c.dims.length) {
        final _Minterm m = List<Object>.unmodifiable(prefix);
        (isImpossible(m) ? impossible : possible).add(m);
        return;
      }
      for (final Object v in c.dims[i].domain) {
        build(i + 1, <Object>[...prefix, v]);
      }
    }

    build(0, <Object>[]);
  }

  final ComponentModel c;
  final List<_Minterm> possible = <_Minterm>[];
  final List<_Minterm> impossible = <_Minterm>[];

  int index(String dim) => c.dims.indexWhere((DimModel d) => d.name == dim);

  bool condMatches(Map<String, Object> when, _Minterm m) {
    for (final MapEntry<String, Object> e in when.entries) {
      final Object v = m[index(e.key)];
      final Object want = e.value;
      if (want is bool ? v != want : !(want as Set<String>).contains(v)) {
        return false;
      }
    }
    return true;
  }

  bool isImpossible(_Minterm m) => c.impossible.any((Map<String, Object> w) => condMatches(w, m));

  bool cubeContains(Map<String, Set<Object>> cube, _Minterm m) {
    for (final MapEntry<String, Set<Object>> e in cube.entries) {
      if (!e.value.contains(m[index(e.key)])) {
        return false;
      }
    }
    return true;
  }
}

/// The winning key of [field] at [m]: the label of the last default rule
/// that sets it and matches (`rule #i` for an unlabeled rule), or null.
(String?, int) _winner(ComponentModel c, _Space s, String field, _Minterm m) {
  for (int i = c.defaults.length - 1; i >= 0; i--) {
    final RuleModel r = c.defaults[i];
    if (r.entries.any((EntryModel e) => e.field == field && e.parts == null) && s.condMatches(r.when, m)) {
      return (r.label ?? 'rule #$i', i);
    }
  }
  return (null, -1);
}

List<Region> _regionsOf(ComponentModel c, _Space s, String field) {
  final Map<_Minterm, (String?, int)> win = <_Minterm, (String?, int)>{
    for (final _Minterm m in s.possible) m: _winner(c, s, field, m),
  };
  String key(_Minterm m) => win[m]!.$1 ?? '\u0000unset';

  // Split on variant dimensions whose values partition the field
  // differently.
  List<List<_Minterm>> groups = <List<_Minterm>>[s.possible];
  final List<String> splitOn = <String>[];
  for (final DimModel d in c.dims) {
    if (d.role != DimRole.variant) {
      continue;
    }
    final int di = s.index(d.name);
    final Map<Object, Map<String, String>> perValue = <Object, Map<String, String>>{};
    for (final _Minterm m in s.possible) {
      final String rest = <Object>[for (int i = 0; i < m.length; i++) if (i != di) m[i]].join(',');
      (perValue[m[di]] ??= <String, String>{})[rest] = key(m);
    }
    final List<Map<String, String>> maps = perValue.values.toList();
    final bool differ = maps.any((Map<String, String> x) => !_sameMap(x, maps.first));
    if (differ) {
      splitOn.add(d.name);
      groups = <List<_Minterm>>[
        for (final List<_Minterm> g in groups)
          for (final Object v in d.domain) <_Minterm>[for (final _Minterm m in g) if (m[di] == v) m],
      ].where((List<_Minterm> g) => g.isNotEmpty).toList();
    }
  }

  // Regions: per group, per key; ordered by group, then by the first rule
  // of the key (unset first).
  final List<(List<_Minterm>, int)> regionSets = <(List<_Minterm>, int)>[];
  for (final List<_Minterm> g in groups) {
    final Map<String, List<_Minterm>> byKey = <String, List<_Minterm>>{};
    final Map<String, int> first = <String, int>{};
    for (final _Minterm m in g) {
      (byKey[key(m)] ??= <_Minterm>[]).add(m);
      final int i = win[m]!.$2;
      first[key(m)] = first[key(m)] == null || i < first[key(m)]! ? i : first[key(m)]!;
    }
    final List<String> keys = byKey.keys.toList()..sort((String a, String b) => first[a]!.compareTo(first[b]!));
    for (final String k in keys) {
      regionSets.add((byKey[k]!, first[k]!));
    }
  }
  final List<List<Map<String, Set<Object>>>> covers = <List<Map<String, Set<Object>>>>[
    for (final (List<_Minterm> on, int _) in regionSets) _cover(c, s, on.toSet(), splitOn),
  ];
  // Semantic bool dims some region of this field constrains to true: only
  // those get a false suffix (`Unselected`) elsewhere (6.1 rule 4).
  final Set<String> trueSemantic = <String>{
    for (final List<Map<String, Set<Object>>> cubes in covers)
      for (final Map<String, Set<Object>> cube in cubes)
        for (final DimModel d in c.dims)
          if (d.role == DimRole.semantic && d.isBool && cube[d.name]?.length == 1 && cube[d.name]!.single == true) d.name,
  };
  final _Naming naming = _Naming(c, trueSemantic);
  return <Region>[
    for (final List<Map<String, Set<Object>>> cubes in covers) Region(naming.regionName(cubes), cubes, naming.regionDoc(cubes)),
  ];
}

bool _sameMap(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length && a.entries.every((MapEntry<String, String> e) => b[e.key] == e.value);

/// Cubes (prime implicants) covering [on] without touching any other
/// possible minterm; impossible minterms are don't-cares. One cube when
/// one covers the whole region; else a greedy cover.
List<Map<String, Set<Object>>> _cover(ComponentModel c, _Space s, Set<_Minterm> on, List<String> splitOn) {
  final List<_Minterm> off = <_Minterm>[for (final _Minterm m in s.possible) if (!on.contains(m)) m];
  final List<Map<String, Set<Object>>> candidates = <Map<String, Set<Object>>>[];
  void build(int i, Map<String, Set<Object>> cube) {
    if (i == c.dims.length) {
      if (!off.any((_Minterm m) => s.cubeContains(cube, m)) && on.any((_Minterm m) => s.cubeContains(cube, m))) {
        candidates.add(Map<String, Set<Object>>.of(cube));
      }
      return;
    }
    final DimModel d = c.dims[i];
    for (final Set<Object>? option in _options(d)) {
      if (option == null) {
        build(i + 1, cube);
      } else {
        build(i + 1, <String, Set<Object>>{...cube, d.name: option});
      }
    }
  }

  build(0, <String, Set<Object>>{});
  int covered(Map<String, Set<Object>> cube, Set<_Minterm> left) =>
      left.where((_Minterm m) => s.cubeContains(cube, m)).length;
  // Fewer constrained dimensions first, then smaller value sets, then
  // spec order (stable).
  int weight(Map<String, Set<Object>> cube) => cube.length * 1000 + cube.values.fold(0, (int a, Set<Object> v) => a + v.length);
  candidates.sort((Map<String, Set<Object>> a, Map<String, Set<Object>> b) => weight(a).compareTo(weight(b)));
  final List<Map<String, Set<Object>>> whole = <Map<String, Set<Object>>>[
    for (final Map<String, Set<Object>> x in candidates)
      if (covered(x, on) == on.length) x,
  ];
  if (whole.isNotEmpty) {
    return <Map<String, Set<Object>>>[_ordered(c, whole.first)];
  }
  final Set<_Minterm> left = Set<_Minterm>.of(on);
  final List<Map<String, Set<Object>>> out = <Map<String, Set<Object>>>[];
  while (left.isNotEmpty) {
    Map<String, Set<Object>>? best;
    int bestN = 0;
    for (final Map<String, Set<Object>> x in candidates) {
      final int n = covered(x, left);
      if (n > bestN) {
        best = x;
        bestN = n;
      }
    }
    out.add(_ordered(c, best!));
    left.removeWhere((_Minterm m) => s.cubeContains(best!, m));
  }
  return out;
}

/// [cube] with its keys in spec order and enum values in domain order.
Map<String, Set<Object>> _ordered(ComponentModel c, Map<String, Set<Object>> cube) => <String, Set<Object>>{
      for (final DimModel d in c.dims)
        if (cube[d.name] case final Set<Object> v) d.name: <Object>{for (final Object x in d.domain) if (v.contains(x)) x},
    };

/// Constraint options of one dimension: null (any), then each proper
/// non-empty subset of its domain.
Iterable<Set<Object>?> _options(DimModel d) sync* {
  yield null;
  final List<Object> dom = d.domain;
  for (int bits = 1; bits < (1 << dom.length) - 1; bits++) {
    yield <Object>{for (int i = 0; i < dom.length; i++) if (bits & (1 << i) != 0) dom[i]};
  }
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _camel(List<String> words) => words.isEmpty ? '' : words.first + words.skip(1).map(_cap).join();

/// Negative form of a semantic bool dim.
String negativeName(String dim) => switch (dim) {
      'selected' => 'unselected',
      'checked' => 'unchecked',
      'error' => 'noError',
      _ => 'not${_cap(dim)}',
    };

final class _Naming {
  _Naming(this.c, this.trueSemantic);

  final ComponentModel c;

  /// Semantic bool dims with a true-valued region in the same field.
  final Set<String> trueSemantic;

  DimModel? get disabled => c.dims.where((DimModel d) => d.role == DimRole.disabled).firstOrNull;
  List<DimModel> get interaction => <DimModel>[for (final DimModel d in c.dims) if (d.role == DimRole.interaction) d];
  List<DimModel> get semantic => <DimModel>[for (final DimModel d in c.dims) if (d.role == DimRole.semantic) d];

  bool isState(DimModel d) => d.role != DimRole.variant;

  Set<Object>? constraint(Map<String, Set<Object>> cube, DimModel d) {
    final Set<Object>? s = cube[d.name];
    return s == null || s.length == d.domain.length ? null : s;
  }

  String camelOr(DimModel d, Set<Object> s) {
    final List<String> vs = <String>[for (final Object v in d.domain) if (s.contains(v)) '$v'];
    return vs.first + vs.skip(1).map((String x) => 'Or${_cap(x)}').join();
  }

  int baseRule(Map<String, Set<Object>> c) {
    bool isTrue(DimModel d) => constraint(c, d)?.single == true;
    bool isFalse(DimModel d) => constraint(c, d)?.single == false;
    if ((disabled != null && isTrue(disabled!)) || interaction.any(isTrue)) {
      return 1;
    }
    if (interaction.isNotEmpty && interaction.every(isFalse)) {
      return 2;
    }
    if (disabled != null && isFalse(disabled!)) {
      return 3;
    }
    return 4;
  }

  String cubeName(Map<String, Set<Object>> cube) {
    final List<String> prefix = <String>[];
    for (final DimModel d in c.dims) {
      if (isState(d)) {
        continue;
      }
      final Set<Object>? s = constraint(cube, d);
      if (s == null) {
        continue;
      }
      prefix.add(d.isBool ? (s.single == true ? d.name : 'not${_cap(d.name)}') : camelOr(d, s));
    }
    final int rule = baseRule(cube);
    final List<String> base = switch (rule) {
      1 => <String>[
          for (final DimModel d in <DimModel>[?disabled, ...interaction])
            if (constraint(cube, d)?.single == true) d.name,
        ],
      2 => <String>['idle'],
      3 => <String>['enabled'],
      _ => <String>['anyState'],
    };
    final List<String> suffix = <String>[];
    for (final DimModel d in semantic) {
      final Set<Object>? s = constraint(cube, d);
      if (s == null) {
        continue;
      }
      if (d.isBool && s.single == false) {
        // Design doc 6.1 rule 4: the false suffix is written only when the
        // field also has a region with the true value.
        if (rule != 4 && trueSemantic.contains(d.name)) {
          suffix.add(negativeName(d.name));
        }
        continue;
      }
      suffix.add(d.isBool ? d.name : camelOr(d, s));
    }
    if (rule == 4) {
      base.clear();
      if (suffix.isEmpty) {
        for (final DimModel d in <DimModel>[...interaction, ...semantic]) {
          if (constraint(cube, d)?.single == false) {
            suffix.add(interaction.contains(d) ? 'not${_cap(d.name)}' : negativeName(d.name));
          }
        }
      }
      if (suffix.isEmpty) {
        base.add('anyState');
      }
    }
    return _camel(<String>[...prefix, ...base, ...suffix]);
  }

  String regionName(List<Map<String, Set<Object>>> cubes) {
    final List<String> names = <String>[for (final Map<String, Set<Object>> x in cubes) cubeName(x)];
    return names.first + names.skip(1).map(_cap).map((String x) => 'Or$x').join();
  }

  String cubeWords(Map<String, Set<Object>> cube) {
    final List<String> parts = <String>[];
    final List<String> free = <String>[];
    for (final DimModel d in c.dims) {
      final Set<Object>? s = constraint(cube, d);
      if (s == null) {
        if (isState(d)) {
          free.add(d.name);
        }
        continue;
      }
      if (d.isBool) {
        parts.add(s.single == true ? d.name : 'not ${d.name}');
      } else {
        parts.add('${d.name} ${<String>[for (final Object v in d.domain) if (s.contains(v)) '$v'].join(' or ')}');
      }
    }
    if (parts.isEmpty) {
      return 'every state';
    }
    return free.isEmpty ? parts.join(', ') : '${parts.join(', ')}; any ${free.join(' / ')}';
  }

  String regionDoc(List<Map<String, Set<Object>>> cubes) {
    final String words = cubes.map(cubeWords).join('; or ');
    return '${words[0].toUpperCase()}${words.substring(1)}.';
  }
}

/// The full-coverage check of design doc 4 (step 1) and 7.5: every field
/// has a value in every reachable state of the library defaults. For a
/// composite field a whole value is required (`.parts` alone patches
/// nothing). Returns one line per uncovered field: how many reachable
/// states lack a value, and one of them.
List<String> coverageGaps(ComponentModel c) {
  final _Space s = _Space(c);
  final List<String> out = <String>[];
  for (final FieldModel f in c.fields) {
    final List<_Minterm> missing = <_Minterm>[
      for (final _Minterm m in s.possible)
        if (!c.defaults.any((RuleModel r) =>
            r.entries.any((EntryModel e) => e.field == f.name && e.parts == null) && s.condMatches(r.when, m)))
          m,
    ];
    if (missing.isNotEmpty) {
      final String example = <String>[
        for (int i = 0; i < c.dims.length; i++) '${c.dims[i].name}=${missing.first[i]}',
      ].join(', ');
      out.add('${c.name}.${f.name}: unset in ${missing.length} of ${s.possible.length} reachable states (e.g. $example)');
    }
  }
  return out;
}
