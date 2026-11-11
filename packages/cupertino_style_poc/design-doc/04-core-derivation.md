# 4. Design

[← Previous: 3. Goals and existing options](03-requirements-and-existing-options.md) | [Back to Roadmap](00-intro.md) | [Next: 5. Walkthrough →](05-walkthrough.md)

---

The root flaw of the existing model is forcing multi-dimensional states into a one-dimensional static property table. Designing from first principles starts from modeling a component's appearance as a two-dimensional table of `Condition (state / variant / environment) × Property`—each customization layer expresses only the sparse sub-table it cares about using pure-data syntax, and the engine stacks those sub-tables in order to resolve all non-null properties.

Turning this model into a complete API that satisfies all five design goals from Section 3.1 requires answering six connected questions:
1. **Property columns and null semantics (Step 1)**: How is a component's plain-value property set defined so `null` solely means "unset"?
2. **Slicing by column vs. by row (Step 2)**: Should multi-dimensional conditions hang inside each property, or wrap outside a property block?
3. **Conflict precedence and clobber protection (Step 3)**: When multiple tables stack, what rule decides the winner without complex specificity math while preventing broad conditions from accidentally clobbering fine-grained states like `disabled`?
4. **Closure-free dynamic derivations (Step 4)**: While preserving `const` and value equality, how are sibling-field references and global/custom tokens expressed?
5. **Partial patching of composite values (Step 5)**: How can a rule modify a single sub-property of `TextStyle`, `BorderSide`, or `EdgeInsets` without wiping out the remaining components?
6. **Theme containers and call-site ergonomics (Step 6)**: How are global and local rules organized on the widget tree while keeping everyday widget calls simple?

---

## Step 1: Values and `null`

### 1. Meaning of `null`

To resolve the six-way overloading of `null` from Section 2.2 and match Dart's default behavior for omitted optional named parameters, in style inputs, `null` solely means `unset` (unspecified at this rule; fall back to earlier rules or defaults). The other five meanings previously overloaded onto `null` are separated out:

- **Explicitly disabling a visual effect** → Use a real value that naturally represents "no effect" (such as `Colors.transparent`, `elevation: 0`, `BorderSide.none`, or `pressedOpacity: 1.0`). If a base type lacks such a natural value, define a `sealed class` with a `.none` branch or a dedicated boolean field—do not borrow `null` or magic sentinel numbers (like Compose's `Color.Unspecified` or negative float sentinels) that bypass compile-time type checking.
- **Keeping existing values in `copyWith` and `lerp` toward transparent black** → Do not run `copyWith` or `lerp` on partially populated objects containing `null`; instead, resolve the rule chain into a final snapshot where every field is non-null before consuming or interpolating.
- **Cross-field horizontal fallbacks and layout-time dynamic calculations** → Move into the explicit dynamic derivation mechanism in Step 4, rather than using `null` to trigger hidden branches inside `build()`.

### 2. `XStyle` and the full-coverage invariant

Once states and conditions are stripped away, a component's visual and layout properties form a plain flat data class `XStyle` (such as `ButtonStyle` or `SwitchStyle`; note that code examples use `cupertino_ui`'s `Button` by default, while `material_ui` uses names like `CommonButtonRule` to avoid colliding with the legacy `ButtonStyle` class).

- **All fields are nullable plain value types**: `backgroundColor` is `Color?`, `borderRadius` is `BorderRadius?`, with no `WidgetStateProperty` wrappers or closures inside (nor does this design hide component Style classes behind token-only APIs like Angular Material, preserving full control over multi-dimensional component variants).
- **Full-coverage invariant (reusing `XStyle` for resolved output)**: To avoid doubling the number of generated classes per component, the resolved output reuses the same `XStyle` type. The library's default rule table at the bottom of the fallback chain is required to cover every field across all reachable state combinations (enforced by static exhaustiveness checks in the code generator at compile and test time). Once resolution completes, every field on the returned `XStyle` instance holds a non-null value, so widget `build()` methods never need `??` fallback branches. Fields that can naturally have "no content" (such as `thumbIcon` or `thumbImage` on `Switch`) are no exception: following the rule above, those fields use a type with a `.none` value and the default rules set `.none` explicitly rather than leaving them null.

### 3. Boundary between constructor parameters and `XStyle`

Five categories of parameters stay on the Widget constructor and do not enter `XStyle`: (1) event callbacks (`onPressed`); (2) business data and controlled state (`value`, `selected`); (3) `Widget` child slots (`child`, `leading`, since `Widget` instances cannot support value equality or style interpolation); (4) controllers and focus nodes (`controller`, `focusNode`); and (5) semantics and tree identifiers (`semanticLabel`, `key`). All other purely visual and layout metric parameters belong in `XStyle`.

---

## Step 2: Conditions and rules

### 1. `XWhen`

Instead of the globally shared `WidgetState` enum, the code generator emits a dedicated strongly typed immutable condition class `XWhen` for each component (such as `ButtonWhen`, `SwitchWhen`), constraining at compile time the interaction states (e.g., `Switch` has `selected`, while `Button` does not), component variants (`appearance`, `size`), and environment dimensions (`brightness`, `highContrast`, `interfaceLevel`) valid for that component:

- **Binary dimensions** (`disabled`, `pressed`, `selected`, `highContrast`, `brightness`): Typed as nullable scalars `bool?` or `Brightness?` (a concrete value requires an exact match; `null` is a wildcard).
- **Multi-value enum dimensions** (`appearance`, `size`): Typed as `Set<E>?`, where multiple values inside the set represent OR (e.g., `appearance: {.plain, .tinted}`) and `null` is a wildcard.
- **Across different dimensions**: Combined with AND.

### 2. Conditions outside vs. properties outside

With the condition struct `XWhen` and property set `XStyle`, a sparse 2D table can be sliced in two isomorphic directions:
- **Direction A (slice by column: properties outside, conditions inside)**: `XStyle` sits on the outside, and each property field carries its own `XWhen -> T` branch list.
- **Direction B (slice by row: conditions outside, properties inside)**: Each configuration entry is written as a rule `XRule(XWhen, XStyle)` where the outer condition wraps a partial property set, and themes/widgets take a `List<XRule>`.

Direction A is direct when inspecting or tweaking a single property in isolation, but Direction B (`List<XRule>`) is chosen as the unified foundation for two reasons:

1. **Semantic conditions usually link multiple properties; Direction A fragments design intent and duplicates conditions**: Whether configuring interaction states (`disabled` or `selected` typically updates 2–4 properties like background, foreground, icon, and border together) or appearance/size variants (typically setting 5–8 color and geometry properties at once), a single condition corresponds to a coordinated group of properties, while geometric properties stay constant across most interaction states. Slicing by Direction A forces static properties into state containers and requires repeating the exact same `XWhen` condition under 3–8 separate fields, making it impossible to name or reuse a variant as a unit.
2. **Direction B absorbs Direction A's single-property ergonomics without loss, but not vice versa**: With `List<XRule>` as the foundation, multi-property conditions are written once on the outside. Meanwhile, for the single-property tweaks where Direction A shines, keeping flat parameters on widget constructors and generating per-property region constructors on `XRule` (such as `ButtonRule.backgroundColor(...)`, derived in Step 3) preserves property-first ergonomics and IDE autocomplete.

Using `.when` / `.always` named constructors on `XRule` together with Dart dot shorthands, a list of button rules reads:

```dart
...<ButtonRule>[
  .always(
    style: .values(borderRadius: .all(.circular(12))),
  ),
  .when(
    appearance: {.filled},
    disabled: false,
    style: .values(
      backgroundColor: CupertinoColors.activeBlue,
      foregroundColor: CupertinoColors.white,
    ),
  ),
  .when(
    pressed: true,
    brightness: .dark,
    style: .values(foregroundColor: Color(0xFFFFD60A)),
  ),
]
```

This is equivalent to writing out `ButtonRule(ButtonWhen(appearance: {ButtonAppearance.filled}, ...), style: ButtonStyle(...))`. Four design considerations shape this structure:

- **Per-component generated types without binary size bloat**: `XRule`, `XWhen`, and `XStyle` are thin data shells sharing a single generic resolution engine; combined with the decentralized theme architecture, unused component rule classes are tree-shaken by the compiler (see [Section 7.2](07-engineering-validation.md) for binary size measurements).
- **Prefix-free authoring designed around dot shorthands**: Declaring `...<ButtonRule>[...]` once on the outer list allows `.when(...)` inside to flatten `ButtonWhen` dimensions as named parameters and enum values as `{.filled}` or `.dark`. The `style:` parameter is written as `.values(...)` (rather than flattening style properties directly into `.when`) to form a symmetric pair with the dynamic derivation constructor `.derive(...)` introduced in Step 4—use `style: .values(...)` for plain literals, and switch to `style: .derive(...)` when referencing tokens or sibling fields. Note: this conciseness relies on the assumption that developers will use dot shorthands extensively to omit generated helper class names; potential risks around IDE autocomplete and internal style guides are assessed in [Section 9.2](09-topics-and-tradeoffs.md).
- **No closure DSLs (unlike Jetpack Compose `Styles API`)**: Dart lacks Kotlin's receiver lambda syntax, and closures or method chains cannot be compile-time `const`, which would prevent placing thousand-line default rule tables into read-only data segments or performing `O(1)` equality checks and cross-frame caching.
- **Explicit distinction between `.always` and `.when`**: There is no implicit conversion from a bare `XStyle` into an unconditional rule, because an unconditional rule overwrites all states including `disabled`. Requiring `.always` makes the scope of the rule explicit, leading into Step 3.

---

## Step 3: Ordering and rule regions

### 1. Order-only precedence

When a component receives rules from five layers—1. Library defaults → 2. Global `StyleTheme` → 3. Outer-to-inner `StyleScope`s → 4. Widget constructor flat parameters → 5. Widget constructor `rules:` parameter—the engine resolves values by one simple rule: concatenate all rules in that outer-to-inner, front-to-back order into a single chain; for each property field independently, the last rule matching the current state wins (last write wins).

```dart
// Global StyleTheme:
.when(appearance: {.filled}, disabled: false, style: .values(backgroundColor: brandBlue, borderRadius: .all(.circular(8))))
// Appended in a subtree StyleScope:
.when(appearance: {.filled}, disabled: false, style: .values(backgroundColor: warningRed))
// Result: backgroundColor takes the later warningRed, unmentioned borderRadius keeps 8, and the default grey background for disabled: true is untouched.
```

Pure order precedence is chosen over CSS-style specificity (weighting rules by how many dimensions they constrain) or fixed dimension tiers (`Forui` / `Mix`) for three reasons:
1. **Flutter has a deterministic ordering premise and does not need specificity tie-breaking**: CSS invented specificity because external stylesheet load order was unpredictable, at the cost of simple local overrides silently losing to multi-selector library rules (forcing modern CSS to add `:where()` to zero out specificity and `@layer` to restore order control). In Flutter, same-layer rules live in a single Dart list literal and cross-layer rules follow the outer-to-inner widget tree topology, with library defaults always at the head of the chain. Pure order guarantees that "closer to the widget and written later always wins," allowing a 1-dimension rule in an inner scope (like `disabled: false`) to override a 3-dimension rule in the default table.
2. **Avoids priority inversions from fixed dimension tiers**: As noted in Section 3.2, hard-coded tiers (`base < environment < interaction` or `platform < interaction < semantic`) force developers to memorize a hidden hierarchy and fail whenever a real requirement crosses tiers (such as tweaking hover in dark mode, or overriding `touch` interaction styling on `android`).
3. **Prefix cacheability**: Because priority depends solely on chain position, any prefix of the rule chain (such as "library defaults + global theme") can be pre-merged and cached per state combination, with inner scopes stacking on top (see [Section 7.1](07-engineering-validation.md)).

### 2. Rule regions

Pure order stacking has an obvious pitfall: a broad condition written later will clobber narrower state rules written earlier (for example, writing `.when(appearance: {.tinted}, style: .values(backgroundColor: mint))` in a theme without constraining `disabled` will also overwrite the `tinted` button's grey background when `disabled: true`; an audit of production `resolveWith` closures found over a dozen bugs caused by forgetting `disabled` or ordering `hovered` before `pressed`).

Requiring developers to read the component's default rule table and hand-craft mutually exclusive conditions every time they tweak a single property would set a high bar. A key observation resolves this: the way a component's default rule table partitions states for a given property reflects that property's core semantic boundaries in the design spec—which are the state combinations developers most commonly customize. Because the code generator has the complete default rule table at build time, it can statically traverse all reachable state combinations for each property and group "the set of states where the same default rule wins" into a Rule Region.

Consider Cupertino `Button.backgroundColor` and Material `CommonButton.elevation`. On a 2D truth table of `appearance × interaction state`, adjacent cells won by the same default rule merge into mutually exclusive, exhaustive regions:

```text
1. Cupertino Button.backgroundColor (enabled states do not distinguish pressed; first two columns merge → 5 regions)
              disabled: F        disabled: F        disabled: T
              pressed:  F        pressed:  T        pressed:  F
           ┌────────────────────────────────────────────────────────┐
  plain    │                    transparent                         │ ──► 1 region:  plainAnyState
           ├─────────────────────────────────────┬──────────────────┤
  tinted   │             tintedFill              │   tertiaryFill   │ ──► 2 regions: tintedEnabled / tintedDisabled
           ├─────────────────────────────────────┼──────────────────┤
  filled   │            primaryColor             │   tertiaryFill   │ ──► 2 regions: filledEnabled / filledDisabled
           └─────────────────────────────────────┴──────────────────┘

2. Material CommonButton.elevation (enabled states also split by hovered / pressed → produces an Idle region)
              disabled: F    disabled: F    disabled: F    disabled: T
                (idle)       hovered: T     pressed: T
           ┌──────────────┬──────────────┬──────────────┬──────────────┐
  elevated │     1.0      │     3.0      │     1.0      │     0.0      │ ──► 4 regions: elevatedIdle / Hovered / Pressed / Disabled
           ├──────────────┼──────────────┼──────────────┼──────────────┤
  filled   │     0.0      │     1.0      │  0.0 (same)  │     0.0      │ ──► 3 regions: filledIdle (incl. pressed) / Hovered / Disabled
           ├──────────────┴──────────────┴──────────────┴──────────────┤
  outlined │                            0.0                            │ ──► 1 region:  outlinedAnyState
           └───────────────────────────────────────────────────────────┘
```

Whenever a property has more than 1 region in the default table (static properties like `alignment` with only 1 unconstrained region across the entire table are skipped), the generator emits a same-named `const` region constructor on `XRule`, dropping irrelevant dimensions that were merged away and exposing readable named parameters:
- **Mutually exclusive and exhaustive, preventing accidental clobbering with no parameter-order sensitivity**: Regions tile the truth table without overlap. Passing only `tintedEnabled` does not touch `tintedDisabled`, and passing multiple regions in one call is order-independent.
- **Mixes directly into rule lists with self-documenting IDE autocomplete**: Typing `.backgroundColor(` surfaces all default state regions for that property in autocomplete, expanding under the hood into the equivalent `.when(...)` rules:

```dart
...<ButtonRule>[
  .always(style: .values(borderRadius: .all(.circular(12)))),
  // Only modify enabled backgrounds; omitted tintedDisabled / filledDisabled automatically keep default grey.
  // Equivalent under the hood to two .when(...) rules constraining appearance and disabled: false.
  .backgroundColor(
    tintedEnabled: CupertinoColors.systemMint,
    filledEnabled: CupertinoColors.systemIndigo,
  ),
]
```

### 3. Feasibility and boundaries

Generating public APIs from default rule partitions rests on two verified engineering premises (cross-version structural evolution, candidate API comparisons, and semantic boundaries are detailed in [Section 6.1](06-design-details-and-codegen.md)):
1. **Tweaking default color values does not break parameter names**: Regions are partitioned by which default rule wins (its `XWhen` structure), not by whether the resulting colors happen to be equal; routine adjustments to default colors or opacity numbers do not alter region parameter names.
2. **No combinatorial parameter explosion**: Running the partitioning algorithm across all 868 property keys of the 17 core component groups in `material_ui` shows that 774 properties (89%) have only 1 unconstrained region (no region constructor generated). Only 94 properties vary by state (490 regions total), averaging ~5 parameters per stateful property, with 99.6% of regions mapping to a single `XWhen` condition.

This establishes a clear division of labor: use `.when(...)` when multiple fields change together under one state (or when targeting custom conditions outside the default regions); use `XRule.<field>(...)` region constructors when tweaking a single field's literal value along default state boundaries.

---

## Step 4: Derivations and tokens

### 1. Semantics of derivation

Beyond static literals, component styles involve two core kinds of dynamic dependencies: sibling-field following (such as `iconColor` following the same button's `foregroundColor`) and global design token references (such as a background color reading `primaryColor`).

To eliminate the `build()`-time `??` fallbacks that short-circuit during `lerp` (Section 2.2) and the construction-time eager evaluation that fails to update when tokens change in a subtree (Section 2.3), derivations become first-class entries in the rule chain under a two-phase "compete in order first, evaluate at the end" model:
1. **Compete in the rule chain**: A derivation rule has the same status as a literal rule and participates in "last write wins." A later literal rule overrides and severs an earlier derivation; conversely, an inner derivation rule can override an earlier literal and re-establish dynamic following.
2. **Lazy evaluation after winning (with chaining and cycle detection)**: Once the rule chain merges, each property slot holds a single winning entry (either a literal or a symbolic derivation reference). In the second phase, the engine resolves winning derivation references by following the target field or global token chain (e.g., `A -> foregroundColor -> token primaryColor`), automatically detecting and rejecting cycles (such as `A <-> B`) at chain-build and evaluation time. Whichever layer modifies an upstream field or token, all downstream dependent properties recompute automatically.

### 2. `.derive` and `XStyleSpec`

Rules containing only literals use `style: .values(...)`; rules involving derivations switch to the symmetric `style: .derive(...)` (wrapping any mixed-in plain literals in `.value(...)`):

```dart
...<ButtonRule>[
  .when(
    appearance: {.filled},
    disabled: false,
    style: .derive(
      backgroundColor: .fromToken(.primaryColor),              // 1. Reference built-in global token
      foregroundColor: .fromToken(.primaryContrastingColor),
      focusColor: .fromField(.backgroundColor),                // 2. Follow another field on the same component
      borderRadius: .value(.all(.circular(12))),               // 3. Mix in a plain literal value
    ),
  ),
]
```

At the type level, the `style:` parameter of `ButtonRule.when` accepts the base class `ButtonStyleSpec`:
- **`ButtonStyleSpec.derive(...)`**: Each field parameter accepts a wrapper `ButtonSource<T>` (or subclass `ButtonColorSource` for color fields), providing `const` constructors `.fromToken(...)`, `.fromField(...)`, and `.value(...)`;
- **`ButtonStyleSpec.values(...)`**: A `const factory` redirecting to `ButtonStyle extends ButtonStyleSpec`, where every parameter accepts bare value types (`Color`, `double`), saving `.value(...)` wrappers when all fields are literals.

### 3. `.opacity` and `.opaque`

Scaling a source color's opacity is common in Material 3 and iOS HIG (such as disabled foreground taking `onSurface × 0.38` or hover overlay taking `primary × 0.08`), whereas non-color properties rarely need arithmetic transforms. Rather than inventing a general arithmetic DSL, `XColorSource` provides two built-in `const` opacity operators (using multiplicative alpha semantics to compose cleanly with translucent source colors; see [Section 6.2](06-design-details-and-codegen.md)):
- **`.opacity(source, factor)`**: Multiplies the alpha of the inner color source (`.fromToken`, `.fromField`, `.value`, or nested transform) by `factor` (e.g., `.opacity(.fromToken(.primaryColor), 0.15)`);
- **`.opaque(source)`**: Preserves RGB channels and forces alpha to `1.0`.

### 4. `.computed`

For the small fraction of calculations beyond built-in operators (such as computing a focus ring color from background HSL lightness, or converting a `double` radius token into a `BorderRadius`), `XSource<T>` provides `.computed(T Function(XView s) fn)`, where `XView` reads resolved sibling fields (`s.field(...)`), tokens (`s.token(...)`), and state dimensions (`s.brightness`) under the current state:

```dart
// Top-level function so its tear-off is a const expression (inline closures also work, but cannot be const or cached across frames)
Color _focusRingFromBg(ButtonView s) =>
    HSLColor.fromColor(s.field(.backgroundColor)).withLightness(0.8).toColor();

// Inside .derive(...):
focusColor: .computed(_focusRingFromBg),
```

Providing declarative `.fromField`, `.fromToken`, and `.opacity` alongside `.computed(fn)` serves two purposes: first, it lets the 95%+ of everyday derivations stay inline `const` expressions with value equality without forcing a choice between non-`const` inline closures and top-level helper functions; second, declarative combinators are inspectable data nodes, allowing `debugSources` to print full dependency chains without executing callbacks.

### 5. Custom `TokenGroup`

App design systems frequently need custom brand and semantic tokens beyond standard `ColorScheme` / `CupertinoToken` fields (such as `accent`, `success`, `textMuted`, `radius`). An audit of 91 `ThemeExtension` subclasses (1,149 fields) across 21 production projects revealed three pain points in legacy `ThemeExtension`: (1) adding a single field requires touching 4–6 places across field declarations, constructors, `copyWith`, and `lerp` (and 20% of classes had broken or stubbed `lerp` implementations); (2) component styles cannot declaratively reference extension fields, and precomputed opacity/alias fields inside an extension silently go stale after `copyWith`; and (3) `ThemeData.copyWith(extensions: ...)` replaces the extension map wholesale without per-field merging.

In the new model, a custom `TokenGroup` reuses the same ordered rule chain and consists of just one Token enum (serving as both identifier and read entry point) plus one write-side rule class. Neither `copyWith` nor `lerp` needs to be written by hand (99% of common types use the engine's built-in interpolation table, while custom composite types pass `lerp:` on the enum entry), and adding a new token field requires adding just 1 line in 3 places (the enum entry, the rule constructor parameter, and the `values` map):

```dart
// 1. Define Token enum and write-side rule class (groups with heavy cross-token derivations can extend TokenSourceRule instead; see Section 6.2)
enum MyBrand<T extends Object> with GroupTokenMixin<T> {
  accent<Color>(),
  success<Color>(),
  textPrimary<Color>(),
  textMuted<Color>(),
  radius<double>();

  const MyBrand({this.lerp});
  @override
  final T? Function(T? a, T? b, double t)? lerp;
  static const TokenGroup group = TokenGroup('MyBrand', values);
}

final class const MyBrandRule({
  super.when,
  final Color? accent,
  final Color? success,
  final Color? textPrimary,
  final Color? textMuted,
  final double? radius,
}) extends TokenValueRule {
  @override
  Map<Token<Object>, Object> get values => {
    MyBrand.accent: ?accent,
    MyBrand.success: ?success,
    MyBrand.textPrimary: ?textPrimary,
    MyBrand.textMuted: ?textMuted,
    MyBrand.radius: ?radius,
  };
}
```

Brightness and contrast branches stack in the same rule list via the global environment condition `TokenWhen`; component rules bind tokens declaratively via `.fromCustomToken(...)`; ordinary widgets read non-null values directly via `MyBrand.x.of(context)`; and local subtrees override individual fields via `StyleScope` with automatic downstream recomputation:

```dart
BorderRadius _brandRadius(ButtonView s) => BorderRadius.circular(s.customToken(MyBrand.radius));

// 1. Global configuration: environment branches, cross-token derivations, and component bindings in one rule list
StyleTheme(
  groups: [MyBrand.group],
  rules: [
    // Dynamic cross-token derivation: textMuted always follows the currently active textPrimary × 0.6
    MyBrand.textMuted.setFrom(.opacity(.fromCustomToken(MyBrand.textPrimary), 0.6)),
    const MyBrandRule(accent: teal700, success: green700, textPrimary: ink, radius: 12),
    // Dark mode rule specifies only what changes; radius: 12 and textMuted derivation carry over automatically
    const MyBrandRule(when: TokenWhen(brightness: .dark), accent: teal200, success: green300, textPrimary: paper),
    const ButtonRule.when(appearance: {.filled}, style: .derive(
      backgroundColor: .fromCustomToken(MyBrand.accent),
      borderRadius: .computed(_brandRadius),
    )),
  ],
  child: app,
);

// 2. Read non-null value directly inside an ordinary widget:
Text('Paid', style: TextStyle(color: MyBrand.success.of(context)));

// 3. Per-field incremental override in a local StyleScope (downstream button background and textMuted update automatically):
StyleScope(
  rules: const [MyBrandRule(accent: pumpkin, textPrimary: brown)],
  child: promoBanner,
);
```

> For the choice between `TokenValueRule` and `TokenSourceRule`, why whole-group data classes and `maybeOf` are omitted, and details of the built-in interpolation dispatch table, see [Section 6.2](06-design-details-and-codegen.md).

---

## Step 5: Composite values

Most Flutter value types (`Color`, `Size`, `BorderSide`, `EdgeInsets`) have non-nullable fields and default to atomic whole-value replacement. However, composite values regularly run into two practical needs:
1. **Partial patching of `BorderSide` and `EdgeInsets`**: For example, changing only an `OutlinedButton`'s border `color` when `focused` while keeping the base rule's `width: 1.5` (passing a native `BorderSide(color: brand)` resets `width` to its default `1.0`), or changing only `horizontal` on `EdgeInsets` while keeping `vertical`.
2. **Binding derivations to individual sub-properties of a composite value**: For example, setting base font size and weight on `textStyle` while making `textStyle.color` and `iconStyle.color` dynamically follow the button's `foregroundColor`.

To avoid intruding on `flutter/painting` with nullable mirror classes (like `BorderSideStyle`), native Flutter value types are kept unchanged. Instead, the wrapper slots of `style: .derive(...)` provide a projection patch constructor `.parts(...)`, dividing all property value types into three tiers:

1. **Mergeable (`TextStyle`, `IconStyle`, and nested child `XStyle`s)**:
   All fields on the value type itself are nullable (`null` carries over earlier rules, and `TextStyle(inherit: false)` is ignored during rule merging). When modifying literal sub-properties, pass a plain instance directly in `.values(textStyle: TextStyle(color: red))` to merge non-null fields automatically; when binding a derivation to a sub-property, use `.parts(...)` inside `.derive(...)`:
   ```dart
   style: .derive(
     iconStyle: .parts(color: .fromField(.foregroundColor)),
     textStyle: .parts(color: .fromField(.foregroundColor)),
   )
   ```
2. **Patchable (`BorderSide` and `EdgeInsets`)**:
   Fields on the value type are non-nullable, so passing an instance in `.values(...)` performs whole-value replacement; inside `.derive(...)`, dedicated source subclasses provide `.parts(...)` to patch only specified components (omitted components carry over from earlier rules, and sub-properties accept either `.value(...)` literals or derivations):
   ```dart
   // Only modify border color, preserving width from earlier rules:
   style: .derive(side: .parts(color: .fromToken(.primaryColor)))
   ```
   - `BorderSide` supports `.parts(color:, width:, style:, strokeAlign:)`;
   - `EdgeInsets` supports `.parts(left:, top:, right:, bottom:, horizontal:, vertical:)` (for the trade-off around whether the abstract base class `EdgeInsetsGeometry` should also be Patchable, see [Section 6.3](06-design-details-and-codegen.md)).
3. **Atomic (all other value types: `Color`, `double`, `AlignmentGeometry`, etc.)**:
   Whole-value replacement only. Upgrading any type from Atomic to Patchable in the future only requires swapping the slot's source subclass on `XStyleSpec`, without breaking code that uses dot shorthands.

**Rule idempotency axiom**: All partial merging and patching must be idempotent ($f(f(v)) = f(v)$). Any operation that reads the result of earlier rules on the same field is restricted to projection replacement (`.parts`); non-idempotent accumulators like `prev + delta` or `.inherited(fn)` are omitted to keep cross-frame caching and static checks deterministic (see [Section 6.3](06-design-details-and-codegen.md)).

---

## Step 6: Theme containers and call sites

### 1. `StyleTheme` and `StyleScope`

Instead of defining separate `XTheme` / `XThemeData` classes for every component, the widget tree uses two containers that accept a mixed `List<StyleRule>` (for the underlying `InheritedModel` per-channel notifications, cross-route local chain snapshot capture, and decentralized tree-shaking mechanics, see [Sections 7.1–7.3](07-engineering-validation.md)):

- **`StyleTheme` (global root container)**: Mounted above `Navigator` by `CupertinoApp` / `MaterialApp`. It loads the library's built-in base token defaults, registers custom app `TokenGroup`s (`groups: [...]`), holds global rules, and drives interpolation transitions when switching global themes.
- **`StyleScope` (local incremental container)**: Mounted on any subtree to incrementally append component rules, token overrides, or local environment overrides (`environment:`) on top of its parent's rule chain. When a subtree pushes a dialog route via `Navigator.push`, `InheritedTheme.capture` snapshots and replays only the accumulated local `StyleScope` chain onto the new route, while the root `StyleTheme` continues to be read live from the tree root—preventing nested local themes from clobbering outer local properties ([#196177](https://github.com/flutter/flutter/issues/196177)) while allowing open dialogs to respond live to global dark-mode switches ([#106642](https://github.com/flutter/flutter/issues/106642)).

### 2. Sub-parts of composite widgets

Rather than introducing CSS descendant selectors, sub-parts of composite widgets (`AlertDialog`, `DatePicker`) are handled in two ways:
1. **Internal private visual parts** (such as a `Switch` thumb or `DatePicker` year cell): Defined directly as prefixed fields (`thumbColor`, `yearCellBackgroundColor`) on the parent component's `XStyle`.
2. **Semantic slots reusing public widgets** (such as confirm and cancel buttons inside `DatePicker`): Declared on `DatePickerStyle` as `confirmButton: List<ButtonRule>?`. When building that button, the parent wraps it in a local `StyleScope(rules: resolvedStyle.confirmButton)`, scoping the rules to that slot without affecting other buttons inside the dialog body.

### 3. Call sites

1. **Curated flat parameters + `rules:` local rules**: Widget constructors do not take a full `XStyle` object. Component maintainers hand-pick common properties to expose as plain-value flat constructor parameters (such as `color` and `disabledColor` on `Button`)—matching the familiar design of existing Flutter widgets, but grounded in the Rule Regions partitioned from the default rule table by the code generator. Inside the component, flat parameters map to rules via the corresponding region constructors (so `color` maps to the enabled region and does not clobber `disabled`) and sit ahead of the instance `rules:` parameter. Everyday calls pass flat parameters directly; per-instance state tweaks append `rules:`.
2. **Automatic expansion of `CupertinoDynamicColor` (CDC) at chain build time in `cupertino_ui`**: In `cupertino_ui`, to keep dark-mode adaptation effortless, any `Color` parameter or slot accepts a `CDC` directly (such as `CupertinoColors.systemRed`). Because a `CDC` is a `const` pure-data object holding 8 fixed environment slots, the engine automatically expands it during chain flattening into environment-conditioned plain `Color` rules (intersected with any outer `XWhen` environment constraint). The evaluation engine and widget `build()` methods only ever see resolved plain `Color` instances, eliminating forgotten `resolve` bugs (note: to adjust opacity on a dynamic color, use `.opacity(.value(cdc), 0.5)` rather than calling `.withValues` outside the widget).
3. **Retiring `WidgetStateProperty` (WSP) on new parameters while preserving legacy APIs in place**: New components and new parameters use plain value types paired with `rules:` (gaining `const` caching, single-condition authoring, and compile-time state checking, at the trade-off of not sharing a single `WSP` variable across unrelated component types). Existing `WSP` parameters and `ThemeData` fields in `material_ui` are preserved in place and bridged into rules automatically; see [Section 8.2](08-migration-plan.md).

---

[← Previous: 3. Goals and existing options](03-requirements-and-existing-options.md) | [Back to Roadmap](00-intro.md) | [Next: 5. Walkthrough →](05-walkthrough.md)
