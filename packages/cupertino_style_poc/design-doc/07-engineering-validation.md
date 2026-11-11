# 7. Engineering validation

[← Previous: 6. Technical details](06-design-details-and-codegen.md) | [Back to Roadmap](00-intro.md) | [Next: 8. Migration →](08-migration-plan.md)

---

Drawing on measurements from the rule engine prototype and the Cupertino widget prototype, this section covers per-channel notifications and two-stage cache performance (7.1), architectural constraints for tree-shaking (7.2), interoperability with existing framework primitives and cross-route capture (7.3), `debugSources` provenance (7.4), three-tier diagnostic checks (7.5), and the unit-testing API (7.6).

---

## 7.1 Notifications and caching

### 1. Per-channel notifications

`StyleTheme` and `StyleScope` are built on Flutter's `InheritedModel`, with each component channel mapped to an independent aspect (plus one global token aspect):
- **Per-channel subscriptions**: In `build()`, a widget subscribes only to its own channel (e.g., `Button` subscribes only to the button channel). When a `StyleScope` updates a `ButtonRule`, `InheritedModel.updateShouldNotifyDependent` compares the persistent linked-list node (`ChannelLink`) per channel: only `Button` widgets subscribed to the button channel rebuild, while `Switch` and `Slider` widgets in the same subtree rebuild 0 times.
- **Persistent singly linked lists and `O(1)` empty-node skipping**: Each `StyleScope` maintains a per-channel persistent linked list pointing to the parent's `ChannelLink`; if a scope does not modify a given component channel, it reuses the parent's `ChannelLink` pointer directly, skipping empty scopes in `O(1)`. Resolution scans from inner to outer ("last write wins" becomes "first encountered wins"), terminating early as soon as all fields are determined.
- **No cross-channel reverse dependency graph on global token changes**: When the global token channel changes (such as a brightness switch or `AnimatedTheme` interpolation), the engine notifies all component channels to refresh. Because nearly every standard component references global base tokens (`primary`, `onSurface`, typography), tracking fine-grained cross-channel reverse dependencies adds everyday bookkeeping overhead without meaningfully reducing rebuilds during global theme transitions; the key to 60fps theme animation performance is avoiding re-matching and re-merging each component's rule chain on every interpolated frame.

### 2. Two-stage caching

Because default rule tables and theme rules use `const` declarative symbolic references (`.fromToken` / `.fromField`), evaluation splits into two stages backed by two cache levels:
1. **Stage 1: Symbolic resolution and `SymbolicCache` (attached to the component channel's `ChannelLink`)**
   Given the current state combination, the engine scans the rule chain, performs condition matching, order-based overriding, composite sub-property merging, and intra-component `.fromField` resolution, producing a Symbolic Style whose global token references remain unbound. This result is cached per state combination on `ChannelLink`, shared across all instances of that component under the same scope, and is independent of concrete global token values.
2. **Stage 2: Token binding and `BoundCache` (attached to the theme/scope node owning `Tokens`)**
   The symbolic style's `.fromToken(...)` references are bound to the concrete `Tokens` values of the current node (applying `.opacity` transforms) to produce the final `XStyle`, which is likewise cached per state combination on the `Tokens`-owning node. Whenever multiple buttons in the same subtree share the same state (such as 30 `idle` buttons on a page), only the first button performs token binding on a given frame; the remaining 29 hit `BoundCache` in `O(1)`.

### 3. 60-frame theme animation benchmark

In the pure-Dart rule engine prototype, a 60-frame `ColorScheme.lerp(light, dark, t)` animation benchmark was run with 17 core `material_ui` component groups × 50 instances each (850 widget instances total, spanning 63 active state combinations) (`flutter test` JIT mode with assertions enabled, median of 5 warmed-up runs; AOT/Profile widget-tree frame benchmarks pending):
- **Baseline (rebuilding default rules with interpolated colors every frame)**: Allocates 294 rule objects and re-runs 63 full rule-chain scans and merges per frame, taking 607µs/frame.
- **This proposal (`const` symbolic rules + `SymbolicCache` + `BoundCache`)**: Stage-1 `SymbolicCache` misses only on frame 1 (63 misses, 719µs on frame 1) and achieves a 100% symbolic cache hit rate on frames 2–60; subsequent frames perform token binding once for each of the 63 active states, reducing steady-state time to 197–205µs/frame (~1/3 of the rule-rebuilding baseline; when half the instances sit inside a local `StyleScope` overriding a token, steady-state time is ~390µs/frame).
- **Cache parity**: Across 118,683 field comparisons over all reachable states, 6 color schemes, and intermediate interpolation frames on the 17 component groups, two-stage cached outputs matched uncached evaluation 100% (0 diffs).

---

## 7.2 Tree-shaking

To avoid repeating legacy `ThemeData`'s static coupling to all 50+ component theme classes (which prevents tree-shaking and costs ~200 KB even in a minimal app), the architecture enforces two hard constraints:
1. **No centralized default rule registry**: Each component's default rule table (such as `Button._defaultRules`) is defined as a static constant inside the component Widget class itself and passed to the resolver only when that component's `build` (or `resolveStyle`) is called.
2. **No central dispatch `switch` table listing all components**: `StyleTheme` and `StyleScope` accept an abstract `List<StyleRule>`, and each rule registers itself into its channel via the virtual method `rule.addTo(channels)`, leaving the core engine agnostic to concrete component classes.

A component's style and rule classes enter the compiler's reachability graph only when app code instantiates that widget or explicitly writes its `XRule` (a CI tree-shake binary size benchmark will be added as additional components land).

---

## 7.3 Interoperability with the existing framework

1. **State collection and downstream propagation**: Widgets continue using `WidgetStatesController` to collect interaction states, combining them with environment dimensions from `MediaQuery` / `StyleTheme`; resolved `textStyle` and `iconStyle` values continue to be passed down to `child` subtrees via standard `DefaultTextStyle.merge` and `IconTheme.merge`.
2. **Overlays and cross-route local rule capture**:
   - **`OverlayPortal` overlays** (`Tooltip`, `MenuAnchor`): Remain children of the call site in the Element tree, inheriting and reacting live to the call site's `StyleScope` chain.
   - **`Navigator.push` dialog routes** (`showDialog`, `showCupertinoDialog`): The internal `InheritedModel` implements `InheritedTheme`. When `InheritedTheme.capture` runs, only the accumulated outer-to-inner local `StyleScope` chain at the call site is snapshotted and replayed onto the new route, while the root `StyleTheme` (mounted above `Navigator`) is excluded from the snapshot—fixing both the loss of outer local theme properties when multiple local themes are nested ([#196177](https://github.com/flutter/flutter/issues/196177)) and the bug where freezing the entire `ThemeData` snapshot prevents open dialogs from reacting live to global dark-mode switches ([#106642](https://github.com/flutter/flutter/issues/106642)). Missing `capture` calls in `DialogWindow` and `showCupertinoDialog` will be filled in alongside this change.

---

## 7.4 Debug provenance

Because rules, conditions, and derivations are inspectable pure data, the engine provides `StyleResolver.debugSources(node, callSite, minterm)`, which outputs per-field provenance showing the winning layer, rule index, dynamic-color environment slot, and derivation chain for any component node and state. Because that method takes engine-internal types, the code generator also emits a public entry point on each component symmetric with `X.resolveStyle` (7.6): `X.debugSources(BuildContext context, {state parameters..., rules})`, which reads the active theme/scope chain from `context`, assembles the state combination, and delegates to the engine (this wrapper is pending verification in the prototype). Illustrative output:

```text
Button, ButtonWhen(appearance: {tinted}, disabled: false, pressed: true), brightness dark:
  backgroundColor  <- defaults rule #3 [appearance: {tinted}, disabled: false]
                      token tintedFill
  foregroundColor  <- scope #1 rule #0 [pressed: true]
                      systemYellow, dark normal-contrast slot
  iconStyle.color  <- defaults rule #5 [disabled: false]
                      parts(color: field .foregroundColor)
  focusColor       <- defaults rule #6, computed rule
  borderRadius     <- call site, flat parameter borderRadius
```

> Known limitations: Derived tokens (such as `tintedFill`) currently stop at the token name (a recursive lookup across the token channel can be added later); reads inside `.computed` function bodies report `computed rule`.

---

## 7.5 Diagnostic checks

Safeguards operate across three levels (all runtime diagnostics are wrapped in `assert` with zero Release overhead):
1. **Compile-time type checking**: Type mismatches, misspelled dimension or region names, and calling `.opacity` on non-color fields fail at compile time.
2. **Chain-build fail-fast checks (throwing `RuleError` with full paths in Debug)**: Catches field/token derivation cycles (printing `A -> B -> A`), derived-dimension cycles (e.g., modifying `thumbIcon` under a `hasThumbIcon: true` condition), unregistered or uninitialized custom `TokenGroup`s, and `CupertinoDynamicColor` instances nested inside unknown custom containers that cannot be expanded.
3. **Library test-time exhaustiveness and zero-shadowing gate (CI Gate)**: Automatically scans default rule tables to verify that all fields are non-null across every reachable state combination and that no default rule is completely shadowed by subsequent default rules (0 shadowed rules across all 258 default rules of the 17 M3 component groups).

---

## 7.6 Testing

Every generated component provides a static `X.resolveStyle(BuildContext context, ...)` method (as well as a `BuildContext`-free pure-data entry point `StyleResolver.resolve` that takes a rule list directly). Tests can assert resolved styles under any target state and environment combination directly, without simulating gestures or pumping animation frames:

```dart
final ButtonStyle pressedDarkStyle = Button.resolveStyle(
  context,
  appearance: ButtonAppearance.filled,
  pressed: true,
  brightness: Brightness.dark,
);
expect(pressedDarkStyle.foregroundColor, const Color(0xFFFFD60A));
expect(pressedDarkStyle.iconStyle.color, const Color(0xFFFFD60A));
```

---

[← Previous: 6. Technical details](06-design-details-and-codegen.md) | [Back to Roadmap](00-intro.md) | [Next: 8. Migration →](08-migration-plan.md)
