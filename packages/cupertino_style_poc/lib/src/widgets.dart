// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Widget layer: rule channels, the persistent provider chain, StyleTheme /
/// StyleScope, per-channel notification, the two-stage caches and the
/// read API.
///
/// * Every rule reports its channel through [Rule.addTo]; no runtimeType.
/// * A [StyleNode] is one provider (the theme root or one scope). Per
///   channel it holds a [ChannelLink]: a persistent linked list from the
///   root to this node that skips nodes without rules for the channel, so
///   appending a scope is O(#channels it touches) and unchanged channels
///   keep the identical link object. Identity of links is what
///   [_StyleModel.updateShouldNotifyDependent] compares.
/// * Stage 1 cache (symbolic, token reads unbound) hangs on the link, so
///   every instance of a component under the same chain shares it, across
///   [Tokens] instances. Stage 2 (bound values) is the node's [BoundCache],
///   owned by the node that changes the global channel (theme root, or a
///   scope with [TokenRule]s); other nodes reuse their parent's.
library;

import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoTheme, CupertinoUserInterfaceLevel, CupertinoUserInterfaceLevelData;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_adapter.dart';
import 'engine/cache.dart';
import 'engine/engine.dart';

// ---------------------------------------------------------------------------
// Rules and channels.

/// A rule of any channel. Component rules ([ComponentRule]) and global
/// token rules ([TokenRule]) can share one list; each reports its channel.
@immutable
abstract base class Rule {
  const Rule();

  /// Adds this rule to its channel. A generated component rule does
  /// `channels.add<ButtonRule>(this)`.
  void addTo(RuleChannels channels);
}

/// A rule of one component channel. [F] is the component's field type.
abstract base class ComponentRule<F extends Enum> extends Rule {
  const ComponentRule();

  /// The engine form of this rule (cached by the implementation).
  RawRule<F> toRaw();
}

/// The rules of one provider, grouped by channel in list order.
final class RuleChannels {
  RuleChannels._();

  /// Groups [rules] by calling [Rule.addTo] on each, in order.
  factory RuleChannels.of(List<Rule> rules) {
    final RuleChannels c = RuleChannels._();
    for (final Rule r in rules) {
      r.addTo(c);
    }
    return c;
  }

  final Map<Type, List<Rule>> _byChannel = <Type, List<Rule>>{};
  final List<TokenRule> _tokens = <TokenRule>[];

  /// Adds [rule] to channel [R] (the channel key is the type argument, so a
  /// `.any` subclass or a third-party subclass lands in the same channel).
  void add<R extends Rule>(R rule) {
    (_byChannel.putIfAbsent(R, () => <R>[]) as List<R>).add(rule);
  }

  /// Adds a rule of the global token channel.
  void addToken(TokenRule rule) => _tokens.add(rule);

  /// The channels this provider has rules for.
  Iterable<Type> get channels => _byChannel.keys;

  /// The rules of channel [channel], in order (null when none).
  List<Rule>? rulesOf(Type channel) => _byChannel[channel];

  /// The global token channel rules, in order.
  List<TokenRule> get tokens => _tokens;
}

/// Condition of a [TokenRule]: environment dimensions only.
@immutable
final class TokenWhen {
  const TokenWhen({this.brightness, this.highContrast, this.interfaceLevel});

  final Set<Brightness>? brightness;
  final bool? highContrast;
  final Set<CupertinoUserInterfaceLevelData>? interfaceLevel;

  Condition toCondition() => Condition(<Dimension<Object>, Object>{
        EnvDims.brightness: ?brightness,
        EnvDims.highContrast: ?highContrast,
        EnvDims.interfaceLevel: ?interfaceLevel,
      });

  @override
  bool operator ==(Object other) =>
      other is TokenWhen &&
      setEquals(other.brightness, brightness) &&
      other.highContrast == highContrast &&
      setEquals(other.interfaceLevel, interfaceLevel);

  @override
  int get hashCode => Object.hash(
      brightness == null ? null : Object.hashAllUnordered(brightness!),
      highContrast,
      interfaceLevel == null ? null : Object.hashAllUnordered(interfaceLevel!));
}

/// A rule of the global token channel: sets group tokens (or derives them
/// from other tokens) under an environment condition.
final class TokenRule extends Rule {
  const TokenRule(this.when, {this.values = const <Enum, Object>{}, this.derive = const <Enum, DeriveSource>{}});

  /// Whole-group sugar: every non-null field of [value] (one rule).
  static TokenRule group<G extends Object>(TokenGroup<G> group, G value, {TokenWhen when = const TokenWhen()}) =>
      TokenRule(when, values: <Enum, Object>{
        for (final GroupToken<G, Object> t in group.tokens)
          if (t.of(value) case final Object v) t.token: v,
      });

  final TokenWhen when;
  final Map<Enum, Object> values;
  final Map<Enum, DeriveSource> derive;

  @override
  void addTo(RuleChannels channels) => channels.addToken(this);

  static final Expando<RawRule<Enum>> _raw = Expando<RawRule<Enum>>('TokenRule.raw');

  RawRule<Enum> toRaw() =>
      _raw[this] ??= RawRule<Enum>(when.toCondition(), style: Style<Enum>(values), derive: Derive<Enum>(derive));

  @override
  bool operator ==(Object other) =>
      other is TokenRule && other.when == when && mapEquals(other.values, values) && mapEquals(other.derive, derive);

  @override
  int get hashCode => Object.hash(when, Object.hashAllUnordered(values.entries.map((e) => Object.hash(e.key, e.value))));
}

/// Element-wise list equality: identity first, then `==` per element.
bool rulesEqual(List<Object>? a, List<Object>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (!identical(a[i], b[i]) && a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

// ---------------------------------------------------------------------------
// Environment.

/// Environment dimensions. Every component carries all three, and so does
/// the global token channel.
abstract final class EnvDims {
  static const Dimension<Brightness> brightness =
      Dimension<Brightness>('brightness', Brightness.values, environment: true);
  static const BoolDimension highContrast = BoolDimension('highContrast', environment: true);
  static const Dimension<CupertinoUserInterfaceLevelData> interfaceLevel = Dimension<CupertinoUserInterfaceLevelData>(
      'interfaceLevel', CupertinoUserInterfaceLevelData.values,
      environment: true);

  static const List<Dimension<Object>> all = <Dimension<Object>>[brightness, highContrast, interfaceLevel];
}

/// An explicit environment set by [StyleTheme] / [StyleScope]. A null
/// field is read from the context at the component
/// (`CupertinoTheme.brightnessOf`, `MediaQuery.highContrastOf`,
/// `CupertinoUserInterfaceLevel.maybeOf`).
@immutable
final class StyleEnvironment {
  const StyleEnvironment({this.brightness, this.highContrast, this.interfaceLevel});

  static const StyleEnvironment none = StyleEnvironment();

  final Brightness? brightness;
  final bool? highContrast;
  final CupertinoUserInterfaceLevelData? interfaceLevel;

  /// [inner]'s set fields over this one's.
  StyleEnvironment merge(StyleEnvironment? inner) => inner == null
      ? this
      : StyleEnvironment(
          brightness: inner.brightness ?? brightness,
          highContrast: inner.highContrast ?? highContrast,
          interfaceLevel: inner.interfaceLevel ?? interfaceLevel,
        );

  /// Every field set: explicit ones, the rest from [context]. Reading the
  /// context registers the usual dependencies (CupertinoTheme, MediaQuery,
  /// CupertinoUserInterfaceLevel), so context changes rebuild as today.
  ResolvedEnvironment resolve(BuildContext context) => ResolvedEnvironment(
        brightness: brightness ?? CupertinoTheme.brightnessOf(context),
        highContrast: highContrast ?? MediaQuery.highContrastOf(context),
        interfaceLevel:
            interfaceLevel ?? CupertinoUserInterfaceLevel.maybeOf(context) ?? CupertinoUserInterfaceLevelData.base,
      );

  @override
  bool operator ==(Object other) =>
      other is StyleEnvironment &&
      other.brightness == brightness &&
      other.highContrast == highContrast &&
      other.interfaceLevel == interfaceLevel;

  @override
  int get hashCode => Object.hash(brightness, highContrast, interfaceLevel);
}

/// A fully determined environment (the env part of a minterm).
@immutable
final class ResolvedEnvironment {
  const ResolvedEnvironment({required this.brightness, required this.highContrast, required this.interfaceLevel});

  final Brightness brightness;
  final bool highContrast;
  final CupertinoUserInterfaceLevelData interfaceLevel;

  /// The values in [EnvDims.all] order.
  List<Object> get values => <Object>[brightness, highContrast, interfaceLevel];

  @override
  String toString() => '(${brightness.name}, hc: $highContrast, ${interfaceLevel.name})';
}

// ---------------------------------------------------------------------------
// Persistent chain.

/// One channel's rules from the root to some node: the nearest provider
/// with rules for the channel plus a pointer to the previous such link.
final class ChannelLink {
  ChannelLink._(this.parent, this.rules, {required this.isScope});

  final ChannelLink? parent;
  final List<Rule> rules;

  /// Whether [rules] belong to a scope (false: the theme root).
  final bool isScope;

  /// Links from the root to this one (outer first).
  List<ChannelLink> get links {
    final List<ChannelLink> out = <ChannelLink>[];
    for (ChannelLink? l = this; l != null; l = l.parent) {
      out.add(l);
    }
    return out.reversed.toList();
  }

  /// Rule lists from the root to this link (outer first).
  List<List<Rule>> get lists => <List<Rule>>[for (final ChannelLink l in links) l.rules];

  // Stage-1 cache for (component defaults + this chain); see
  // [ComponentStyle.chainCache].
  Object? _symbolic;
  Object? _symbolicOwner;
}

/// A provider in the chain: the theme root ([isScope] false) or a scope.
final class StyleNode {
  StyleNode._({
    required this.parent,
    required this.isScope,
    required this.rules,
    required this.environment,
    required this.groups,
    StyleNode? previous,
  })  : channels = RuleChannels.of(rules),
        effectiveEnvironment = (parent?.effectiveEnvironment ?? StyleEnvironment.none).merge(environment) {
    // Links: reuse the previous node's link when neither the parent link
    // nor this node's list changed, so identity == "unchanged".
    final Set<Type> keys = <Type>{...?parent?._links.keys, ...channels.channels};
    for (final Type k in keys) {
      final ChannelLink? parentLink = parent?._links[k];
      final List<Rule>? own = channels.rulesOf(k);
      if (own == null) {
        if (parentLink != null) {
          _links[k] = parentLink; // pointer skipping
        }
        continue;
      }
      final ChannelLink? prev = previous?._links[k];
      if (prev != null &&
          identical(prev.parent, parentLink) &&
          !identical(prev, previous?.parent?._links[k]) &&
          rulesEqual(prev.rules, own)) {
        _links[k] = prev;
      } else {
        _links[k] = ChannelLink._(parentLink, own, isScope: isScope);
      }
    }
    // Global token channel: own Tokens + BoundCache only when this node
    // changes the global channel (the root always does).
    final List<TokenRule> ownTokens = channels.tokens;
    if (parent != null && ownTokens.isEmpty) {
      _tokenRules = parent!._tokenRules;
      tokens = parent!.tokens;
      boundCache = parent!.boundCache;
    } else {
      _tokenRules = <TokenRule>[...?parent?._tokenRules, ...ownTokens];
      if (previous != null &&
          identical(previous.groups, groups) &&
          rulesEqual(previous._tokenRules, _tokenRules) &&
          (previous.parent == null || !identical(previous.tokens, previous.parent!.tokens))) {
        tokens = previous.tokens;
        boundCache = previous.boundCache;
      } else {
        tokens = buildTokens(groups, _tokenRules);
        boundCache = BoundCache(tokens);
      }
    }
  }

  /// The theme root.
  factory StyleNode.root({
    List<Rule> rules = const <Rule>[],
    StyleEnvironment? environment,
    List<TokenGroup<Object>> groups = const <TokenGroup<Object>>[],
    StyleNode? previous,
  }) =>
      StyleNode._(
          parent: null, isScope: false, rules: rules, environment: environment, groups: groups, previous: previous);

  /// A scope below [parent].
  factory StyleNode.scope(StyleNode parent,
          {List<Rule> rules = const <Rule>[], StyleEnvironment? environment, StyleNode? previous}) =>
      StyleNode._(
          parent: parent,
          isScope: true,
          rules: rules,
          environment: environment,
          groups: parent.groups,
          previous: previous);

  /// The node used when there is no [StyleTheme] above.
  static final StyleNode fallback = StyleNode.root();

  final StyleNode? parent;
  final bool isScope;

  /// This provider's own rules, as written.
  final List<Rule> rules;
  final RuleChannels channels;

  /// This provider's own environment override.
  final StyleEnvironment? environment;

  /// Every override from the root to here (inner wins).
  final StyleEnvironment effectiveEnvironment;

  /// App token groups provided by the theme (the Cupertino group is
  /// always there).
  final List<TokenGroup<Object>> groups;

  final Map<Type, ChannelLink> _links = <Type, ChannelLink>{};
  late final List<TokenRule> _tokenRules;

  /// The global token channel visible here.
  late final Tokens tokens;

  /// Stage-2 cache shared by this node's subtree up to the next node that
  /// changes the global channel.
  late final BoundCache boundCache;

  /// Channel [channel]'s link here (null: only the component defaults).
  ChannelLink? linkFor(Type channel) => _links[channel];

  /// The scope nodes from the outermost to this one (empty for the root).
  List<StyleNode> get scopeChain {
    final List<StyleNode> out = <StyleNode>[];
    for (StyleNode? n = this; n != null && n.isScope; n = n.parent) {
      out.add(n);
    }
    return out.reversed.toList();
  }
}

// ---------------------------------------------------------------------------
// Inherited model.

/// Aspects other than component channels.
enum StyleAspect {
  /// The global token channel and the environment. Every component
  /// subscribes to it.
  global,

  /// Any change of the node (used by nested scopes to rebuild their own
  /// node).
  chain,
}

class _StyleModel extends InheritedModel<Object> implements InheritedTheme {
  const _StyleModel({required this.node, required super.child});

  final StyleNode node;

  @override
  bool updateShouldNotify(_StyleModel oldWidget) => !identical(oldWidget.node, node);

  @override
  bool updateShouldNotifyDependent(_StyleModel oldWidget, Set<Object> dependencies) {
    final StyleNode a = oldWidget.node;
    final StyleNode b = node;
    if (identical(a, b)) {
      return false;
    }
    if (dependencies.contains(StyleAspect.chain)) {
      return true;
    }
    final bool globalChanged = !identical(a.tokens, b.tokens) || a.effectiveEnvironment != b.effectiveEnvironment;
    if (globalChanged) {
      return true;
    }
    for (final Object d in dependencies) {
      if (d is Type && !identical(a.linkFor(d), b.linkFor(d))) {
        return true;
      }
    }
    return false;
  }

  /// A route pushed with `InheritedTheme.capture`
  /// gets a snapshot of the caller's scope chain (not of the theme root,
  /// which stays live at the route).
  @override
  Widget wrap(BuildContext context, Widget child) {
    if (!node.isScope) {
      return child;
    }
    return _CapturedStyleScope(snapshot: node, child: child);
  }
}

StyleNode _chainOf(BuildContext context) =>
    InheritedModel.inheritFrom<_StyleModel>(context, aspect: StyleAspect.chain)?.node ?? StyleNode.fallback;

// ---------------------------------------------------------------------------
// Public widgets.

/// The global theme: component rules and global token rules in one list.
class StyleTheme extends StatefulWidget {
  const StyleTheme({
    super.key,
    this.rules = const <Rule>[],
    this.environment,
    this.groups = const <TokenGroup<Object>>[],
    required this.child,
  });

  final List<Rule> rules;
  final StyleEnvironment? environment;

  /// App token groups (like ThemeExtension types). Rules may reference
  /// only tokens of these groups and of the built-in Cupertino group.
  final List<TokenGroup<Object>> groups;
  final Widget child;

  /// The node visible at [context], subscribing to [channel] and to the
  /// global aspect only.
  static StyleNode nodeOf(BuildContext context, Type channel) {
    final _StyleModel? m = InheritedModel.inheritFrom<_StyleModel>(context, aspect: channel);
    InheritedModel.inheritFrom<_StyleModel>(context, aspect: StyleAspect.global);
    return m?.node ?? StyleNode.fallback;
  }

  /// The node visible at [context] without subscribing (for reads such as
  /// `resolveStyle`).
  static StyleNode peekNode(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<_StyleModel>()?.widget as _StyleModel?)?.node ??
      StyleNode.fallback;

  /// Reads a group token outside components, at the environment of
  /// [context].
  static T? tokenOf<G extends Object, T extends Object>(BuildContext context, GroupToken<G, T> token) {
    final StyleNode node =
        InheritedModel.inheritFrom<_StyleModel>(context, aspect: StyleAspect.global)?.node ?? StyleNode.fallback;
    final ResolvedEnvironment env = node.effectiveEnvironment.resolve(context);
    return node.tokens.read(token, Minterm(EnvDims.all, env.values)) as T?;
  }

  @override
  State<StyleTheme> createState() => _StyleThemeState();
}

class _StyleThemeState extends State<StyleTheme> {
  StyleNode? _node;

  @override
  Widget build(BuildContext context) {
    final StyleNode? prev = _node;
    if (prev == null ||
        !rulesEqual(prev.rules, widget.rules) ||
        prev.environment != widget.environment ||
        !listEquals(prev.groups, widget.groups)) {
      _node = StyleNode.root(
          rules: widget.rules,
          environment: widget.environment,
          groups: prev != null && listEquals(prev.groups, widget.groups) ? prev.groups : widget.groups,
          previous: prev);
    }
    return _StyleModel(node: _node!, child: widget.child);
  }
}

/// A local override. Its rules are appended after the outer providers'
/// rules (merge, not replace); [environment] overrides environment
/// dimensions for the subtree.
class StyleScope extends StatefulWidget {
  const StyleScope({super.key, this.rules = const <Rule>[], this.environment, required this.child});

  final List<Rule> rules;
  final StyleEnvironment? environment;
  final Widget child;

  @override
  State<StyleScope> createState() => _StyleScopeState();
}

class _StyleScopeState extends State<StyleScope> {
  StyleNode? _node;

  @override
  Widget build(BuildContext context) {
    final StyleNode parent = _chainOf(context);
    final StyleNode? prev = _node;
    if (prev == null ||
        !identical(prev.parent, parent) ||
        !rulesEqual(prev.rules, widget.rules) ||
        prev.environment != widget.environment) {
      _node = StyleNode.scope(parent, rules: widget.rules, environment: widget.environment, previous: prev);
    }
    return _StyleModel(node: _node!, child: widget.child);
  }
}

/// The route side of a captured scope chain: replays the snapshot's scope
/// nodes (outer to inner) on top of the route's own chain (the live
/// StyleTheme plus any scope above the Navigator). Scopes above the
/// Navigator therefore appear twice in the route's chain, which resolves
/// the same as once (a repeated list adds no new winner).
class _CapturedStyleScope extends StatefulWidget {
  const _CapturedStyleScope({required this.snapshot, required this.child});

  final StyleNode snapshot;
  final Widget child;

  @override
  State<_CapturedStyleScope> createState() => _CapturedStyleScopeState();
}

class _CapturedStyleScopeState extends State<_CapturedStyleScope> {
  List<StyleNode> _replayed = <StyleNode>[];

  @override
  Widget build(BuildContext context) {
    StyleNode node = _chainOf(context);
    final List<StyleNode> scopes = widget.snapshot.scopeChain;
    final List<StyleNode> next = <StyleNode>[];
    for (int i = 0; i < scopes.length; i++) {
      final StyleNode s = scopes[i];
      final StyleNode? prev = i < _replayed.length ? _replayed[i] : null;
      if (prev != null &&
          identical(prev.parent, node) &&
          identical(prev.rules, s.rules) &&
          prev.environment == s.environment) {
        node = prev;
      } else {
        node = StyleNode.scope(node, rules: s.rules, environment: s.environment, previous: prev);
      }
      next.add(node);
    }
    _replayed = next;
    return _StyleModel(node: node, child: widget.child);
  }
}

// ---------------------------------------------------------------------------
// Component side.

/// A component's static description: spec + const default rules.
final class ComponentStyle<F extends Enum> {
  ComponentStyle({required this.channel, required this.spec, required this.defaults});

  /// The channel key (the component's rule type).
  final Type channel;
  final ComponentSpec<F> spec;
  final List<RawRule<F>> defaults;

  late final SymbolicCache<F> _defaultsOnly = _build(const <ChannelLink>[], const <Never>[]);

  static final Expando<List<String>> _providerNames = Expando<List<String>>('providerNames');

  /// Flattens defaults + [links] + [callSite] into one chain. Dynamic colors
  /// are expanded into environment-conditioned sub-rules with plain colors
  /// ([cupertinoEnvSplitter]); the expansion is cached per authored rule,
  /// so the defaults and each theme / scope list are expanded once and an
  /// instance only expands its own call-site rules. The authored lists are
  /// not touched.
  ///
  /// Debug: a dynamic color nested where expansion can't reach fails
  /// ([debugCheckEnvExpandable]).
  SymbolicCache<F> _build(List<ChannelLink> links, List<ComponentRule<F>> callSite) {
    final List<List<RawRule<F>>> providers = <List<RawRule<F>>>[
      defaults,
      for (final ChannelLink l in links) <RawRule<F>>[for (final Rule r in l.rules) (r as ComponentRule<F>).toRaw()],
      <RawRule<F>>[for (final ComponentRule<F> r in callSite) r.toRaw()],
    ];
    int scopes = 0;
    final List<String> names = <String>[
      'defaults',
      for (final ChannelLink l in links) l.isScope ? 'scope ${++scopes}' : 'theme',
      'call site',
    ];
    final List<FlatRule<F>> flat =
        chain<F>(providers, spec: spec, splitter: cupertinoEnvSplitter, providerNames: names);
    final SymbolicCache<F> cache = SymbolicCache<F>(flat, spec.fields, cacheBound: false, composites: spec.composites);
    _providerNames[cache] = names;
    return cache;
  }

  /// Stage-1 cache for the defaults plus [link]'s chain, shared by every
  /// instance under that link.
  SymbolicCache<F> chainCache(ChannelLink? link) {
    if (link == null) {
      return _defaultsOnly;
    }
    if (identical(link._symbolicOwner, this)) {
      return link._symbolic! as SymbolicCache<F>;
    }
    final SymbolicCache<F> c = _build(link.links, const <Never>[]);
    link
      .._symbolic = c
      .._symbolicOwner = this;
    return c;
  }
}

/// Per-instance resolver: reuses the shared chain cache when the instance
/// has no call-site rules; otherwise keeps its own stage-1 cache, rebuilt
/// only when the link or the call-site rules (compared element-wise)
/// change.
final class StyleResolver<F extends Enum> {
  StyleResolver(this.component);

  final ComponentStyle<F> component;

  ChannelLink? _link;
  bool _hasLink = false;
  List<ComponentRule<F>> _callSite = const <Never>[];
  SymbolicCache<F>? _own;

  /// Debug counter: stage-1 caches built for this instance.
  int debugOwnCacheBuilds = 0;

  SymbolicCache<F> _cacheFor(StyleNode node, List<ComponentRule<F>> callSite) {
    final ChannelLink? link = node.linkFor(component.channel);
    final SymbolicCache<F> cache;
    if (callSite.isEmpty) {
      cache = component.chainCache(link);
      _own = null;
    } else {
      if (_own == null || !_hasLink || !identical(_link, link) || !rulesEqual(_callSite, callSite)) {
        _own = component._build(link?.links ?? const <ChannelLink>[], callSite);
        debugOwnCacheBuilds++;
      }
      cache = _own!;
    }
    _link = link;
    _hasLink = true;
    _callSite = callSite;
    return cache;
  }

  /// The flattened chain for [node] + [callSite], after dynamic-color
  /// expansion.
  List<FlatRule<F>> debugChain(StyleNode node, List<ComponentRule<F>> callSite) => _cacheFor(node, callSite).rules;

  /// Resolved values at [m] for the chain at [node] + [callSite].
  Map<F, Object> resolve(StyleNode node, List<ComponentRule<F>> callSite, Minterm m) =>
      node.boundCache.lookup(_cacheFor(node, callSite), m);

  /// Debug: for every set field at [m], where its value comes from. The
  /// winning rule is reported as authored (provider and index in its list).
  /// When it is a sub-rule expanded from a dynamic color, the dynamic color
  /// and the slot are named too, e.g. `rule #3 (theme), systemBlue dark
  /// normal-contrast slot`. A value read from a token also names the token
  /// rule that set it: `rule #4 "rest" (defaults) <- primaryColor: rule #0
  /// "Cupertino defaults" (global), systemBlue dark normal-contrast slot`.
  Map<F, String> debugSources(StyleNode node, List<ComponentRule<F>> callSite, Minterm m) {
    final SymbolicCache<F> cache = _cacheFor(node, callSite);
    final List<String> names = ComponentStyle._providerNames[cache]!;
    final SymbolicStyle<F> s = cache.symbolic(m);
    final Tokens tokens = node.tokens;
    final Resolved<Enum> global = tokens.global.resolved(tokens.envMinterm(m));
    return <F, String>{
      for (final MapEntry<F, FlatRule<F>> e in s.winners.entries)
        if (s.symbols.containsKey(e.key))
          e.key: <String>[
            e.value.describeSource((int p) => names[p], e.key),
            if (s.symbols[e.key] case TokVal(:final TokenRef<Enum> ref))
              if (global.winners[ref.token] case final FlatRule<Enum> t)
                '<- ${ref.token.name}${ref.alpha == null ? '' : ' (alpha ${ref.alpha})'}: '
                    '${t.describeSource((int _) => 'global', ref.token)}',
          ].join(' '),
    };
  }
}

/// Debug hook: called on every build of a styled component (used by the
/// example and tests to count rebuilds).
abstract final class StyleDebug {
  static void Function(Widget widget)? onComponentBuild;
}
