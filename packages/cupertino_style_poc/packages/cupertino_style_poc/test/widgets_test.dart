// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Widget layer: channels, persistent chain, per-channel notification,
// caches, environment overrides, route capture, WidgetStateProperty
// compatibility.
import 'package:cupertino_style_poc/cupertino_style_poc.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoColors, CupertinoPageRoute, CupertinoUserInterfaceLevelData;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/resolve_own.dart';

const ResolvedEnvironment light =
    ResolvedEnvironment(brightness: Brightness.light, highContrast: false, interfaceLevel: CupertinoUserInterfaceLevelData.base);

const ButtonRule red = ButtonRule(ButtonWhen(disabled: false),
    style: ButtonStyle(backgroundColor: Color(0xFFFF0000)));
const ButtonRule blue = ButtonRule(ButtonWhen(disabled: false),
    style: ButtonStyle(backgroundColor: Color(0xFF0000FF)));
const SwitchRule orangeTrack =
    SwitchRule(SwitchWhen(selected: true), style: SwitchStyle(trackColor: Color(0xFFFF8800)));

/// Counts component builds by key.
final Map<Key, int> builds = <Key, int>{};
void _count(Widget w) {
  if (w.key != null) {
    builds[w.key!] = (builds[w.key!] ?? 0) + 1;
  }
}

const Key bKey = Key('b');
const Key sKey = Key('s');

/// A const subtree, so only inherited-model notifications rebuild it.
class _Pair extends StatelessWidget {
  const _Pair();
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Button.filled(key: bKey, onPressed: () {}, child: const Text('b')),
        Switch(key: sKey, value: true, onChanged: (bool _) {}),
      ]);
}

Color? bg(WidgetTester tester, Key key) => ((tester
            .widget<DecoratedBox>(find.descendant(of: find.byKey(key), matching: find.byType(DecoratedBox)).first)
            .decoration) as ShapeDecoration)
    .color;

void main() {
  setUp(() {
    builds.clear();
    StyleDebug.onComponentBuild = _count;
  });
  tearDown(() => StyleDebug.onComponentBuild = null);

  test('addTo groups a mixed list by channel; .any lands in the same channel', () {
    const ButtonRule any = ButtonRule.whenAny(<ButtonWhen>[
      ButtonWhen(pressed: true),
      ButtonWhen(focused: true),
    ], style: ButtonStyle());
    final RuleChannels c = RuleChannels.of(<Rule>[red, orangeTrack, any, cupertinoDefaultTokens]);
    expect(c.rulesOf(ButtonRule), <Rule>[red, any]);
    expect(c.rulesOf(SwitchRule), <Rule>[orangeTrack]);
    expect(c.tokens, <TokenRule>[cupertinoDefaultTokens]);
  });

  test('links: pointer skipping and reuse of unchanged links', () {
    final StyleNode root = StyleNode.root(rules: const <Rule>[red, orangeTrack]);
    final StyleNode a = StyleNode.scope(root, rules: const <Rule>[blue]);
    // Switch: a has no switch rules, so it points at the root's link.
    expect(identical(a.linkFor(SwitchRule), root.linkFor(SwitchRule)), isTrue);
    expect(a.linkFor(ButtonRule)!.lists, <List<Rule>>[<Rule>[red], <Rule>[blue]]);
    // A new but equal list at the same position reuses the link object.
    final StyleNode a2 = StyleNode.scope(root, rules: <Rule>[blue], previous: a);
    expect(identical(a2.linkFor(ButtonRule), a.linkFor(ButtonRule)), isTrue);
    // A different list gets a new link; the other channel keeps its link.
    final StyleNode a3 = StyleNode.scope(root, rules: const <Rule>[red], previous: a2);
    expect(identical(a3.linkFor(ButtonRule), a2.linkFor(ButtonRule)), isFalse);
    expect(identical(a3.linkFor(SwitchRule), a2.linkFor(SwitchRule)), isTrue);
    // Tokens / bound cache: a scope without token rules shares its parent's.
    expect(identical(a3.tokens, root.tokens), isTrue);
    expect(identical(a3.boundCache, root.boundCache), isTrue);
    final StyleNode t = StyleNode.scope(root, rules: const <Rule>[CupertinoTokenRule(primaryColor: Color(0xFF123456))]);
    expect(identical(t.tokens, root.tokens), isFalse);
    expect(identical(t.boundCache, root.boundCache), isFalse);
  });

  testWidgets('changing a button rule notifies buttons only; equal lists notify nobody', (WidgetTester tester) async {
    Widget app(List<Rule> rules) => inEnvironment(light, StyleTheme(child: StyleScope(rules: rules, child: const _Pair())));
    await tester.pumpWidget(app(const <Rule>[red, orangeTrack]));
    expect(builds[bKey], 1);
    expect(builds[sKey], 1);

    await tester.pumpWidget(app(<Rule>[red, orangeTrack])); // new list, equal elements
    expect(builds[bKey], 1);
    expect(builds[sKey], 1);

    await tester.pumpWidget(app(const <Rule>[blue, orangeTrack]));
    expect(builds[bKey], 2);
    expect(builds[sKey], 1, reason: 'switch channel unchanged');
    expect(bg(tester, bKey), const Color(0xFF0000FF));

    await tester.pumpWidget(app(const <Rule>[blue]));
    expect(builds[bKey], 2, reason: 'button channel unchanged');
    expect(builds[sKey], 2);
  });

  testWidgets('a token change or an environment change notifies every component', (WidgetTester tester) async {
    Widget app({required List<Rule> theme, StyleEnvironment? env}) =>
        inEnvironment(light, StyleTheme(groups: <TokenGroup>[Brand.group], rules: theme, child: StyleScope(environment: env, child: const _Pair())));
    await tester.pumpWidget(app(theme: <Rule>[...BrandRule.teal]));
    await tester.pumpWidget(app(theme: <Rule>[...BrandRule.purple]));
    expect(builds[bKey], 2);
    expect(builds[sKey], 2);
    await tester.pumpWidget(app(
        theme: <Rule>[...BrandRule.purple], env: const StyleEnvironment(brightness: Brightness.dark)));
    expect(builds[bKey], 3);
    expect(builds[sKey], 3);
    // StyleScope(environment: dark) inside a light CupertinoTheme: dark values.
    expect(bg(tester, bKey)!.toARGB32(), CupertinoColors.systemBlue.darkColor.toARGB32());
  });

  testWidgets('nested scopes: an outer change reaches components under an inner scope', (WidgetTester tester) async {
    Widget app(List<Rule> outer) => inEnvironment(
        light,
        StyleTheme(
            child: StyleScope(
                rules: outer, child: const StyleScope(rules: <Rule>[orangeTrack], child: _Pair()))));
    await tester.pumpWidget(app(const <Rule>[red]));
    expect(bg(tester, bKey), const Color(0xFFFF0000));
    await tester.pumpWidget(app(const <Rule>[blue]));
    expect(bg(tester, bKey), const Color(0xFF0000FF));
    expect(builds[sKey], 1, reason: 'the inner scope rebuilt its node, but the switch link did not change');
  });

  testWidgets("a scope rule on the same field also replaces the theme's dark+pressed value", (WidgetTester tester) async {
    // An earlier draft of quick-version.md (Design Skeleton snippet 2): theme has a
    // dark+pressed tint, the scope sets the tint for `disabled: false`.
    // Order-only: the scope rule is later and also matches pressed, so it
    // wins there too. The radius (not written by the scope) survives. The
    // current text puts the dark+pressed value on foregroundColor; see
    // test/quick_version_snippets_test.dart.
    const ButtonRule themeTint = ButtonRule(ButtonWhen(disabled: false),
        style: ButtonStyle(backgroundColor: Color(0xFF00AA00), borderRadius: BorderRadius.all(Radius.circular(12))));
    const ButtonRule darkPressed = ButtonRule(
        ButtonWhen(pressed: true, brightness: Brightness.dark),
        style: ButtonStyle(backgroundColor: Color(0xFF004400)));
    const ButtonRule scopeOrange = ButtonRule(ButtonWhen(disabled: false),
        style: ButtonStyle(backgroundColor: Color(0xFFFF8800)));
    late BuildContext inner;
    late BuildContext outer;
    const Button b = Button.filled(onPressed: null, child: SizedBox());
    await tester.pumpWidget(inEnvironment(
        light,
        StyleTheme(
          environment: const StyleEnvironment(brightness: Brightness.dark),
          rules: const <Rule>[themeTint, darkPressed],
          child: Row(children: <Widget>[
            Builder(builder: (BuildContext c) {
              outer = c;
              return const SizedBox();
            }),
            StyleScope(
              rules: const <Rule>[scopeOrange],
              child: Builder(builder: (BuildContext c) {
                inner = c;
                return const SizedBox();
              }),
            ),
          ]),
        )));
    expect(b.resolveOwn(outer, pressed: true).backgroundColor, const Color(0xFF004400));
    expect(b.resolveOwn(inner, pressed: true).backgroundColor, const Color(0xFFFF8800), reason: 'dark+pressed lost in the scope');
    expect(b.resolveOwn(inner, pressed: true).borderRadius, const BorderRadius.all(Radius.circular(12)));
  });

  testWidgets('symbolic cache shared by instances and across token changes; bound cache per token node', (WidgetTester tester) async {
    Widget app(List<TokenRule> brand) => inEnvironment(
        light,
        StyleTheme(
            groups: <TokenGroup>[Brand.group],
            rules: <Rule>[
              ...brand,
              const ButtonRule(ButtonWhen(), style: ButtonStyleSpec(backgroundColor: .fromCustomToken(Brand.accent))),
            ],
            child: Row(children: <Widget>[
              Button(key: const Key('x'), onPressed: () {}, child: const Text('x')),
              Button(key: const Key('y'), onPressed: () {}, child: const Text('y')),
            ])));
    await tester.pumpWidget(app(BrandRule.teal));
    final BuildContext ctx = tester.element(find.byKey(const Key('x')));
    final StyleNode n1 = StyleTheme.peekNode(ctx);
    final ChannelLink? link = n1.linkFor(ButtonRule);
    final cache1 = buttonStyle.chainCache(link);
    final int misses1 = cache1.symbolicMisses;
    // Two instances x two minterms each (current + pressed, for the fade
    // target): two symbolic resolutions; the second instance hits the bound
    // cache of the theme node.
    expect(misses1, 2);
    expect(n1.boundCache.hits, greaterThanOrEqualTo(2));

    await tester.pumpWidget(app(BrandRule.purple));
    final StyleNode n2 = StyleTheme.peekNode(tester.element(find.byKey(const Key('x'))));
    expect(identical(n2.tokens, n1.tokens), isFalse);
    expect(identical(n2.boundCache, n1.boundCache), isFalse);
    // The rule list is equal, so the link and its symbolic cache survive the token change.
    expect(identical(n2.linkFor(ButtonRule), link), isTrue);
    expect(identical(buttonStyle.chainCache(link), cache1), isTrue);
    expect(cache1.symbolicMisses, misses1, reason: 'no new symbolic resolution after a token change');
    expect(cache1.symbolicHits, greaterThanOrEqualTo(2), reason: 'rebinding reuses the symbolic styles');
    expect(bg(tester, const Key('x'))!.toARGB32(),
        brandPurpleAccent.color.toARGB32());
  });

  testWidgets('call-site rules: per-instance stage-1 cache rebuilt only when they change', (WidgetTester tester) async {
    late StyleResolver<ButtonField> r;
    final StyleNode node = StyleNode.root();
    r = StyleResolver<ButtonField>(buttonStyle);
    final Minterm m = buttonMinterm(
        disabled: false, pressed: false, focused: false, appearance: ButtonAppearance.plain,
        sizeStyle: ButtonSize.large, env: light);
    r.resolve(node, const Button(onPressed: null, color: Color(0xFF00FF00), child: SizedBox()).callSiteRules(), m);
    r.resolve(node, const Button(onPressed: null, color: Color(0xFF00FF00), child: SizedBox()).callSiteRules(), m);
    expect(r.debugOwnCacheBuilds, 1);
    r.resolve(node, const Button(onPressed: null, color: Color(0xFF0000FF), child: SizedBox()).callSiteRules(), m);
    expect(r.debugOwnCacheBuilds, 2);
  });

  testWidgets('route capture: the pushed route gets a snapshot of the caller scope chain; the theme stays live',
      (WidgetTester tester) async {
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    late BuildContext caller;
    Widget app(List<Rule> theme, List<Rule> scope) => inEnvironment(
        light,
        StyleTheme(
          rules: theme,
          child: SizedBox(
            width: 400,
            height: 400,
            child: Navigator(
              key: nav,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => StyleScope(
                  rules: scope,
                  child: Builder(builder: (BuildContext c) {
                    caller = c;
                    return const SizedBox();
                  }),
                ),
              ),
            ),
          ),
        ));
    await tester.pumpWidget(app(const <Rule>[orangeTrack], const <Rule>[red]));

    void push({required bool capture}) {
      final CapturedThemes themes = InheritedTheme.capture(from: caller, to: nav.currentContext!);
      nav.currentState!.push(CupertinoPageRoute<void>(builder: (_) {
        final Widget content = Row(children: <Widget>[
          Button(key: const Key('d'), onPressed: () {}, child: const Text('d')),
          Switch(key: const Key('ds'), value: true, onChanged: (bool _) {}),
        ]);
        return capture ? themes.wrap(content) : content;
      }));
    }

    push(capture: false);
    await tester.pumpAndSettle();
    expect(bg(tester, const Key('d')), isNull, reason: 'without capture the scope rule does not reach the route');
    nav.currentState!.pop();
    await tester.pumpAndSettle();

    push(capture: true);
    await tester.pumpAndSettle();
    expect(bg(tester, const Key('d')), const Color(0xFFFF0000));
    SwitchStyle sw() => tester
        .widget<Switch>(find.byKey(const Key('ds')))
        .resolveOwn(tester.element(find.byKey(const Key('ds'))), selected: true);
    expect(sw().trackColor, const Color(0xFFFF8800));

    // Theme live: a new theme rule reaches the open route.
    await tester.pumpWidget(app(const <Rule>[], const <Rule>[red]));
    await tester.pumpAndSettle();
    expect(sw().trackColor!.toARGB32(), CupertinoColors.systemGreen.color.toARGB32());
    // Scope snapshot: changing the caller's scope does not reach the route.
    await tester.pumpWidget(app(const <Rule>[], const <Rule>[blue]));
    await tester.pumpAndSettle();
    expect(bg(tester, const Key('d')), const Color(0xFFFF0000));
  });

  testWidgets('route capture: a root token change reaches the open route, also through a snapshotted scope derive',
      (WidgetTester tester) async {
    const Color purple = Color(0xFF8E24AA);
    const Color teal = Color(0xFF00897B);
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    late BuildContext caller;
    // The scope derives the background from a token: the rule is
    // snapshotted, the token it reads is not.
    const List<Rule> scope = <Rule>[
      ButtonRule.always(style: .derive(backgroundColor: .opacity(.fromToken(.primaryColor), 0.5))),
    ];
    Widget app(Color primary) => inEnvironment(
        light,
        StyleTheme(
          rules: <Rule>[CupertinoTokenRule(primaryColor: primary)],
          child: SizedBox(
            width: 400,
            height: 400,
            child: Navigator(
              key: nav,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => StyleScope(
                  rules: scope,
                  child: Builder(builder: (BuildContext c) {
                    caller = c;
                    return const SizedBox();
                  }),
                ),
              ),
            ),
          ),
        ));
    await tester.pumpWidget(app(purple));
    final CapturedThemes themes = InheritedTheme.capture(from: caller, to: nav.currentContext!);
    nav.currentState!.push(CupertinoPageRoute<void>(
        builder: (_) => themes.wrap(Button(key: const Key('d'), onPressed: () {}, child: const Text('d')))));
    await tester.pumpAndSettle();
    ButtonStyle d() => tester.widget<Button>(find.byKey(const Key('d'))).resolveOwn(tester.element(find.byKey(const Key('d'))));
    expect(d().foregroundColor, purple, reason: 'default foreground reads the root token');
    expect(d().backgroundColor, applyOpacity(purple, 0.5), reason: 'scope derive reads the root token');

    // Change the root token while the route is open.
    await tester.pumpWidget(app(teal));
    await tester.pumpAndSettle();
    expect(d().foregroundColor, teal);
    expect(d().backgroundColor, applyOpacity(teal, 0.5));
    expect(bg(tester, const Key('d')), applyOpacity(teal, 0.5), reason: 'painted, not only resolved');
  });

  testWidgets('route capture of nested scopes keeps the outer scope (not only the closest provider)',
      (WidgetTester tester) async {
    // InheritedTheme.capture keeps only the closest InheritedTheme of each
    // type. The closest style scope carries its whole scope chain, so an
    // outer scope's rule on a field the inner scope does not set survives.
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    late BuildContext caller;
    await tester.pumpWidget(inEnvironment(
        light,
        StyleTheme(
          child: SizedBox(
            width: 400,
            height: 400,
            child: Navigator(
              key: nav,
              onGenerateRoute: (_) => PageRouteBuilder<void>(
                pageBuilder: (_, _, _) => StyleScope(
                  rules: const <Rule>[red, ButtonRule.always(style: .values(minimumSize: Size(77, 33)))],
                  child: StyleScope(
                    rules: const <Rule>[blue],
                    child: Builder(builder: (BuildContext c) {
                      caller = c;
                      return const SizedBox();
                    }),
                  ),
                ),
              ),
            ),
          ),
        )));
    final CapturedThemes themes = InheritedTheme.capture(from: caller, to: nav.currentContext!);
    nav.currentState!.push(CupertinoPageRoute<void>(
        builder: (_) => themes.wrap(Button(key: const Key('d'), onPressed: () {}, child: const Text('d')))));
    await tester.pumpAndSettle();
    final ButtonStyle d =
        tester.widget<Button>(find.byKey(const Key('d'))).resolveOwn(tester.element(find.byKey(const Key('d'))));
    expect(d.backgroundColor, const Color(0xFF0000FF), reason: 'inner scope wins where both set the field');
    expect(d.minimumSize, const Size(77, 33), reason: 'outer scope survives where the inner one is silent');
  });

  testWidgets('map-form WidgetStateProperty becomes rules; the expansion helper rejects a closure', (WidgetTester tester) async {
    await tester.pumpWidget(inEnvironment(light, const SizedBox()));
    final BuildContext ctx = tester.element(find.byType(SizedBox));
    final Switch sw = Switch(
      value: true,
      onChanged: (bool _) {},
      mouseCursor: WidgetStateMouseCursor.fromMap(<WidgetStatesConstraint, MouseCursor>{
        WidgetState.disabled: SystemMouseCursors.forbidden,
        WidgetState.hovered: SystemMouseCursors.click,
        WidgetState.any: SystemMouseCursors.basic,
      }),
      rules: switchRulesFromWidgetStates(
        trackOutlineColor: WidgetStateProperty<Color?>.fromMap(<WidgetStatesConstraint, Color?>{
          WidgetState.selected & WidgetState.focused: const Color(0xFF00FF00),
          WidgetState.selected: const Color(0xFFFF0000),
        }),
      ),
    );
    expect(sw.resolveOwn(ctx, selected: true).mouseCursor, SystemMouseCursors.basic);
    expect(sw.resolveOwn(ctx, selected: true, hovered: true).mouseCursor, SystemMouseCursors.click);
    expect(sw.resolveOwn(ctx, selected: false, disabled: true).mouseCursor, SystemMouseCursors.forbidden);
    expect(sw.resolveOwn(ctx, selected: true).trackOutlineColor, const Color(0xFFFF0000));
    expect(sw.resolveOwn(ctx, selected: true, focused: true).trackOutlineColor, const Color(0xFF00FF00));
    expect(sw.resolveOwn(ctx, selected: false).trackOutlineColor, isNull, reason: 'null in the map = not set');

    // The helper expands by sampling, which a closure can't be: rejected.
    // The constructor parameters take closures as legacy rules instead
    // (test/callback_opaque_test.dart).
    expect(
        () => switchRulesFromWidgetStates(
            trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> _) => const Color(0xFF000000))),
        throwsArgumentError);
    expect(
        () => buttonRulesFromWidgetStates(
            mouseCursor: WidgetStateMouseCursor.resolveWith((Set<WidgetState> _) => MouseCursor.defer)),
        throwsArgumentError);
  });

  testWidgets('a rule referencing a token group the theme does not provide fails with the group name', (WidgetTester tester) async {
    await tester.pumpWidget(inEnvironment(light, const SizedBox()));
    final BuildContext ctx = tester.element(find.byType(SizedBox));
    final Button b = Button(
      onPressed: () {},
      rules: const <ButtonRule>[
        ButtonRule(ButtonWhen(), style: ButtonStyleSpec(backgroundColor: .fromCustomToken(Brand.accent))),
      ],
      child: const SizedBox(),
    );
    expect(() => b.resolveOwn(ctx), throwsA(isA<RuleError>()));
  });
}
