# 6. Technical details

[← Previous: 5. Walkthrough](05-walkthrough.md) | [Back to Roadmap](00-intro.md) | [Next: 7. Engineering validation →](07-engineering-validation.md)

---

Section 4 derived the public API from a user perspective. Aimed at framework implementers and component maintainers, this section specifies five internal mechanisms following the order of Section 4: the Rule Regions partitioning algorithm and slot-expansion implementation (6.1), internal derivation and token types plus three special component patterns (6.2), composite partial-override contracts (6.3), the code generation architecture and multi-widget shared rules (6.4), and the boundary between styling and animation plus environment interpolation (6.5). For comparisons of rejected alternatives and empirical survey data across 21 projects, see [Appendix (Section 10)](10-appendix.md).

---

## 6.1 Rule regions

### 1. Partitioning and naming

When deriving each field's "Rule Regions" (the set of all reachable states won by the same default rule on that field) from a component's default rule table and generating named parameters, the code generator follows four rules:

1. **Split by individual `appearance` only when the partitioning structure differs across appearances**:
   If a field has different state partitions across appearances (for example, `CommonButton.backgroundColor` splits into enabled and disabled regions under `elevated`/`filled`/`tonal`, but has a single all-state transparent region under `outlined`/`text`), the generator splits by individual appearance first, emitting `elevatedEnabled`, `outlinedAnyState`, etc., and does not concatenate multiple appearances into compound names like `elevatedOutlinedTextEnabled`. Conversely, if a field has the same partition structure across all appearances (such as `foregroundColor`, which has one enabled region and one disabled region across all five button appearances), the parent rule class omits the appearance prefix and emits `CommonButtonRule.foregroundColor(enabled:, disabled:)` (if a future spec update causes one appearance to diverge, the old parameter name can be kept as `@Deprecated` and expanded into the newly split regions automatically).
2. **Merge environment dimensions on Cupertino `Color` fields**:
   In `cupertino_ui`, the 8 environment sub-rules expanded from a single default rule's `CupertinoDynamicColor` are treated as a single region, so parameter names do not append `Light` / `Dark` suffixes—callers pass a dynamic color directly to a single region parameter (e.g., `filledEnabled: CupertinoColors.systemOrange`) to cover all 8 environment slots at once (if `material_ui` needs a similar shorthand in the future, a declarative constructor like `.byBrightness(light:, dark:)` on source slots is preferable to a `Color` subclass so it cannot silently degrade when methods are called outside a widget).
3. **Simplify impossible state combinations as Don't-Cares**:
   Mutually exclusive combinations such as `disabled: true` with `pressed: true` (or `hovered: true`) are eliminated as Don't-Care terms during Boolean simplification.
4. **Deterministic parameter naming formula**:
   Parameter names concatenate `[appearance prefix] + [positive interaction state | idle | enabled | anyState] + [semantic state suffix]`. Here, `enabled` means not disabled regardless of interaction state; `idle` means not disabled while excluding interaction states that have dedicated rules on that field (for example, once `elevation` defines dedicated rules for `hovered` and `pressed`, the remaining enabled states are named `idle`); negative semantic suffixes (like `Unselected`) are spelled out only when the same field also has a positive partition (`Selected`).

Across the 17 core component groups in Material 3 (868 property keys) and the Cupertino prototype, 89% of properties (774) have only 1 unconstrained region (skipped by the generator). The remaining 94 stateful properties produce 490 regions total (averaging 5.2 regions per property), with an average parameter name length of 11 characters (1–2 words on standard components).

### 2. Slot expansion

To avoid generating separate expansion code for every region constructor and inflating binary size, region constructors use branchless fixed-slot table expansion:
- Every region constructor is `const`, storing user-supplied arguments into fixed slots (`_r0`, `_r1`, ..., sized to the maximum region count on that component—at most 16 in M3E) and pointing to a private `const` region condition table and target field index in the generated file;
- At chain build time, all components share a single generic loop in the engine that iterates over non-null slots and expands them into rules.
- **Measured binary size**: Across AOT (arm64 release), Web (dart2js -O2), and Wasm (dart2wasm -O2), unused region constructors and their private tables are 100% tree-shaken (0 bytes). Referencing all 490 regions across all 94 stateful M3 fields adds only ~10 KB in AOT (~21 bytes per region, compared to ~90 KB if each field generated its own expansion function).

### 3. Boundaries

1. **Accept concrete literals (including `CDC`) only, not derivations** (use `.when(..., style: .derive(...))` for derivations).
2. **Reflect only the library's compile-time default rule table, unaware of custom state subdivisions added by outer app themes**: For instance, if a field does not distinguish `pressed` in the library defaults (its default region is a broad `enabled`), and an outer `StyleTheme` adds a custom `.when(pressed: true, ...)` rule on that field, calling `XRule.<field>(enabled: blue)` in an inner `StyleScope` will overwrite the outer `pressed` rule by order. To preserve custom outer state subdivisions, inner scopes should use explicit `.when` rules. (For detailed comparisons of candidate API shapes and rule organization styles, see [Appendices A.1 and A.2](10-appendix.md).)

---

## 6.2 Derivations and tokens

### 1. Source classes

The generator emits source classes independently per component (such as `ButtonSource<T>` and `SwitchSource<T>`, extending the shared engine base class `DeriveSource`) rather than sharing a single global `Source<T>`, for two reasons: first, `.fromField(ButtonField<T>)` must bind its parameter type to that component's generic field enum `XField<T>` so the compiler can resolve dot shorthands like `.fromField(.foregroundColor)` and reject cross-component field mix-ups at compile time; second, the callback view `XView` in `.computed(T Function(ButtonView))` must expose that component's fields and state dimensions (`appearance`, `pressed`).

- **General fields (`XSource<T>`)**: Provide five constructors: `.value(T)`, `.fromField(XField<T>)`, `.fromToken(CupertinoToken<T>)`, `.fromCustomToken(Token<T>)`, and `.computed(T Function(XView))`.
- **Color fields (`XColorSource extends XSource<Color>`)**: Re-declare the five base constructors plus two `const` opacity operators:
  1. **`.opacity(XColorSource source, double opacity)`**: Uses multiplicative alpha semantics (`clamp(source.a * opacity, 0.0, 1.0)`) rather than replacing alpha. When an upstream color is already translucent (e.g., an 80% opaque brand color), `.opacity(..., 0.5)` scales it proportionally to 40% rather than forcing 50% (matching SwiftUI `Color.opacity` and CSS `opacity`; note that when migrating `material_ui`, if legacy code set `onSurface` to a translucent color, stacking `.opacity(..., 0.38)` for disabled states changes from alpha replacement to multiplication, which will be noted in the migration guide).
  2. **`.opaque(XColorSource source)`**: Preserves RGB channels and forces alpha to `1.0`.

### 2. Tokens

1. **Built-in token facade (preventing exhaustive enum breakage) and `.fromToken` vs. `.fromCustomToken`**:
   In Dart, adding a value to a public `enum` is a breaking change for downstream exhaustive `switch` statements. Built-in library tokens are therefore exposed as `static const` constants on `abstract interface class CupertinoToken<T extends Object> implements Token<T>` (backed by a package-private enum). `.fromToken` types its parameter as `CupertinoToken<T>` so built-in tokens support dot shorthands (`.fromToken(.primaryColor)`), whereas custom app token enums implement `Token<T>` and pass their qualified enum name via `.fromCustomToken(MyBrand.accent)`.
2. **Full environment set on `TokenWhen` vs. component subsets on `XWhen`**:
   Each widget package defines its full set of built-in environment dimensions as `TokenWhen` (such as `brightness`, `highContrast`, and Cupertino's `interfaceLevel`), while each component's `XWhen` includes only the subset of environment dimensions actually distinguished in that component's default rule table. Custom app-level conditions beyond built-in dimensions (such as a third eye-care theme mode or screen breakpoints) are handled by switching the rule list passed to `StyleTheme` / `StyleScope` rather than adding custom dimensions to the engine.
3. **Dual write-side base classes (`TokenValueRule` vs. `TokenSourceRule`) and instance method `.set`**:
   - Custom token groups consisting mostly of literals extend `TokenValueRule` (nullable plain parameters `Color?`, overriding `get values`, paired with `MyBrand.x.setFrom(...)` for occasional derivations); groups with heavy cross-token derivations (or generated built-in `CupertinoTokenRule`) extend `TokenSourceRule` (parameters typed `TokenColorSource?` / `TokenSource<T>?`, overriding `get sources`).
   - Single-token assignment is an instance method `MyBrand.accent.set(T value)` on `Token<T>` rather than a static generic function `TokenRule.value<T>(Token<T>, T)`—because Dart generic covariance would allow `TokenRule.value(MyBrand.accent, 3)` to infer `T` as `Object` and compile without error, whereas an instance method locks `T` to `Color` on the receiver. Although `.set` is a method call and not `const`, `TokenRule` implements value-based `==` and `hashCode` so inline usage does not trigger spurious `InheritedModel` rebuilds.
4. **Built-in interpolation dispatch table and `lerpObject` contravariance wrapper**:
   The engine includes a type-dispatched interpolation table covering `Color`, `double`, `TextStyle`, `EdgeInsetsGeometry`, `BorderRadiusGeometry`, `ShapeBorder`, `BorderSide`, `BoxShadow`, and other standard types (covering 99% of interpolable extension fields found in production; non-interpolable types flip at `t = 0.5`; custom composite classes pass `lerp: MyType.lerp` on the enum entry). Because `T` appears in contravariant parameter positions in `T? Function(T?, T?, double)?`, `GroupTokenMixin` provides `lerpObject(Object? a, Object? b, double t)` to invoke the callback inside the token's own concrete `T` scope without triggering Dart runtime type-erasure cast errors. (For empirical data on why whole-group data classes like `MyBrandData` and `maybeOf` are omitted, see [Appendix A.3](10-appendix.md).)

### 3. Special component patterns

1. **Accessible text-scaled padding (`padding` + `paddingScaler` dual-field pattern)**:
   Under Material 3 accessibility guidelines, when system text scales up (`TextScaler` > 1.0), horizontal padding on buttons and chips scales down piecewise linearly (halved at 2x text scale, quartered at 3x). Legacy implementations tied this logic to `padding == null`, silently breaking accessibility scaling whenever a user passed a custom `padding` (and a `ScaledPadding extends EdgeInsets` subclass would lose its scaling strategy on arithmetic ops or left-hand `==` comparisons). This is split into two orthogonal fields:
   - **`padding: EdgeInsetsGeometry?`**: Base padding at `1.0` text scale;
   - **`paddingScaler: PaddingScaler?`**: Pure-data scaling strategy providing `const PaddingScaler.identity()` (no scaling) and `const PaddingScaler.stops([(1, 1), (2, 0.5), (3, 0.25)])` (piecewise linear scaling; uses a list of records rather than a `Map` because `double` cannot be a `const Map` key).
   During layout, the widget calls `resolved.paddingScaler!.apply(resolved.padding!, textScaler, fontSize)`. (Because resolved output reuses `XStyle`, field types remain nullable and read sites use `!`, which the full-coverage invariant guarantees cannot fail; whether to also generate a non-nullable resolved view type is left out of scope for now.) Overriding `padding` in the new API preserves the default `paddingScaler`; meanwhile, the legacy bridge for `ButtonStyle(padding: ...)` (Section 8.2) emits `paddingScaler: .identity()` whenever a non-null legacy `padding` is provided to preserve existing behavior.
2. **Virtual Fields (internal pattern for sharing values across states)**:
   `.fromField` and `.computed` only read sibling fields resolved under the same state combination (cross-state reads are forbidden so state evaluations remain independent and cache complexity stays linear). For rare spec requirements that share a color across states—such as legacy `CupertinoSwitch` using the selected (`selected: true`) track color for its focus ring even when unselected (`selected: false`)—the component declares a non-painted field `accentColor` (unpartitioned by `selected`, acting as a component-local token) and has both `trackColor` (when `selected: true`) and `focusColor` (when `focused: true`) derive from `.fromField(.accentColor)`.
3. **`extension type` view and re-entrancy detection for `.computed` callbacks**:
   Thanks to the full-coverage invariant, `s.field(.x)`, `s.token(.x)`, and `s.customToken(x)` on a `.computed` view all return non-null `T` directly; if a callback reads back the field currently being evaluated along a dependency chain, the evaluation stack catches the re-entrancy at runtime and throws a `RuleError` with the cycle trace. The callback view `XView` is generated as a per-component `extension type` exposing a single generic method `s.field(.x)` rather than per-field getters (cutting AOT binary size growth by ~70% in a synthetic stress test of 75 components × 40 fields; base engine overhead when `.computed` is unused is ~3.5 KB).

---

## 6.3 Partial overrides

Around the three-tier value model (Mergeable / Patchable / Atomic) from Section 4 Step 5, the engine enforces two contracts (see [Appendix A.4](10-appendix.md) for why nullable mirror classes and `.inherited()` were rejected):

1. **Mergeable types (`TextStyle`, `IconStyle`, nested `XStyle`) cannot reset an already-set sub-property back to `null`, and ignore `TextStyle(inherit: false)`**:
   In a rule chain, `null` solely means "carry over earlier rules." For `TextStyle`, the engine ignores `inherit: false` during rule merging (always merging non-null sub-properties, with a debug diagnostic hint if `inherit: false` is passed) and sets `inherit: false` on the final resolved `TextStyle` output (preventing accidental pollution from outer `DefaultTextStyle`s and avoiding `TextStyle.lerp` exceptions when `inherit` flags differ).
2. **Patchable types (`BorderSide`, `EdgeInsets`) reconstruct the base class via public getters**:
   When executing `.parts(...)`, the engine reads public getters from the earlier value, replaces the specified components, and reconstructs the declared base type (custom subclass identity is not preserved). For the abstract base class `EdgeInsetsGeometry` widely used in `material_ui`, keeping zero framework changes (Option A) limits `.parts` to concrete `EdgeInsets`, whereas adding a static projection helper in `flutter/painting` (Option B) enables direction-agnostic `.parts(top:, bottom:, vertical:, horizontal:)` on `EdgeInsetsGeometry` (see [Appendix A.4](10-appendix.md)).

---

## 6.4 Code generation

### 1. Single source of truth

A component maintainer authors a single definition file declaring: (1) the component's field list and types; (2) the component's condition dimension enums and boolean states; and (3) the component's default rule table.

After running static exhaustiveness checks and region simplification, the generator emits three artifacts checked directly into the repository (downstream app developers never run any codegen tools):
1. **`XStyleSpec` and `XStyle`**: Including sub-property merging and `lerp`;
2. **`XField`, `XSource` / `XColorSource`, and callback view `XView`**: Providing type-safe field enums and derivation entry points;
3. **`XWhen` and `XRule`**: Including `.when`, `.always`, `.whenAny`, and region constructors for all multi-region fields.

> Note: Flat parameters on Widget constructors are not auto-generated; maintainers curate common regions to expose as constructor parameters and map them to generated region constructors inside the widget. The generator checks for intra-package name collisions so generated `<Component>Style` classes do not collide with existing `painting` / `widgets` classes like `TextStyle`.

### 2. Multiple widgets sharing rules

In `cupertino_ui`, button appearances live on a single `Button(appearance: ...)` widget. In `material_ui`, however, `ElevatedButton`, `FilledButton`, `OutlinedButton`, and `TextButton` are four separate Widget classes spanning five appearances (including `FilledButton.tonal`). While keeping those Widget classes unchanged, they share a single underlying rule set parameterized by `appearance`: `CommonButtonStyle`, `CommonButtonRule`, and `CommonButtonWhen`.

To preserve API discoverability and ensure class names match their actual scope (which a `typedef` cannot do), the generator emits scoped rule subclasses for each appearance: `ElevatedButtonRule`, `FilledButtonRule`, `FilledTonalButtonRule`, `OutlinedButtonRule`, and `TextButtonRule` (each containing only forwarding constructors, costing 61–80 bytes in AOT when referenced and 0 bytes when tree-shaken):

1. **Chain-build condition intersection (`_scope`)**: The parent `CommonButtonRule` holds a private nullable field `final CommonButtonAppearance? _scope` (`null` on parent constructors; set via `super._scoped(CommonButtonAppearance.outlined, ...)` on subclasses). During chain flattening, if `_scope` is non-null, the engine intersects every condition on the rule with `appearance: {outlined}` (unconstrained conditions gain that appearance; sets containing it narrow to just that appearance; disjoint conditions are dropped, asserting in Debug if all conditions become empty).
2. **Subclass constructors and unprefixed region parameters**:
   - `.when(...)` omits the `appearance` parameter (passing `appearance` is a compile-time error), and `.always(...)` applies only to that appearance;
   - **Region constructors expose only the regions for that single appearance, with appearance prefixes stripped from parameter names**: for example, `CommonButtonRule.side(outlinedIdle:, outlinedFocused:, outlinedDisabled:)` becomes `OutlinedButtonRule.side(idle:, focused:, disabled:)`.
3. **Narrowed instance `rules:` parameter type**: `OutlinedButton(rules:)` accepts `List<OutlinedButtonRule>`, preventing rules for other appearances from being passed to an `OutlinedButton` instance at compile time.

In themes, use `CommonButtonRule` to style all five buttons at once, `.when(appearance: {...})` to target a subset of appearances, and a scoped subclass like `OutlinedButtonRule` to target a single button type:

```dart
StyleTheme(
  rules: [
    ...<CommonButtonRule>[
      // (1) Unconstrained appearance: applies to all five button types
      .always(style: .values(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
      // (2) Target two appearances at once via an appearance set
      .when(appearance: {.outlined, .text}, disabled: false, style: .values(foregroundColor: brand)),
    ],
    ...<OutlinedButtonRule>[
      // (3) Applies only to OutlinedButton; region parameters drop the outlined prefix, and omitted disabled keeps its default
      .side(idle: BorderSide(color: brand), focused: BorderSide(color: brandStrong)),
      .foregroundColor(enabled: brand),
    ],
  ],
  child: ...,
)
```

---

## 6.5 Animation

### 1. Double interpolation

In existing `material_ui`, widgets like `ButtonStyleButton`, `Card`, and `Chip` wrap their contents in `AnimatedDefaultTextStyle` or `AnimatedPhysicalModel`. When a top-level `AnimatedTheme` interpolates `ThemeData` every frame, the widget detects incoming property changes and kicks off its own implicit animation to chase the already-interpolating intermediate values—distorting easing curves and waking up redundant `AnimationController` tickers across the tree.

To prevent this, widgets only run micro-interaction animations for interaction state changes (`pressed`, `hovered`, `selected`) and do not run implicit transition animations in response to external style property changes; theme and environment transition interpolation is handled by the theme layer (legacy `ButtonStyle.animationDuration` is removed from `XStyle`, while `splashFactory` is retained).

### 2. Environment transition interpolation

When switching between light and dark mode, the `brightness` dimension itself changes from `light` to `dark`. Flipping the discrete `brightness` enum at the animation midpoint (`t = 0.5`) would cause colors defined under `brightness: .dark` (or expanded from a `CupertinoDynamicColor`) to jump at `t = 0.5`. Environment transition animations ($0 < t < 1$) therefore handle two cases in tandem:

1. **Component properties derived purely from global tokens (symbolic cache fast path)**:
   If a component's rule chain contains no environment-conditioned branches, its stage-1 symbolic style is identical at both endpoints. During the transition, the theme interpolates between `Tokens_from` and `Tokens_to` token by token, and the component hits `SymbolicCache` directly while binding the current frame's interpolated tokens.
2. **Component rule chains containing direct environment branches (endpoint `BoundCache` snapshots + `XStyle.lerp`)**:
   For components whose channel contains environment-conditioned rules, the resolver evaluates two endpoint snapshots for the current interaction state—`XStyle_from` at $(E_{\text{from}}, \text{Tokens}_{\text{from}})$ and `XStyle_to` at $(E_{\text{to}}, \text{Tokens}_{\text{to}})$ (because both endpoints remain fixed throughout the 60-frame transition, they are resolved only on frame 1 and hit their respective `BoundCache`s on frames 2–60)—and then interpolates field by field via the generated `XStyle.lerp(styleFrom, styleTo, t)`.
   Unlike legacy `ButtonStyle.lerp`, which interpolated partially populated objects containing `null` before rule resolution and `build()` fallbacks (causing `null` to interpolate toward transparent black and breaking `iconColor ?? foregroundColor`), both `styleFrom` and `styleTo` are fully resolved snapshots satisfying the full-coverage invariant (all fields non-null), eliminating fallback short-circuiting and midpoint jumps.

---

[← Previous: 5. Walkthrough](05-walkthrough.md) | [Back to Roadmap](00-intro.md) | [Next: 7. Engineering validation →](07-engineering-validation.md)
