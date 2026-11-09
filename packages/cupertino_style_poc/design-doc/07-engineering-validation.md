# 7. Engineering Validation: Performance, Binary Size, Observability, and Testing

[← Previous: 6. Detailed Mechanics and Code Generation](06-design-details-and-codegen.md) | [Back to Index](00-intro.md) | [Next: 8. Migration and Evolution Plan →](08-migration-plan.md)

---

Drawing on benchmark data from the rule-engine prototype and the Cupertino component prototype, this section covers our two-stage caching mechanism and theme animation performance, architectural constraints for tree-shaking, integration with existing framework primitives, provenance debugging (`debugSources`), and unit-testing APIs.

---

## 7.1 Two-Stage Caching (`SymbolicCache` + `BoundCache`) and Theme Animation Performance

### Invalidation Trade-off: No Cross-Channel Fine-Grained Dependency Graph on Global Token Updates

When the global token channel changes (such as switching between light and dark themes, or updating interpolated tokens every frame during an `AnimatedTheme` transition), the engine notifies all component style channels in the tree to refresh **without maintaining a runtime cross-channel fine-grained reverse dependency graph of which component field references which specific token**.

Almost every design-system component references global `primary`, `onSurface`, or base typography tokens. Maintaining a fine-grained reverse dependency graph across channels would add bookkeeping overhead to everyday resolution while saving almost no rebuilds during global light/dark switches where nearly every widget repaints anyway. What actually determines theme animation performance is **avoiding re-matching and re-merging each component's rule chain on every frame of a 60fps animation as new interpolated tokens arrive**.

### Two-Stage Evaluation and Dual-Layer Caching

Because Step 4 of Section 4 designs default rule tables and theme rules as **`const` declarative symbolic references (`.fromToken` / `.fromField`)**, the rule chain itself holds no concrete token values. Evaluation splits into two stages, each backed by its own cache layer:

1. **Stage 1: Symbolic Resolution and `SymbolicCache` (attached to the component channel's `ChannelLink` node)**
   Given a component's current state combination (such as `appearance: filled, disabled: false, pressed: true, brightness: dark`), the engine scans the rule chain from inside out, performing condition matching, sequential overrides, sub-property merging for composite types, and component-internal `.fromField` reference resolution to produce a **symbolic style** that has not yet bound concrete global token values.
   This result is cached by state combination on the component channel node (`ChannelLink`) of the current `StyleScope` / `StyleTheme`, shared across all instances of that component in the same scope, and **completely independent of concrete global token values**.
2. **Stage 2: Token Binding and `BoundCache` (attached to the theme/scope node holding `Tokens`)**
   Taking the symbolic style from Stage 1, the engine binds its `.fromToken(...)` symbolic references to the concrete `Tokens` values on the current node (and executes numeric transforms such as `.opacity`) to produce the final `XStyle`.
   Benchmarks showed that repeating Stage 2 token binding locally on every component instance costs more than rebuilding rules when hundreds of instances of the same component appear on screen. Therefore, **the final token-bound `XStyle` from Stage 2 is also cached by state combination on the theme node holding `Tokens` (`BoundCache`)**. Whenever multiple buttons under the same subtree share a state combination (for example, 30 buttons sitting in the default `idle` state on a page), only the first button performs token binding on each frame, while the remaining 29 hit `BoundCache` in `O(1)` time.

### 60fps Theme Interpolation Animation Benchmark

We built a 60fps theme animation benchmark in the pure-Dart rule-engine prototype, mounting **17 core `material_ui` component groups × 50 instances per group (850 component instances in total, spanning 63 distinct active state combinations)** and simulating a 60-frame `ColorScheme.lerp(light, dark, t)` animation.

We compared two implementation paths on the same rule engine (`flutter test` JIT mode with `assert`s enabled, taking the median of 5 runs after warm-up):
- **Path B (Baseline: rebuilding default rules with newly interpolated colors every frame)**: Allocates 294 new rule objects and re-runs 63 full rule-chain scans and merges on every frame, taking **607µs** per frame.
- **Path A (Proposed: `const` symbolic rules + `SymbolicCache` + theme-level `BoundCache`)**: Across the 60-frame animation, Stage 1 `SymbolicCache` incurs 63 misses on Frame 1 only (first-frame time: 719µs) and achieves a **100% symbolic cache hit rate (0 misses) from Frame 2 through Frame 60**. Subsequent frames only perform token binding once for each of the 63 active state combinations, dropping steady-state per-frame time to **197–205µs**—roughly **one-third** the time of rebuilding rules.
- **Local scope benchmark (Path AS)**: Placing half of the instances (425 widgets) inside a local `StyleScope` subtree that overrides the `onSurface` token similarly misses the symbolic cache only on Frame 1, with subsequent frames taking ~**390µs** in total.
- **Cache consistency verification**: Across all reachable state combinations of the 17 component groups, 6 color schemes, and multiple intermediate interpolation frames, we performed **118,683** field-by-field comparisons: the output of two-stage caching matched full from-scratch evaluation with 0 diffs.

Note: These numbers come from JIT-mode tests on the pure-Dart rule-engine prototype to measure relative cost between the two architectural paths; they do not yet include AOT/Profile-mode frame times on a full widget tree.

---

## 7.2 Architectural Constraint: No Central Registry Referencing All Components (Guaranteeing Tree-Shaking)

Every component generates `XStyle`, `XStyleSpec`, `XRule`, `XWhen`, `XSource`, and a default rule table. When a simple app only uses `Button` and `Switch`, the compiler must be able to tree-shake the styling code for the other 70+ unused components completely.

`ThemeData` in `material_ui` today is a textbook cautionary tale: because `ThemeData` **statically references the `XThemeData` classes of all 50+ components** in its field declarations, constructor, `==`, `hashCode`, and `lerp`, merely instantiating `MaterialApp` (which constructs a default `ThemeData` internally) forces the Dart AOT compiler to retain every component's theme class along with its `lerp` and `copyWith` code (~200 KB in a minimal counter app).

To prevent this, the new model enforces a strict architectural constraint: **nothing in the theme and style infrastructure may centrally reference all component types**:
- **No centralized default-rule registry**: There is no global map or initialization function that collects default rules across all components. Each component's default rule table (such as `Button._defaultRules`) is defined strictly as a static constant inside the `Button` widget class itself, and only passed to the resolver when `Button.build` (or `Button.resolveStyle`) is called.
- **No central dispatch `switch` enumerating all components**: As described in Section 4, Step 5, `StyleTheme` and `StyleScope` accept an abstract `List<StyleRule>`, and each concrete component rule registers itself into its own channel via the virtual method `rule.addTo(channels)`. The core engine has no knowledge of which concrete component classes exist.

Under this constraint, a component's default rule table, style class, and rule class enter the compiler's reachability graph only when app code imports and instantiates that component (such as `Slider`) or explicitly writes a `SliderRule`. Because the current prototype only includes 2 components, full multi-component tree-shaking will be verified during the multi-component rollout via a CI binary-size benchmark (Tree-Shake Benchmark) that compiles a minimal app referencing only `Button` and asserts that its AOT binary size stays constant as additional components are added to the package.

---

## 7.3 Integration with Existing `flutter/framework` Rendering Primitives

The new styling system is solely responsible for resolving a flat `XStyle` for the current state from the rule chain; inside each component, integration with existing `flutter/framework` rendering primitives stays unchanged:
- **State collection**: Components continue using `WidgetStatesController` (or their own internal state fields) to track interaction states like `hovered`, `pressed`, and `focused`, combining them with environment dimensions from `MediaQuery` / `StyleTheme` into a query condition passed to the resolver.
- **Downstream propagation**: Once the final `XStyle` is resolved, its `textStyle` and `iconStyle` continue propagating to the `child` subtree via standard `DefaultTextStyle.merge` and `IconTheme.merge` widgets, so ordinary `Text` and `Icon` widgets inside a button or list item automatically inherit the resolved font and color.

---

## 7.4 Observability and Provenance Debugging (`debugSources`)

Debugging component styling issues in the legacy system is notoriously frustrating: `WidgetStateProperty.resolveWith` is an opaque black-box closure that shows up in the debugger only as `Closure: (Set<WidgetState>) => Color?`, giving you no way to see which condition matched, which theme layer provided the value, or which `??` fallback inside `build()` took effect.

Because rules, conditions, and derivations in the new model are pure data, the engine provides the **`StyleResolver.debugSources(node, callSite, minterm)`** diagnostic API. Given any component node and target state, it prints the winning layer, rule index, and derivation chain for every field (illustrative output format shown below):

```text
Button, ButtonWhen(appearance: {tinted}, disabled: false, pressed: true), brightness dark:
  backgroundColor  <- defaults rule #3 [appearance: {tinted}, disabled: false]
                      token tintedFill
  foregroundColor  <- scope #1 rule #0 [pressed: true]
                      systemYellow, dark normal-contrast slot
  iconTheme.color  <- defaults rule #5 [disabled: false]
                      parts(color: field .foregroundColor)
  focusColor       <- defaults rule #6, computed rule
  borderRadius     <- call site, flat parameter borderRadius
```

The output shows which layer (`defaults`, `theme`, `scope #n`, or `call site`) and rule index won for each field; sub-rules expanded from `CupertinoDynamicColor` identify the matched environment slot (such as `dark normal-contrast slot`); and derived properties print their upstream source and transformation steps (`field`, `token`, `custom token`, `computed`, `opacity`, `opaque`, `parts`).

There are currently two known limitations: first, provenance for derived tokens (such as `tintedFill`) stops at the token name without recursively printing its upstream tokens (we can add a recursive lookup across the token channel in `debugSources` later without affecting runtime logic); second, reads inside a `.computed` callback live inside a function body and can only be reported as `computed rule`.

---

## 7.5 Static Safeguards and Runtime Diagnostics (Debug vs. Release)

Safeguards operate across four levels, and all runtime diagnostics are wrapped in `assert`s so Release builds incur zero overhead:

1. **Compile-time type checking**: Passing the wrong value type, misspelling a dimension or region parameter name, or calling `.opacity` on a non-color field is caught directly by the Dart compiler.
2. **Fail-fast checks when building the rule chain (throwing `RuleError` with full paths in Debug mode)**:
   - **Circular field or token derivations**: For example, if field A derives `.fromField(.B)` while field B derives `.fromField(.A)`, the engine throws an error when building the chain or on first evaluation and prints the cycle `A -> B -> A`.
   - **Derived-dimension cycles**: For example, if a `Switch` rule constrains `hasThumbIcon: true` and simultaneously mutates the source field `thumbIcon`, the engine catches it when building the rule chain.
   - **Unregistered or uninitialized custom `TokenGroup`s**: If a component rule or app code reads `MyBrand.accent` when the outer `StyleTheme` either forgot to register `MyBrand.group` or left that token unset, reading it throws a `RuleError` naming the missing group or token (tests can also call `debugMissingTokenDefaults` to batch-check all registered tokens for missing values).
   - **Unexpanded `CupertinoDynamicColor` nested inside an unknown container**: If a dynamic color is placed inside a custom container unknown to the engine and cannot be expanded during chain construction, a static expandability check reports the exact field path in Debug mode so unresolved dynamic colors never leak into painting.
3. **Exhaustiveness and zero-shadowing checks during component-library tests (CI Gate)**:
   The code generator's companion test harness automatically scans every component's default rule table to verify that (1) every field resolves to a non-null value across all reachable state combinations, and (2) **no field in any default rule is completely overwritten across all reachable states by later default rules (Shadowed Rule Check)**. Across all 258 default rules for the 17 M3 component groups, the number of shadowed rules is 0.
4. **Static analysis warnings for app themes**:
   When an app developer writes an unconstrained `.always(style: .values(backgroundColor: red))` in `StyleTheme` on a state-varying property like `backgroundColor`, the analyzer helper `checkStateVaryingFields` warns that an unconditional rule will clobber dedicated states like `disabled` and suggests using the `ButtonRule.backgroundColor(...)` region constructor or specifying an explicit condition.

---

## 7.6 Unit Testing and External Resolution API (`X.resolveStyle`)

In the legacy system, some unit tests assert colors by reading `widget.backgroundColor` directly. In the new model, property getters on the widget only return the raw flat parameters passed at the call site; when styles come from `StyleTheme`, `StyleScope`, `states:` rule chains, or cross-field derivations, callers query the resolution API to obtain the final resolved values.

Every generated component provides a static **`X.resolveStyle(BuildContext context, ...)`** method (such as `Button.resolveStyle(context, appearance: .filled, pressed: true)`). Tests and external callers can not only retrieve the complete non-null `ButtonStyle` for the current state, but also pass **any target state combination directly**—asserting resolved styles under specific interaction states and environment settings without simulating gesture presses or pumping animation frames in the test:

```dart
final ButtonStyle pressedDarkStyle = Button.resolveStyle(
  context,
  appearance: ButtonAppearance.filled,
  pressed: true,
  brightness: Brightness.dark,
);
expect(pressedDarkStyle.foregroundColor, const Color(0xFFFFD60A));
expect(pressedDarkStyle.iconColor, const Color(0xFFFFD60A));
```

Furthermore, our audit of a large internal codebase found 34 files (27 of them test files) that call `.style?.X?.resolve(states)` directly, including theme unit tests that never `pump` a widget tree at all and instead run pure-Dart assertions against a theme configuration. Because our rule engine runs independently of the widget tree (as demonstrated by `StyleResolver.resolve` in the prototype), generated components can also expose a pure-data resolution entry point that takes a rule list (such as a theme rule set) and a target state combination without requiring a `BuildContext`, allowing widget-free theme unit tests to call it directly.

---

[← Previous: 6. Detailed Mechanics and Code Generation](06-design-details-and-codegen.md) | [Back to Index](00-intro.md) | [Next: 8. Migration and Evolution Plan →](08-migration-plan.md)
