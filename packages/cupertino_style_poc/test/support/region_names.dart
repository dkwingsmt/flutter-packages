// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The region naming rules as the function a generator would apply to a
// region's condition. The region constants in button.g.dart / switch.g.dart
// are hand-written; test/regions_test.dart checks that every constant's name
// is `regionName(...)` of its condition and its doc comment is
// `regionDoc(...)`, so names and docs cannot drift from the conditions.
//
// Per cube (one When):
// * prefix: the non-state dims (appearance, size), in spec order: the enum
//   value names (a set joined with `Or`), a bool dim as `<dim>` / `not<Dim>`;
// * base word from disabled + interaction dims:
//   1. positive literals (`disabled`, `pressed`, `focusedHovered`, ...);
//   2. else every interaction dim false: `idle`;
//   3. else disabled false: `enabled` (a partial interaction exclusion is
//      treated as order-implied and dropped);
//   4. else `anyState`;
// * suffix: semantic state dims (Switch `selected`): an enum set gives its
//   values joined with `Or`; a bool dim true gives its name; a bool dim false
//   is dropped (an order-implied negation);
// * `anyState` is dropped when a suffix is present (`selected`, not
//   `anyStateSelected`), and is used only for a cube with no state
//   constraint at all: a base-4 cube with nothing else to name is named by
//   its false literals (`notPressed`; `unselected`, `noError`, `not<Dim>`
//   for semantic dims). This gives the Switch's `unselected`.
// Several cubes are joined with `Or`.
import 'package:cupertino_style_poc/src/engine/engine.dart';

/// How a component's dimensions take part in names.
class RegionNaming {
  const RegionNaming({
    required this.dimensions,
    required this.disabled,
    required this.interaction,
    required this.semantic,
  });

  /// Spec order.
  final List<Dimension<Object>> dimensions;
  final Dimension<Object>? disabled;
  final List<Dimension<Object>> interaction;
  final List<Dimension<Object>> semantic;

  bool isState(Dimension<Object> d) => d == disabled || interaction.contains(d) || semantic.contains(d);

  /// Non-state, non-environment dims: name prefix.
  bool isPrefix(Dimension<Object> d) => !d.environment && !isState(d);
}

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String _camel(List<String> words) => words.isEmpty ? '' : words.first + words.skip(1).map(_cap).join();

String _valueName(Object v) => v is Enum ? v.name : '$v';

/// Negative form of a semantic bool dim.
String negativeName(String dim) => switch (dim) {
      'selected' => 'unselected',
      'checked' => 'unchecked',
      'error' => 'noError',
      _ => 'not${_cap(dim)}',
    };

Set<Object>? _constraint(Condition c, Dimension<Object> d) {
  final Set<Object>? s = c.constraints[d];
  return s == null || s.length == d.domain.length ? null : s;
}

/// Which naming rule (1-4) the base word of [c] comes from.
int baseRule(RegionNaming n, Condition c) {
  bool isTrue(Dimension<Object> d) => _constraint(c, d)?.single == true;
  bool isFalse(Dimension<Object> d) => _constraint(c, d)?.single == false;
  if ((n.disabled != null && isTrue(n.disabled!)) || n.interaction.any(isTrue)) {
    return 1;
  }
  if (n.interaction.isNotEmpty && n.interaction.every(isFalse)) {
    return 2;
  }
  if (n.disabled != null && isFalse(n.disabled!)) {
    return 3;
  }
  return 4;
}

/// The name of one cube.
String cubeName(RegionNaming n, Condition c) {
  final List<String> prefix = <String>[];
  for (final Dimension<Object> d in n.dimensions) {
    if (!n.isPrefix(d)) {
      continue;
    }
    final Set<Object>? s = _constraint(c, d);
    if (s == null) {
      continue;
    }
    if (d.isBool) {
      prefix.add(s.single == true ? d.name : 'not${_cap(d.name)}');
    } else {
      prefix.add(_camelOr(d, s));
    }
  }
  final int rule = baseRule(n, c);
  final List<String> base = switch (rule) {
    1 => <String>[
        for (final Dimension<Object> d in <Dimension<Object>>[?n.disabled, ...n.interaction])
          if (_constraint(c, d)?.single == true) d.name,
      ],
    2 => <String>['idle'],
    3 => <String>['enabled'],
    _ => <String>['anyState'],
  };
  final List<String> suffix = <String>[];
  for (final Dimension<Object> d in n.semantic) {
    final Set<Object>? s = _constraint(c, d);
    if (s == null || (d.isBool && s.single == false)) {
      continue;
    }
    suffix.add(d.isBool ? d.name : _camelOr(d, s));
  }
  if (rule == 4) {
    base.clear();
    if (suffix.isEmpty) {
      // `anyState` only for a cube without any state constraint; otherwise
      // name its false literals: `notPressed`, `unselected`.
      for (final Dimension<Object> d in <Dimension<Object>>[...n.interaction, ...n.semantic]) {
        if (_constraint(c, d)?.single == false) {
          suffix.add(n.interaction.contains(d) ? 'not${_cap(d.name)}' : negativeName(d.name));
        }
      }
    }
    if (suffix.isEmpty) {
      base.add('anyState');
    }
  }
  return _camel(<String>[...prefix, ...base, ...suffix]);
}

String _camelOr(Dimension<Object> d, Set<Object> s) {
  final List<String> vs = <String>[for (final Object v in d.domain) if (s.contains(v)) _valueName(v)];
  return vs.first + vs.skip(1).map((String x) => 'Or${_cap(x)}').join();
}

/// The constant name of a region given by its cubes.
String regionName(RegionNaming n, List<Condition> cubes) {
  final List<String> names = <String>[for (final Condition c in cubes) cubeName(n, c)];
  return names.first + names.skip(1).map(_cap).map((String x) => 'Or$x').join();
}

/// The condition of one cube in words: every constrained dim (spec order),
/// then the unconstrained state dims. Environment dims are never
/// constrained by a region and not mentioned.
String cubeWords(RegionNaming n, Condition c) {
  final List<String> parts = <String>[];
  final List<String> free = <String>[];
  for (final Dimension<Object> d in n.dimensions) {
    if (d.environment) {
      continue;
    }
    final Set<Object>? s = _constraint(c, d);
    if (s == null) {
      if (n.isState(d)) {
        free.add(d.name);
      }
      continue;
    }
    if (d.isBool) {
      parts.add(s.single == true ? d.name : 'not ${d.name}');
    } else {
      parts.add('${d.name} ${<String>[for (final Object v in d.domain) if (s.contains(v)) _valueName(v)].join(' or ')}');
    }
  }
  if (parts.isEmpty) {
    return 'every state';
  }
  return free.isEmpty ? parts.join(', ') : '${parts.join(', ')}; any ${free.join(' / ')}';
}

/// The doc comment text (without `/// `) of a region constant.
String regionDoc(RegionNaming n, List<Condition> cubes) {
  final String words = cubes.map((Condition c) => cubeWords(n, c)).join('; or ');
  return '${words[0].toUpperCase()}${words.substring(1)}.';
}
