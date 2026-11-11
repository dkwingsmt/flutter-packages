# 3. Goals and existing options

[← Previous: 2. Problems](02-problems.md) | [Back to Roadmap](00-intro.md) | [Next: 4. Design →](04-core-derivation.md)

---

To address the three structural problems analyzed in Section 2, this section establishes five design goals for the new model and uses them as a yardstick to evaluate existing improvements in the Dart ecosystem (`WidgetStateProperty.fromMap`) and mature community libraries (`Mix`, `Forui`)—setting aside third-party dependency governance for a moment to see why a new underlying architecture is needed.

## 3.1 Goals

1. **Compile-time `const` support and structural value equality (`==`)**: Component default styles, global themes, and local overrides must all be declarable as compile-time constants (with no runtime closure allocations), supporting `O(1)` identity fast paths and structural value equality so style objects do not evaluate `==` to `false` unnecessarily or trigger spurious subtree rebuilds and theme interpolation animations.
2. **Eliminate nested wrapper coloring, masquerading degradation, and `null` ambiguity; support unified multi-dimensional composition and type constraints**: `null` must solely mean "unset." Component-specific variants and states (appearance, size, tristate, etc.), common interaction states, and environment dimensions (brightness, contrast, interface level) must compose and resolve in a single pass within the same mechanism—without nested wrapper types (like `WSP<CDC>`) or `implements Color` masquerading interfaces—while providing compile-time type constraints for the dimensions valid on each component.
3. **Four-layer incremental merging, avoiding multi-property condition duplication, and deterministic precedence**: Component defaults, global themes, local scopes, and call-site parameters must share a single incremental merging mechanism that allows grouping linked properties under one condition without repeating that condition per property. While keeping everyday static parameter passing simple, tweaking a single property or state in a local scope must not wipe out outer configurations or clobber unmentioned states (such as changing an enabled state and accidentally overwriting `disabled`), with uniform, intuitive precedence rules across layers and states.
4. **Explicit, lazily evaluated cross-field and cross-token derivations**: Sibling-field relationships (such as `iconColor` following `foregroundColor`), token references, and dynamic calculations (such as text-scaled padding) must neither be hidden inside `??` branches in `build()` nor baked into static values when constructing theme objects. Modifying a source field or token in a subtree must automatically recompute downstream properties, preserve fallback semantics during theme interpolation animations, and allow developers to retain or customize dynamic calculation strategies when overriding properties.
5. **Per-component fine-grained subscriptions and on-demand tree-shaking**: At the scale of dozens of components, hundreds of properties, and a dozen state dimensions, updating one component's theme at runtime must not rebuild unrelated components, and transition animations must avoid redundant rule-chain resolution. At compile time, centralized static references to all component themes must be eliminated so unused component styles are completely tree-shaken by the compiler.

## 3.2 Existing options

### Path A: Patching the existing model

Fixing `XTheme.of(context)` to merge layer by layer can stop local themes from wiping out outer configurations, but promoting `WSP.fromMap` across the board still cannot overcome the underlying limits from Section 2:
- **No unified all-dimension composition or per-component type constraints (fails Goals 2 & 3)**: `fromMap` keys are locked to the global `WidgetStatesConstraint`, which cannot hold component-specific dimensions (appearance, size, tristate) or environment dimensions; state tables still hang off individual properties, leaving multi-property condition duplication and `CDC` masquerading degradation untouched.
- **Cannot express lazy derivations (fails Goal 4)**: `fromMap` can only store precomputed static values, forcing cross-field and token derivations back into `resolveWith` closures (breaking `const` and `==` in Goal 1) or hidden `??` branches in `build()`.

### Path B: Mix

`Mix` provides atomic primitive builders (`BoxStyler`, `TextStyler`) and chained variant modifiers (`.onHovered(...)`, `.onDark(...)`). It works well for assembling custom UI from basic primitives, but conflicts with first-party component library goals in three ways:
- **Exposes atomic implementation details rather than component-level semantic properties**: A first-party widget's internal node tree and `CustomPaint` structure are private implementation details (rewritten completely when upgrading to Liquid Glass, for example). Public APIs must expose stable component-level semantic properties (like `trackColor`, `thumbColor`), not internal `BoxStyler` containers.
- **Method chains cannot be `const`, and tokens rely on masquerading types (fails Goals 1 & 2)**: Chained calls (`BoxStyler().color(...).onHovered(...)`) cannot be compile-time `const` in Dart. Meanwhile, `ColorRef implements Color` (throwing via `noSuchMethod` if accessed outside a widget) and negative-hash `double` sentinels (producing negative dimensions if multiplied) remain type-erasing masquerades.
- **Fixed dimension tiers and compound-fragment matching increase override friction (fails Goal 3)**: `Mix` hard-codes variant precedence into `base < environment < interaction`, which can cause unexpected priority inversions when real requirements cross tiers; meanwhile, `Remix` merges default styles by compound state fragments (such as `onSelected & onDisabled`), requiring callers to know and write the exact same compound condition to replace a branch.

### Path C: Forui

`Forui` uses "one strongly typed Style class per component + code generation" and solves compile-time type constraints for component-specific interaction states via its generic `FVariants<K, E, V, D>` container, but still falls short in three areas:
- **Eager evaluation at construction time, lacking lazy derivations and sibling-field following (fails Goal 4)**: Default styles are populated via `FButtonStyle.inherit(colors: ...)` when constructing `FThemeData`, baking tokens directly into static `Color` fields. Replacing color tokens in a subtree does not update already-constructed component styles, while re-running `.inherit()` wipes out outer component customizations. Nor is there symbolic sibling-field following—changing a button's text foreground color requires manually updating its icon color too.
- **Dimension tiers + specificity sorting restrict reverse overrides (fails Goal 3)**: `Forui` ranks variants by `platform < interaction < semantic` and then by operand count and lexicographical order. Developers must memorize specificity rules, and when a lower-tier dimension (like `android`) needs to override a higher-tier dimension (like `touch`), it must be written as the compound condition `touch & android` to gain enough weight.
- **Per-property wrapping, split appearance/environment dimensions, and a centralized `FThemeData` (fails Goals 2, 3, & 5)**: `FVariants` still wraps individual properties one by one, repeating conditions when multiple properties change together; button appearances (split into separate `FButtonStyles` fields) and brightness are not unified inside `FVariants`; and the top-level `FThemeData` statically holds and initializes all 50 component styles, preventing per-component subscriptions and tree-shaking.

In short, Paths A and C remain in per-property vertical wrappers + eager static evaluation / monolithic theme objects, while Path B is constrained by non-`const` method chains and masquerading sentinel types. None can satisfy all five design goals in Section 3.1. Section 4 derives the core design of the new model in six steps starting from these five goals.

---

[← Previous: 2. Problems](02-problems.md) | [Back to Roadmap](00-intro.md) | [Next: 4. Design →](04-core-derivation.md)
