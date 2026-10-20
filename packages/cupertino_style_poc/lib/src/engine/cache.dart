// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Resolution caches for const rule chains whose token references
/// stay symbolic.
///
/// Winner selection ([resolveSymbolic]) depends only on the chain and the
/// minterm, never on token values. So for a fixed chain the result per
/// minterm is computed once as a [SymbolicStyle] and binding it to a
/// [Tokens] instance is a handful of global-channel reads.
///
/// Invalidation model:
/// * Any change of the global channel invalidates every style channel: no
///   dependency tracking ([ScopeNode.affectedBy] reports
///   [AffectedChannels.all], i.e. `updateShouldNotifyDependent` returns
///   true for every aspect).
/// * Only bound (token-substituted) values are dropped. The symbolic
///   per-minterm cache ([SymbolicCache]) stays valid because no rule
///   changed.
/// * Bound values live in a [BoundCache] owned by the scope node that owns
///   the [Tokens] instance (the theme root, or a scope that overrides the
///   global channel). Nodes that don't override the global channel reuse
///   their parent's [BoundCache]; an overriding node gets its own, shared by
///   its subtree.
library;

import 'engine.dart';

/// Per-chain cache: minterm -> [SymbolicStyle]. Lives as long as the chain
/// (forever for const defaults). Optionally also caches bound values for
/// the most recent [Tokens] instance ([lookup]); the widget layer uses a
/// [BoundCache] instead.
class SymbolicCache<F extends Enum> {
  SymbolicCache(this.rules, this.fields,
      {this.cacheBound = true, this.composites = const {}});

  final List<FlatRule<F>> rules;
  final List<F> fields;
  final Map<F, Composite> composites;

  /// Whether [lookup] caches bound values per tokens instance. Without it
  /// every lookup binds.
  final bool cacheBound;

  final Map<Minterm, SymbolicStyle<F>> _symbolic = <Minterm, SymbolicStyle<F>>{};
  final Map<Minterm, Map<F, Object>> _bound = <Minterm, Map<F, Object>>{};
  Tokens? _boundFor;

  int symbolicHits = 0;
  int symbolicMisses = 0;
  int boundHits = 0;
  int boundMisses = 0;

  /// Number of cached symbolic minterms.
  int get symbolicEntries => _symbolic.length;

  SymbolicStyle<F> symbolic(Minterm m) {
    final SymbolicStyle<F>? s = _symbolic[m];
    if (s != null) {
      symbolicHits++;
      return s;
    }
    symbolicMisses++;
    return _symbolic[m] = resolveSymbolic(rules, m, fields, composites: composites);
  }

  Map<F, Object> lookup(Minterm m, Tokens tokens) {
    if (!cacheBound) {
      return symbolic(m).bind(tokens, m);
    }
    if (!identical(tokens, _boundFor)) {
      _bound.clear();
      _boundFor = tokens;
    }
    final Map<F, Object>? b = _bound[m];
    if (b != null) {
      boundHits++;
      return b;
    }
    boundMisses++;
    return _bound[m] = symbolic(m).bind(tokens, m);
  }

  void resetCounters() {
    symbolicHits = symbolicMisses = boundHits = boundMisses = 0;
  }
}

/// Bound values for ONE [Tokens] instance, for every chain: (chain's
/// [SymbolicCache], minterm) -> values. Owned by the scope node that owns
/// [tokens]; replaced (not cleared) when that node's global channel
/// changes, so a stale instance can't be reused by accident.
class BoundCache {
  BoundCache(this.tokens);

  final Tokens tokens;

  // Keyed weakly (Expando) instead of a Map, because
  // widget instances with call-site rules own short-lived chains; a Map
  // would keep every replaced chain alive for the lifetime of the node.
  final Expando<Map<Minterm, Map<Enum, Object>>> _map =
      Expando<Map<Minterm, Map<Enum, Object>>>('BoundCache');

  int hits = 0;
  int misses = 0;

  /// Number of bound (chain, minterm) entries created (misses).
  int get entries => misses;

  Map<F, Object> lookup<F extends Enum>(SymbolicCache<F> chain, Minterm m) {
    final Map<Minterm, Map<Enum, Object>> perChain =
        _map[chain] ??= <Minterm, Map<Enum, Object>>{};
    final Map<Enum, Object>? b = perChain[m];
    if (b != null) {
      hits++;
      return b as Map<F, Object>;
    }
    misses++;
    final Map<F, Object> v = chain.symbolic(m).bind(tokens, m);
    perChain[m] = v;
    return v;
  }
}

/// Which style channels a scope update affects.
sealed class AffectedChannels {
  const AffectedChannels();
}

/// Every style channel (any global-channel change).
final class AllChannels extends AffectedChannels {
  const AllChannels();
  @override
  String toString() => 'all';
}

/// Only these component channels (keyed by field enum type).
final class SomeChannels extends AffectedChannels {
  const SomeChannels(this.channels);
  final Set<Type> channels;
  bool get isEmpty => channels.isEmpty;
  @override
  String toString() => '$channels';
}

const AllChannels allChannels = AllChannels();

/// A simulated StyleTheme / StyleScope node. A node holds its own
/// component rules per channel (keyed by field enum type) and optionally
/// overrides the global token channel. [boundCache] is the node's own when
/// it owns a [Tokens] instance (root, or a global override), otherwise the
/// nearest ancestor's.
class ScopeNode {
  /// The theme root: owns the global channel.
  ScopeNode.root(Tokens tokens, {Map<Type, Object> rules = const <Type, Object>{}})
      : parent = null,
        _tokens = tokens,
        _bound = BoundCache(tokens),
        rules = Map<Type, Object>.unmodifiable(rules);

  /// A scope below [parent]. With [tokens] it overrides the global channel
  /// for its subtree (and gets its own [BoundCache]); without, it reuses
  /// the parent's.
  ScopeNode.child(ScopeNode this.parent,
      {Tokens? tokens, Map<Type, Object> rules = const <Type, Object>{}})
      : _tokens = tokens,
        _bound = tokens == null ? null : BoundCache(tokens),
        rules = Map<Type, Object>.unmodifiable(rules);

  final ScopeNode? parent;
  final Tokens? _tokens;
  final BoundCache? _bound;

  /// Component rule lists contributed by this node, per channel. Compared
  /// by identity, then element-wise, in [affectedBy].
  final Map<Type, Object> rules;

  /// Whether this node overrides the global channel.
  bool get overridesGlobal => _tokens != null;

  /// The global channel visible here.
  Tokens get tokens => _tokens ?? parent!.tokens;

  /// The bound cache shared by this node's subtree up to the next override.
  BoundCache get boundCache => _bound ?? parent!.boundCache;

  /// Resolves [chain] at [m] in this scope: symbolic cache (per chain,
  /// shared by every scope) + this scope's bound cache.
  Map<F, Object> resolve<F extends Enum>(SymbolicCache<F> chain, Minterm m) =>
      boundCache.lookup(chain, m);

  /// Simulates `StyleScope.updateShouldNotifyDependent(old, aspects)` for
  /// replacing [old] with [next] at the same position: a different global
  /// channel (not identical, or the override was added/removed) affects
  /// every channel; otherwise only channels whose rule lists differ.
  static AffectedChannels affectedBy(ScopeNode old, ScopeNode next) {
    if (old.overridesGlobal != next.overridesGlobal ||
        !identical(old._tokens, next._tokens)) {
      return allChannels;
    }
    final Set<Type> changed = <Type>{};
    for (final Type t in <Type>{...old.rules.keys, ...next.rules.keys}) {
      final Object? a = old.rules[t];
      final Object? b = next.rules[t];
      if (identical(a, b)) {
        continue;
      }
      if (a is List && b is List && a.length == b.length) {
        bool same = true;
        for (int i = 0; i < a.length && same; i++) {
          same = identical(a[i], b[i]) || a[i] == b[i];
        }
        if (same) {
          continue;
        }
      }
      changed.add(t);
    }
    return SomeChannels(changed);
  }
}

/// Legacy-style cache keyed by (rules identity, minterm): a new rule list
/// (e.g. rebuilt from a new ColorScheme) drops everything.
class RulesKeyedCache<F extends Enum> {
  RulesKeyedCache(this.fields, {this.composites = const {}});

  final List<F> fields;
  final Map<F, Composite> composites;
  Object? _rulesId;
  final Map<Minterm, Map<F, Object>> _map = <Minterm, Map<F, Object>>{};
  int hits = 0;
  int misses = 0;

  Map<F, Object> lookup(List<FlatRule<F>> rules, Minterm m, {Tokens? tokens}) {
    if (!identical(rules, _rulesId)) {
      _map.clear();
      _rulesId = rules;
    }
    final Map<F, Object>? v = _map[m];
    if (v != null) {
      hits++;
      return v;
    }
    misses++;
    return _map[m] = resolve(rules, m, fields, tokens: tokens, composites: composites).values;
  }
}
