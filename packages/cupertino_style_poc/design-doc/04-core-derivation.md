# 4. Core Design Derivation

[← Previous: 3. Design Goals and Evaluation of Existing Options](03-requirements-and-existing-options.md) | [Back to Index](00-intro.md) | [Next: 5. End-to-End Code Walkthrough →](05-walkthrough.md)

---

Since existing mechanisms and third-party community libraries cannot be reused directly, a styling and theming system must be designed from scratch. To satisfy all five design goals from Section 3.1 simultaneously, any styling system must answer six interlocking foundational questions in sequence:

1. **How are style values themselves stored?**: How should a component's pure visual and layout properties be represented to eliminate wrapper-type contagion and the multiple semantic ambiguities of `null`?
2. **Where do multi-dimensional conditions attach?**: When properties need to vary across interactive states, component variants, and environmental dimensions, should conditions be attached inside each individual property or wrapped around a style block on the outside?
3. **Which rule wins when multiple rules conflict?**: When default styles, global themes, and local overrides stack together, what precedence rule resolves conflicts without introducing complex specificity calculations or fixed dimension tiers, while also preventing simple local edits from accidentally clobbering special default states (such as `disabled`)?
4. **How are dynamic derivations expressed without closures?**: Given that style objects must support `const` and value equality, how are cross-field relationships (such as `iconColor` tracking `foregroundColor`), references to global tokens, and color transformations declared?
5. **How are partial overrides expressed on composite values?**: Beyond whole-field overrides, how are value types that contain multiple sub-properties—such as `TextStyle`, `BorderSide`, and `EdgeInsets`—partially merged or patched?
6. **How are styles distributed and consumed across the widget tree?**: How should global themes, local scopes, and widget constructor parameters be organized to achieve on-demand tree-shaking, fine-grained updates, and ergonomic everyday call sites without introducing a centralized `ThemeData` monolith?

Below, the design choices for these six questions are derived step by step.

---

## Step 1: Decoupling Values from Conditions — Single `null` Semantics and Flat `XStyle`

### 1. First, Normalize Null Semantics: `null` Exclusively Means `unset`

Before designing the style data structures, the "six-fold semantic overloading of `null`" identified in Section 2.2 must be resolved first.

In theme customization and style overrides, the most fundamental and frequent requirement is **partial override and vertical fallback**: a developer specifies only the one or two properties they want to change at a theme or widget call site, while all unmentioned properties automatically fall back to the outer theme or component defaults. In Dart, the default value for an omitted optional named parameter is `null`. Therefore, to stay consistent with language idioms and avoid default-argument conflicts, the most reasonable rule is to let **`null` in style inputs retain only its first meaning: `unset` (this property is not specified here; fall back to earlier rules or defaults)**.

Once `null` is strictly restricted to `unset`, the remaining five meanings overloaded onto `null` in Section 2.2 must be stripped away from `null`:

- **"Explicitly disable a visual effect" (original meaning 2) → Use a concrete value that naturally equates to "no effect", or define an explicit union type**: Many types already have concrete values that participate directly in normal painting and interpolation without any special `if` interception while expressing "no effect"—for example, passing `Colors.transparent` for background color (full transparency naturally shows no color), `elevation: 0` for shadow height (zero elevation naturally casts no shadow), `BorderSide.none` for no border (a zero-width transparent border), or `pressedOpacity: 1.0` for no opacity change on press (an opacity of 1.0 naturally does not fade, fixing the legacy `CupertinoButton` bug where using `pressedOpacity: null` to disable the effect made it impossible to fall back to the default value). If a property's underlying primitive type lacks a concrete value that naturally expresses "off", a dedicated union type (such as a `sealed class` with a `.none` variant) or a separate boolean toggle field is defined when designing that property, never borrowing `null` or magic numbers as an "off" sentinel.
- **"`copyWith` retains the original value" and "`lerp` interpolates toward transparent black" (original meanings 5 and 6) → Naturally eliminated through incremental merging and fully non-null resolved outputs**: Once mutating half-baked objects via `copyWith` and running `lerp` directly on unresolved objects containing `null` are eliminated—resolving styles instead into a final snapshot where **every field is non-null** before consuming or interpolating them—both of these `null` ambiguities disappear naturally.
- **"Trigger horizontal cross-field fallback" and "trigger layout-time dynamic computation" (original meanings 3 and 4) → Subsumed into the declarative derivation mechanism, deferred to Step 4**: Whether `iconColor` tracks `foregroundColor` or padding scales dynamically with text scale factor, both are fundamentally cases where "one property's value is dynamically derived from other properties or the environment." At this stage, the exact syntax for derivations has not yet been decided, but the analysis in Sections 2 and 3 already established that dynamic derivation is a hard requirement for first-party component libraries, and neither the existing framework nor community libraries (`Mix`, `Forui`) handle it cleanly. Because a dedicated derivation mechanism will be designed in Step 4, overloading `null` as a secret signal to trigger black-box derivation inside `build()` is no longer needed, and this can safely be set aside until Step 4.

### 2. Extract a Flat Style Container `XStyle` and the Full-Coverage Invariant

Having clarified what happens to `null`, the next step is to define a component's style property container and guarantee that resolved outputs are fully non-null.

In the existing system, aside from buttons (`ButtonStyle`) and menus (`MenuStyle`), most components do not have a standalone style class; they only have an `XThemeData` attached to the theme, whose fields mix plain types (`Color?`) with state wrappers (`WidgetStateProperty<Color?>?`). Temporarily setting aside how properties vary with interactive states or the environment and simply answering **"what visual and layout properties does a component have at a single, specific moment?"**, the cleanest model is to extract a pure, flat data class **`XStyle`** for each component (such as `ButtonStyle` or `SwitchStyle`). Because any partial override or state-specific default rule only specifies a subset of fields while leaving the rest `unset`, every field on `XStyle` is a nullable plain value type: `backgroundColor` is `Color?`, `borderRadius` is `double?`, and `padding` is `EdgeInsetsGeometry?`, with no `WidgetStateProperty` or closures inside.

At the same time, to avoid doubling the number of generated classes per component, a separate `ResolvedXStyle` class with non-nullable fields is not generated for the resolved output; instead, the same `XStyle` type is reused to represent the final resolved result. This raises a critical question: **since all fields on `XStyle` are nullable in Dart's type system, how does a component's internal `build()` method guarantee it will never encounter `null` when reading a field?**

To guarantee this, **the component library's default style table at the very bottom of the fallback chain is required to completely cover every field across all reachable state combinations** (global tokens likewise have default values in every environment). Following the direction established in Sections 1.2 and 2—extending the `gen_defaults` approach and expanding code generation coverage—component authors maintain a single declarative definition. Beyond generating the component's `XStyle` (complete with `==`, `hashCode`, and `lerp`) alongside its companion rule and condition classes, the code generator performs static exhaustiveness checks on the default style table at compile and test time. This mechanism enforces the **full-coverage invariant**: once style merging and resolution finish, every field on the returned `XStyle` instance is guaranteed to hold a concrete non-null value, and the component's `build()` method never needs to write `??` fallback branches for undefined values.

> Note: Code examples in this chapter primarily use the new `Button` from `cupertino_ui`, whose generated class names are `ButtonStyle`, `ButtonRule`, and `ButtonWhen`. To avoid colliding with the legacy `ButtonStyle` class name, Material buttons use names like `CommonButtonRule`, covered in Section 5 (Scenario 5), Section 6, and Section 8.

Isolating `XStyle` as a pure value container brings two immediate benefits:
- First, **the component's style contract is immediately clear**: both component maintainers and users can read the field list of `XStyle` to see exactly which visual and layout customizations the component supports, without agonizing over whether a property might vary by state in the future, and without twin parameters caused by wrapper-type contagion.
- Second, **it naturally leads to lifting state conditions outside of `XStyle`**: restoring `XStyle` fields to plain value types strips the state resolvers (`WSP` / `CDC`) out of individual properties and moves them outside `XStyle`. Because a component often has a dozen or even dozens of style properties, lifting state conditions from "inside every property" to "outside `XStyle`" intuitively avoids wrapping state containers repeatedly across dozens of fields. Step 2 right below evaluates whether flipping from "properties wrapping states" to "conditions wrapping styles" is truly necessary and superior.

### 3. The Boundary Between Widget Constructor Parameters and `XStyle` Fields

Not every parameter on a widget constructor belongs in `XStyle`. Five categories of parameters remain on the widget constructor and **do not enter** `XStyle`:
1. Event callbacks (such as `onPressed`, `onChanged`);
2. Business data and controlled state values (such as `value`, `selected`, `groupValue`);
3. Structural child widget slots (such as `child`, `leading`, `trailing`—`XStyle` fields can only hold value-comparable pure data like `IconData`, never `Widget` instances, which cannot support structural equality or interpolation);
4. Controllers and focus nodes (such as `controller`, `focusNode`);
5. Semantic labels and tree identifiers (such as `semanticLabel`, `key`, `autofocus`).

All pure visual and layout metric parameters outside those five categories go into `XStyle`.

### 4. Tradeoff Comparisons with Other Frameworks at This Stage

- **Why not expose only design tokens and omit component `XStyle` classes, like Angular Material or Material Web?**
  On the web, Angular Material and Material Web restrict customization entry points by hiding component-level style classes from developers, allowing overrides only on global or local design tokens (CSS variables). However, pure tokens can only express atomic constants like colors and font sizes; they cannot express internal component structure or multi-dimensional state combinations. When Material 3 Expressive introduced new specifications requiring shapes to morph across different sizes and states, Angular Material abandoned M3E support because a pure-token architecture could not express those differences, and Material Web only synced the token tables without landing them in components. In Flutter, developers need full control over component visuals and layout metrics, so strongly typed `XStyle` classes are generated for every component alongside global tokens.
- **Why not use in-type sentinel values (like Compose's `Color.Unspecified`) or masquerading subclasses (like `Mix`'s `ColorRef implements Color`) to represent "unset" or "dynamic references"?**
  An alternative that looks convenient on the surface is to stuff special sentinels inside value types rather than relying on nullable types `?` or a separate derivation channel. However, both Jetpack Compose and Flutter's community library `Mix` paid a steep price going down this path:
  1. **The lesson of Compose's `Color.Unspecified`**: Compose avoids nullable `Color?` by defining a special bit pattern `Color.Unspecified` inside the `Color` value class. Because the type system treats it as a valid `Color`, callers and component internals easily confuse "omitted argument (should fall back to theme default color)" with "explicitly requesting no background (transparent)." In early 2026, when Compose migrated `Surface` to its internal `Styles` API, the new implementation uniformly treated `Color.Unspecified` as "unset" and fell back to `colorScheme.surface`. As a result, every caller that had passed `Color.Unspecified` expecting a transparent container suddenly got an opaque background, forcing a rollback just two days after the refactoring landed ([`ab21cf1` → `00b7c9a`](https://github.com/androidx/androidx/commit/00b7c9ad187d0464082bb1ff02e8aaf3443f7426)).
  2. **`Mix`'s masquerading types and negative-float sentinel predicament ([Mix Discussion #852](https://github.com/btwld/mix/discussions/852))**: To allow the same `.color(...)` or `.padding(...)` parameter to accept both concrete values and token references, `Mix` made `ColorRef implements Color` (which throws a runtime error via `noSuchMethod` the moment any property is read outside a `Mix` widget). For `double`, which cannot be subclassed, `Mix` encoded spacing and radius tokens as **negative nano-double sentinels** registered in a global table, and when Flutter later marked `TextDecoration` as non-extensible, `Mix` had to delete `TextDecorationRef` outright. In a post-mortem (#852), the maintainer noted that this design created severe integration hazards: because `$primary()` is statically typed as `Color` and `$spacingMd()` as `double`, the compiler raises no warnings when developers pass them to standard Flutter widgets, call `copyWith` / `.withValues`, or perform arithmetic like `$spacingMd() * 2`, only for the app to crash at runtime, suffer hash collisions, or compute negative dimensions.
  Both cases expose the same fundamental flaw: whether you use `Color.Unspecified`, `double.nan`, `-1` for `int`, or masquerading subclasses as sentinels, you are smuggling "unset" or "unresolved reference" inside the normal value domain and bypassing compile-time type checking. The compiler cannot warn consumers that a value might not be real, and if any arithmetic operation, `lerp` interpolation, method call, or layout check forgets to intercept the magic sentinel, it immediately falls into a subtle API trap. That is why Step 1 establishes a strict boundary: Dart's native nullable `T?` is used exclusively to express `unset`, while `XStyle` fields at consumption time are always genuine Dart values that participate directly in painting and interpolation without special sentinel checks, never introducing masquerading sentinel objects or magic number encodings.

---

## Step 2: Placing States and Conditions — Component-Specific `XWhen` and "Rules Wrapping Styles" (`XRule`)

### 1. From Global `WidgetState` to Component-Specific Multi-Dimensional `XWhen`

Having extracted `XStyle` as a pure value container in Step 1, the next question to answer is: how should the "conditions" that determine style values be modeled?

In the existing system, the condition input to `WidgetStateProperty` is a flat enum set `Set<WidgetState>` shared across all components (or `WidgetStatesConstraint` used as a key in `WidgetStateMap`). As pointed out in Sections 2.1 and 3.1, this globally shared single-dimension enum has two limitations:
- **No per-component compile-time dimension isolation**: Different components support different valid interactive states (for example, a plain `Button` has no `selected` state, whereas `Switch` must distinguish `selected`). Sharing a single `WidgetState` enum prevents the compiler from catching `WidgetState.selected` mistakenly written on a `Button`.
- **Limited to interactive states, unable to unify visual variants and environmental dimensions**: What determines a component's style includes not only boolean interactive states (`pressed`, `hovered`, `focused`, `disabled`), but also component-specific appearance and size variants (such as `plain` / `tinted` / `filled` appearances and `small` / `medium` / `large` sizes for buttons) and environmental dimensions from the context (such as `light` / `dark` brightness and `normal` / `high` contrast).

Therefore, a natural evolution is to replace the globally shared `WidgetState` enum by having the code generator produce a **dedicated, strongly typed, immutable condition struct** for each component—named **`XWhen`** (such as `ButtonWhen` or `SwitchWhen`). It serves as the component-specific query condition unifying interactive states, component variants, and environmental dimensions. Inside `XWhen`, individual dimensions and their combination rules work as follows:

- **Binary dimensions** (such as boolean interactive states `disabled`, `pressed`, `selected`, high contrast `highContrast`, and two-valued `brightness`): typed directly as nullable scalars `bool?` or `Brightness?` (passing a specific value requires an exact match, while omitting it as `null` acts as a wildcard; if `brightness` ever expands beyond two enum values in the future, it can also be typed as `Set<Brightness>?`, as discussed in [Section 6.2](06-design-details-and-codegen.md));
- **Multi-valued enum dimensions** (such as component variants `appearance` and `size`): typed as sets `Set<E>?`, where multiple enum values inside the set represent logical OR (e.g., `appearance: {.plain, .tinted}`), and omitting the parameter (`null`) leaves that dimension unconstrained (wildcard);
- **Across different dimensions**, constraints combine with logical AND.

### 2. Comparing Two Organizational Directions: Per-Property State Branches vs. Conditions Wrapping Styles

With the component-specific condition object `XWhen` and pure value container `XStyle` in hand, the core question left at the end of Step 1 can now be formally evaluated: **should `XWhen` live inside each property of `XStyle`, or wrap `XStyle` from the outside?** Specifically, the two organizational directions are:

- **Direction A (properties on the outside, conditions on the inside)**: Keep `XStyle` at the outermost layer, where each property field carries its own list of state branches matched by `XWhen`.
- **Direction B (conditions on the outside, properties on the inside)**: Flip each style configuration into a rule `XRule(XWhen, XStyle)`, where an outer condition `XWhen` wraps an inner flat `XStyle`, and themes and components accept a rule list `List<XRule>`.

Mathematically, a component's appearance is a two-dimensional table of `properties × state combinations`. Direction A **slices by column** (`property → state branches`), whereas Direction B **slices by row** (`condition → subset of properties`). Because the resolution engine ultimately picks the winning value independently for each property field, both directions have identical theoretical expressive power. The real difference lies in **how code is organized, read, and reused**:

**The advantages of Direction A (properties on the outside, conditions on the inside)** are intuitive and shine in single-property-centric scenarios:
1. **Local completeness for a single property**: All branches for a single property (such as `backgroundColor`) across every state and variant live in one place. When reading or debugging what value a specific property takes under various conditions, you never have to jump up and down across multiple rules.
2. **More direct when tweaking a single property**: When a caller only wants to tweak one property (for instance, changing only `trackColor` when a `Switch` is `selected`), they write the property name once on the outside, making it physically impossible to touch or clobber any other property by mistake.
3. **Fits per-property IDE autocomplete**: If a property has dedicated default regions or options, putting the property name on the outside lets the IDE immediately suggest valid parameter signatures tailored to that property.
4. **Preserves the familiar `XStyle(field: ...)` constructor mental model**: The outermost layer remains a single container object taking property names as named parameters, without introducing the concept of a `List<XRule>`.

However, when looking at default component specifications and multi-property theme customizations, **Direction B (conditions on the outside, properties on the inside)** demonstrates decisive engineering advantages:
1. **Semantic conditions naturally coordinate multiple properties; Direction A fragments design intent and duplicates conditions**: Whether in Material 3, iOS Liquid Glass default specs, or custom brand themes, a state or variant condition typically represents a cohesive design intent. Interactive and semantic states (like `disabled: true` or `selected: true`) usually coordinate changes across 2 to 4 properties such as background color, foreground color, icon color, and border stroke (while geometric properties like `padding` and `borderRadius` remain invariant across interactive states in over 98% of cases). Appearance and size variants (like `appearance: filled` or `size: large`) simultaneously specify 5 to 8 visual and geometric properties, including background color, foreground color, border, corner radius, padding, minimum size, and font size. Under Direction A, on one hand, a vast number of static properties that never vary by state must still be wrapped in state containers (as noted in Section 2.1, 69% of direct `WSP` calls in production code merely wrap static constants in `WidgetStatePropertyAll`). On the other hand, every time a developer configures an interactive state or appearance variant, they must repeat the exact same condition (such as `ButtonWhen(appearance: {.filled}, disabled: false)`) under each of the 3 to 8 affected property fields, making it impossible to name, pass around, or reuse a visual variant as a self-contained unit.
2. **Direction B can absorb Direction A's single-property convenience without loss, whereas the reverse is not true**: Adopting Direction B (`List<XRule>`) as the underlying foundation means conditions that coordinate multiple properties only need to be written once on the outside. Meanwhile, for the "single-property tweak" scenarios where Direction A excels, flat property parameters on widget constructors and **per-property region constructors** as syntactic sugar on `XRule` (such as `ButtonRule.backgroundColor(...)`, derived in Step 3) can be provided. In other words, choosing Direction B as the unified foundation solves the pain of multi-property coordination while fully preserving Direction A's single-property ergonomics through top-level syntactic sugar.

With Direction B, the condition is written once on the outside, and every field inside `style:` is a plain value. Combined with the `.when` and `.always` named constructors on `XRule` and Dart's dot shorthands, a set of button rules reads as follows:

```dart
...<ButtonRule>[
  .always(
    style: .values(borderRadius: 12),
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

This syntax leverages Dart's dot shorthands and the flat dimension parameters on `.when`, and is completely equivalent to the following expanded version with explicit class names:

```dart
...[
  ButtonRule.always(
    style: ButtonStyle(borderRadius: 12),
  ),
  ButtonRule(
    ButtonWhen(
      appearance: {ButtonAppearance.filled},
      disabled: false,
    ),
    style: ButtonStyle(
      backgroundColor: CupertinoColors.activeBlue,
      foregroundColor: CupertinoColors.white,
    ),
  ),
  ButtonRule(
    ButtonWhen(
      pressed: true,
      brightness: Brightness.dark,
    ),
    style: ButtonStyle(foregroundColor: Color(0xFFFFD60A)),
  ),
]
```

Comparing the two versions above highlights three key design considerations behind this rule model:

- **Every component has its own generated `XRule` / `XWhen` / `XStyle` classes without causing binary size bloat**: Because each component has a distinct set of properties and valid state dimensions, the code generator produces dedicated rule, condition, and style classes for every themed component to provide exact compile-time type checking and code completion. Readers might worry that generating a separate set of classes for dozens of components will bloat binary size. In practice, this is not an issue: first, the generated classes for each component are thin, strongly typed data shells that share a single generic resolution engine underneath; second, paired with the decentralized theme design in Step 6, style classes for components unused by an application are automatically stripped by the compiler via tree-shaking, and even when all components are included, the impact on compiled binary size is negligible (Section 7.2 provides concrete binary size measurements).
- **A prefix-free authoring experience designed specifically around dot shorthands (and its core engineering assumption)**: Having a dedicated set of types per component introduces another immediate concern: repeatedly writing class prefixes like `ButtonRule`, `ButtonWhen`, `ButtonStyle`, and `ButtonAppearance` (as well as `ButtonColorSource` and `ButtonField` in Step 4) as in the expanded version would be very verbose. The constructors and factory methods on the generated classes are therefore tailored specifically for Dart's dot shorthands: an outer typed list spread `...<ButtonRule>[...]` declares the component rule type just once; inside, `.when(...)` flattens the dimensions of `ButtonWhen` directly into named parameters (eliminating explicit `ButtonWhen` construction), `style: .values(...)` directly constructs the corresponding `ButtonStyle`, and enum dimensions are written simply as `{.filled}` and `.dark`. This retains full per-component static type safety while keeping everyday code as compact as a prefix-free DSL. **It is worth pointing out upfront that the readability of this API rests on a core assumption: that developers will make heavy use of dot shorthands and thus rarely type out the generated helper class names by hand.** **[Section 9.5](09-topics-and-tradeoffs.md)** dedicates a standalone section to examining how this assumption interacts with IDE autocomplete, the Flutter repository style guide (especially restrictions on positional argument shorthands), and Google's internal codebase conventions, along with the corresponding mitigation strategies.
- **Outer conditions uniformly carry interactive, variant, and environmental dimensions**: Under the "outer `XRule`, inner `XWhen`" structure, interactive states (`pressed`), component variants (`appearance`), and environmental dimensions (`brightness`) are declared in the same condition and matched by the engine in a single resolution pass. The bug in `cupertino_ui` described in Section 2.1—where separating state resolution from dynamic color resolution caused components to forget to call resolve—cannot happen in this structure.

Furthermore, inside themes and `StyleScope`, every rule must explicitly call `.when(...)` or `.always(style: ...)`; **no shorthand is provided that implicitly treats an `XStyle` as an unconditional rule**. Because an unconditional `.always` rule overrides every state including `disabled`, requiring `.always` explicitly reminds the author of the rule's scope, which naturally leads to the precedence and partial-override questions addressed in the next step.

### 3. Why Not Use a Closure DSL Like Jetpack Compose's `Styles API`?

Jetpack Compose's experimental `Styles API` introduced in early 2026 also adopts the direction of per-component style definitions where outer states wrap inner properties (such as `hovered { background(...) }`). However, Compose's style blocks are runtime receiver lambdas (executing closures dynamically during layout and draw phases), while `Mix` uses chained method calls. Closure DSLs and method chaining are avoided in Dart for two reasons:
1. Dart lacks Kotlin's receiver lambda syntax, making `(s) { s.hovered((s) { ... }); }` noisy to write;
2. **In Dart, closures and method chains cannot be compile-time `const` constants** (failing Requirement 1). Without `const`, a thousand-line default component rule table cannot live in the read-only data segment, cannot use `O(1)` identity equality, cannot undergo static shadowing checks when building rule chains, and cannot cache symbolic resolution results by state combination (see Section 7.1). Therefore, `XRule` is designed as a pure data object.

---

## Step 3: How Rules Stack — Pure Sequential Precedence and Rule Regions

### Why Purely Order-Based ("Last Rule Wins") Instead of CSS Specificity or Fixed Dimension Tiers?

When a component receives rules from five levels simultaneously—**1. Component library default rules → 2. Global `StyleTheme` → 3. Outer-to-inner local `StyleScope`s → 4. Widget constructor flat parameters → 5. Widget constructor `states:` parameter**—the engine resolves values using one dead-simple rule: **concatenate all rules into a single unidirectional chain from outside in and front to back, and for each property field independently, pick the last rule on the chain that matches the current state ("last rule wins").**

There is no whole-rule replacement by state, nor any comparison of which rule constrains more dimensions. Three representative scenarios illustrate how this behaves:
- **When multiple rules in the same list match simultaneously, the later one wins**: Suppose a list defines the following three rules in order:
  ```dart
  ...<ButtonRule>[
    .always(style: .values(backgroundColor: blue, borderRadius: 12)),
    .when(hovered: true, style: .values(backgroundColor: lightBlue)),
    .when(pressed: true, style: .values(backgroundColor: darkBlue)),
  ]
  ```
  When the pointer is both hovering and pressing (`hovered: true, pressed: true`), all three conditions match. The engine independently picks the last matching rule that sets each field: `backgroundColor` takes `darkBlue` from the last rule, while `borderRadius`—left unset by the second and third rules—falls through to the first rule and takes `12`.
- **Incremental per-field stacking across levels (without clobbering unmentioned fields or states)**: Suppose the global `StyleTheme` and a page-local `StyleScope` configure the following rules:
  ```dart
  // Rule in global StyleTheme:
  .when(appearance: {.filled}, disabled: false, style: .values(backgroundColor: brandBlue, borderRadius: 8))

  // Rule appended in page-local StyleScope:
  .when(appearance: {.filled}, disabled: false, style: .values(backgroundColor: warningRed))
  ```
  Because each field independently picks the last matching rule on the chain, `backgroundColor` for `filled` buttons in that subtree takes the local `warningRed`, while `borderRadius`—unmentioned locally—retains `8` from the global theme, and the gray background for `disabled: true` in the component's default rule table remains untouched.
- **Inner broad conditions override outer narrow conditions**: Suppose the default rule table defines detailed branches for `filled` buttons under light and dark modes (constraining three dimensions: `appearance`, `disabled`, and `brightness`), and a developer wants all non-disabled buttons in a local `StyleScope` to use a fixed brand color by writing a rule that only constrains `disabled: false` (1 dimension). Under pure sequential precedence, because the local `StyleScope` sits after the default rule table on the chain, this 1-dimension local rule directly beats the 3-dimension fine-grained rules in the default table.

Why firmly choose pure sequential precedence instead of introducing CSS-style specificity (where rules constraining more dimensions carry higher weight) or the preset dimension tiers used by `Forui` and `Mix`?

1. **The problem CSS specificity was invented to solve—"uncontrolled stylesheet load order"—does not exist in Flutter, and specificity itself became historical baggage that the web spent decades trying to work around**:
   - **Why CSS invented specificity in the first place**: On the early web, a page's styles often came from multiple external `.css` files, third-party component stylesheets, and inline tags. Because network loading, bundler output, or HTML `<link>` insertion order was rarely controlled by a single author, CSS needed a tie-breaking mechanism **independent of authoring or loading order** to ensure that a more specific exception like `.btn.primary:hover` would automatically beat a general rule like `.btn` even if it loaded earlier in the page.
   - **The long-standing struggle against specificity in CSS practice**: Once you introduce specificity, whether a rule wins no longer depends on "which rule is written further inward or later," turning instead into an arithmetic contest of dimension weights. When a developer tries to override a detailed rule in a base library (written with three or four pseudo-classes or class names) using a simple local rule, the local rule silently loses due to lower specificity. To beat base rules, the frontend community first fell into the trap of abusing `!important` and padding selectors with meaningless classes just to inflate weights; next, it invented the **BEM methodology** (flattening all selectors into a single class to artificially neutralize specificity and return to pure order control); later still, the CSS specification itself had to introduce the **`:where()` pseudo-class** (explicitly zeroing out selector specificity so downstream rules can override it easily) and **`@layer` cascade layers** (letting explicit layer ordering directly trump specificity). Much of modern CSS's twenty-year evolution has been a history of **finding ways to bypass specificity and reclaim sequential order control**.
   - **Flutter naturally guarantees deterministic ordering**: Flutter has no issue with external stylesheets loading asynchronously out of order. Rules at the same level live in a single Dart list literal whose order is immediately visible and fully controlled by the author; order across levels strictly follows the outside-in topology of the widget tree (default table → global theme → outer `StyleScope` → inner `StyleScope` → call site), matching the developer's intuition that "closer to the component means higher priority." Moreover, the component library's default rule table always sits at the very front of the chain, so even if a framework upgrade adds finer-grained default rules, they will never jump ahead of any custom user rules. Introducing specificity into Flutter would mean importing the disease—"inner broad overrides losing to narrow default rules, forcing developers to pad condition counts"—where the underlying cause does not even exist.
2. **Preset dimension tiers create a counter-intuitive hidden priority table that easily trips developers up during cross-dimension overrides**: As discussed in Section 3.2, `Mix` hardcodes variant tiers as `base < environment (e.g., onDark) < interactive state (e.g., onHover)`, while `Forui` tiers them as `platform < interactive < semantic`. Preset tiers force developers to memorize a hidden hierarchy, and whenever a real requirement goes against the preset ranking, they hit a wall. In `Mix`, the official documentation has to explicitly warn developers that *"variants always override regular properties—even if you chain regular properties after the variant, they cannot override it,"* making runtime behavior the exact opposite of top-to-bottom reading intuition. Even `Mix`'s own maintainers repeatedly tripped over tier interactions (in its 2.2.0 release notes, `focus-visible` silently lost its focus ring because it always lost to other states within the state group, and nesting `onHover` inside the environment group's `onDark` caused hover effects to fail completely due to cross-group priority conflicts). Similarly, in `Forui`, to make a lower-tier `android` (platform) rule beat a higher-tier `touch` (interactive) rule, the maintainer had to contort it into a compound condition `touch & android`.
3. **Prefix cacheability**: Because priority depends solely on position in the chain, any prefix of a rule chain (such as "default table + global theme") can be pre-merged and cached per state combination, allowing inner nodes to simply stack on top of the cached result (see Section 7.1 for details).

### The Cost of Pure Sequential Order and Its Solution: Rule Regions and Region Constructors

Combining pure sequential stacking with outer conditions carries one obvious cost: **a broad condition written later will clobber finer-grained state rules written earlier, and whenever two non-nested state conditions overlap, the outcome depends entirely on the order in which they are written.**

For example, suppose a developer wants to change the background color of `tinted` buttons to mint green in the global theme. If they write `.when(appearance: {.tinted}, style: .values(backgroundColor: mint))`, because this rule does not constrain the `disabled` dimension and sits after the default rule table, it will also clobber the default gray background of `tinted` buttons when `disabled: true`, turning disabled buttons mint green as well. In fact, such state-precedence bugs already happen frequently in existing `resolveWith` closures: in a sample audit of a large production codebase, 4 button background color closures were found that checked `hovered` first, `pressed` second, and `disabled` last—because pressing a mouse button on desktop always implies hovering, the pressed color could never appear (and when `disabled` and `focused` simultaneously, it erroneously showed the interactive color). Around 10 `Switch` and `Checkbox` closures across 6 apps were also found that checked `selected` without checking `disabled`, causing disabled controls to display full active colors. Under a purely sequential rule model, writing `.when(selected: true, ...)` after the default rules or placing `.when(pressed: true)` before `.when(hovered: true)` falls into the exact same trap.

To avoid clobbering `disabled` or inverting state order, a developer would need to first inspect how the component's default rule table partitions that field across states and then manually write mutually exclusive conditions (such as `.when(appearance: {.tinted}, disabled: false, ...)`). Having to look up a component's default rule table and derive mutually exclusive conditions by hand every time you tweak a single property would set the barrier to entry far too high.

Here a key observation applies: **how a component's default rule table partitions a property across states reflects that property's core semantic boundaries in the design spec—which are the exact dimension combinations developers are most likely to customize individually in everyday work** (for instance, a button's `backgroundColor` is partitioned by appearance and enabled/disabled state by default, a switch's `trackColor` is partitioned by selected/unselected and enabled/disabled state, and a button's `borderRadius` remains constant across all interactive states). Since the code generator already holds the component's complete default rule table, the generator can extract these mutually exclusive state partitions directly from the default table and turn them into out-of-the-box APIs.

Specifically, at build time the generator statically analyzes the component's default rule table. For each property field, it traverses all reachable state combinations and groups **the set of states where the exact same default rule wins** into a single **rule region**.

Taking Cupertino `Button.backgroundColor`, Material `CommonButton.elevation` (across `elevated`, `filled`, and `outlined` appearances), and `Button.alignment` as examples, a 2D Karnaugh map can be drawn for each property (where rows are `appearance` and columns are reachable interactive state combinations). On each map, **all cells won by the same default rule merge into a single block (a "rule region")**:

```text
1. Cupertino Button.backgroundColor (when enabled, does not distinguish pressed; first two columns merge → 5 regions total)
              disabled: F        disabled: F        disabled: T
              pressed:  F        pressed:  T        pressed:  F
           ┌────────────────────────────────────────────────────────┐
  plain    │                    transparent                         │ ──► 1 region: plainAnyState
           ├─────────────────────────────────────┬──────────────────┤
  tinted   │             tintedFill              │   tertiaryFill   │ ──► 2 regions: tintedEnabled / tintedDisabled
           ├─────────────────────────────────────┼──────────────────┤
  filled   │            primaryColor             │   tertiaryFill   │ ──► 2 regions: filledEnabled / filledDisabled
           └─────────────────────────────────────┴──────────────────┘

2. Material CommonButton.elevation (when enabled, also splits by hovered / pressed → produces an Idle region)
              disabled: F    disabled: F    disabled: F    disabled: T
               (idle rest)    hovered: T     pressed: T
           ┌──────────────┬──────────────┬──────────────┬──────────────┐
  elevated │     1.0      │     3.0      │     1.0      │     0.0      │ ──► 4 regions: elevatedIdle / Hovered / Pressed / Disabled
           ├──────────────┼──────────────┼──────────────┼──────────────┤
  filled   │     0.0      │     1.0      │ 0.0 (as left)│     0.0      │ ──► 3 regions: filledIdle (incl. pressed) / Hovered / Disabled
           ├──────────────┴──────────────┴──────────────┴──────────────┤
  outlined │                            0.0                            │ ──► 1 region: outlinedAnyState
           └───────────────────────────────────────────────────────────┘

3. Button.alignment (entire map spans a single region horizontally and vertically → no region constructor needed)
              disabled: F        disabled: F        disabled: T
              pressed:  F        pressed:  T        pressed:  F
           ┌────────────────────────────────────────────────────────┐
  plain    │                                                        │
  tinted   │                    Alignment.center                    │ ──► Only 1 unconstrained region
  filled   │                                                        │
           └────────────────────────────────────────────────────────┘
```

The block shapes across these three Karnaugh maps illustrate the three core properties this mechanism achieves:
- **Mutually exclusive and collectively exhaustive across the entire truth table**: Regardless of how many blocks a property's Karnaugh map is split into, its rule regions tile the entire truth table without overlaps or gaps. Modifying any single region (such as passing only `tintedEnabled`) will never bleed into an adjacent region (like `tintedDisabled`), nor will it accidentally expose underlying defaults due to a missed state branch; moreover, when passing multiple regions in a single call, parameter order does not matter at all.
- **Automatically omits "don't-care" dimensions to produce intuitive, readable parameter names**: The generator's naming algorithm automatically drops merged-out dimensions from parameter names. Because `backgroundColor` under the `plain` appearance does not care whether the button is disabled or pressed, it is named `plainAnyState`; under `tinted`, it cares only about whether the button is disabled and not whether it is pressed, so it drops `pressed` and names the parameters `tintedEnabled` and `tintedDisabled`; only for properties like `elevation` that split out dedicated regions for `hovered` and `pressed` does the resting state excluding hover and press get named `elevatedIdle`. Developers do not need to memorize underlying naming rules—the parameter name itself tells you which state slice it represents.
- **Static properties that span the entire table generate no extra API (such as `alignment`)**: When a single unconditional default rule wins across every cell, the Karnaugh map has only **1 block**, and the generator skips it without emitting a redundant region constructor.

Whenever a field has more than 1 region in the default table, the generator emits a same-named `const` **region constructor** on `XRule` exposing each region as an optional named parameter.

In the existing system, the ceiling for ergonomic everyday authoring is flat parameters on widget constructors; the moment you configure a theme or customize by state, you have to write `resolveWith` closures by hand. In the new model, alongside flat parameters at call sites, a generated `XRule.<field>(...)` region constructor is itself a valid `XRule` that can be mixed directly into a rule list. Combined with dot shorthands, you never have to write conditions by hand—typing `.backgroundColor(` in the IDE brings up autocomplete listing all state regions partitioned by the default table (`plainAnyState`, `tintedEnabled`, `tintedDisabled`, `filledEnabled`, `filledDisabled`):

```dart
...<ButtonRule>[
  .always(style: .values(borderRadius: 12)),
  // Modify backgroundColor directly by default state regions inside the rule list:
  // pass only tintedEnabled and filledEnabled; omitted tintedDisabled / filledDisabled automatically keep default gray
  .backgroundColor(
    tintedEnabled: CupertinoColors.systemMint,
    filledEnabled: CupertinoColors.systemIndigo,
  ),
]
```

Under the hood, that single `.backgroundColor(...)` region rule is completely equivalent to expanding in place into the following two `.when(...)` rules with explicit `XWhen` conditions:

```dart
...<ButtonRule>[
  .always(style: .values(borderRadius: 12)),
  // ↑ The .backgroundColor(...) call above precisely replaces these two hand-written conditional rules:
  .when(
    appearance: {.tinted},
    disabled: false,
    style: .values(backgroundColor: CupertinoColors.systemMint),
  ),
  .when(
    appearance: {.filled},
    disabled: false,
    style: .values(backgroundColor: CupertinoColors.systemIndigo),
  ),
]
```

### Initial Feasibility of Rule Regions and Deeper Questions Deferred to Section 6.1

Turning the state partitions of the default rule table directly into named parameters on public constructors naturally raises several engineering questions:
- **Scale**: Material 3 components have many state and variant dimensions—will generated region constructors end up with dozens of parameters and suffer combinatorial explosion?
- **Stability and evolution compatibility**: If default color values are tweaked in the future, or the state partitioning structure of the default rules is altered during a spec upgrade, will public parameter names churn and cause breaking changes?
- **Semantic boundaries**: If an outer theme adds a new state branch to a property that was not in the default table (for example, adding a press color change to a background color that did not distinguish `pressed` by default), what happens when an inner scope overrides it using default region parameters?

To keep the main derivation flowing, the deep dive into cross-version compatibility strategies, alternative API shapes, and the semantic boundaries of rule regions is deferred to **[Section 6.1](06-design-details-and-codegen.md)**. However, for the two foundational questions—"will parameters explode combinatorially?" and "will tweaking default values break the API?"—the verification results can be shared right away:

1. **Why tweaking default colors never affects parameter names (while structural changes still require dedicated handling)**: Rule regions are defined by **which default rule wins in a given state**, not by whether the final computed color values happen to be equal. As long as the `XWhen` condition structure of the rules in the default table remains unchanged, routine adjustments to default color values or opacity numbers never alter region boundaries or parameter names. (As for how breaking changes are prevented when a future spec upgrade genuinely adds or splits default rule conditions—by retaining `@Deprecated` legacy parameter names and automatically mapping them to the new regions—see Section 6.1.)
2. **Why combinatorial parameter explosion does not occur**: Running the region extraction algorithm across all **868 property keys** (including expanded sub-properties of composite types) on all 17 core component groups in `material_ui` shows that **774 properties (89%)** have only 1 unconstrained region across all states (meaning they do not vary by state by default and require no generated region constructor); only **94 properties** actually vary by state (yielding 490 regions total), averaging about **5 parameters** per partitioned field, and **99.6% of regions map directly to a single `XWhen` condition**.

Based on this foundation, the basic division of labor in everyday use is: **when a state needs to coordinate changes across multiple fields (or requires custom conditions outside the default regions), use `.when(...)`; when you only need to modify the literal value of a single field along the component's default state partitions, use the `XRule.<field>(...)` region constructor as a shortcut.** (For the known limitations of this tradeoff, its boundaries when stacking with custom outer themes, and the underlying ~21-byte-per-region expansion implementation, see [Section 6.1](06-design-details-and-codegen.md).)

---

## Step 4: Declarative Derivations and Global/Custom Tokens — `XStyleSpec` and `TokenGroup`

### 1. Semantics of Derivation: Moving Hardcoded Tracking Relationships into the Rule Chain (Compete First, Evaluate Last)

Beyond concrete literal values, component styles include two fundamental kinds of dynamic tracking relationships:
- **Cross-field tracking (sibling fields)**: For example, a button's icon or focus color tracks `foregroundColor` or `backgroundColor` on the same button instance by default;
- **Referencing global design tokens**: For example, a button's default background or foreground color reads from the global `primaryColor` token.

In existing component libraries, cross-property tracking is typically hardcoded as black-box logic right inside the component's `build()` method:

```dart
final Color effectiveIconColor =
    widget.iconColor ?? theme.iconColor ?? effectiveForegroundColor;
```

As discussed in Sections 2.2 and 3.2, this approach not only hides the fallback order from theme authors and makes it impossible to change, but also breaks down mid-transition during `lerp` animations due to `null` interpolation. Conversely, if you eagerly evaluate and bake token values into component themes at construction time—as `Forui` or the legacy `ColorScheme` defaults do—then whenever a subtree locally overrides a source token or source field, downstream properties fail to update accordingly.

In fact, "derivation" means the exact same thing semantically as that line of code above: **read the final resolved value of another field on the same component instance (or the final resolved value of a global token) and use it as the value of the current field.**

The core shift in the new model is moving that hidden logic out of `build()` and into the explicit rule chain, following a two-phase **"compete in order first, resolve and evaluate last"** model:
1. **Compete on the rule chain**: A derivation rule participates in "last rule wins" from outside in and front to back on completely equal footing with plain literal rules. If an earlier rule is a derivation (such as the default table making `iconColor` track `foregroundColor`) and a later rule assigns a concrete `Color` literal to `iconColor`, the literal naturally overrides and severs the earlier tracking relationship; conversely, if an earlier rule pinned a property to a fixed literal value and an inner rule overrides it with a derivation rule, the inner derivation takes effect and re-establishes dynamic tracking.
2. **Lazy evaluation after winning (supporting chained forwarding and automatic cycle detection)**: Once the entire rule chain has merged via "last rule wins," each property slot holds a single winning entry—either a **literal value** or a **derivation reference**. The engine then begins phase-two evaluation: for any property holding a derivation reference, it looks up the winning entry of the target sibling field or global token it points to. If that target is already a literal value, it uses it directly; if the target is itself another derivation reference, the engine follows the reference chain until it reaches a final literal value (for example, if property A tracks `foregroundColor`, and `foregroundColor` references the global token `primaryColor`, evaluation resolves the entire chain in sequence). If stacking multiple rules accidentally creates a circular reference (such as `A` tracking `B` while `B` tracks `A`), the engine automatically detects the cycle and throws a descriptive error. This way, whether an outer or inner scope modifies `foregroundColor` or `primaryColor`, every downstream property tracking it automatically computes the updated result.

### 2. Authoring Derivation Rules: `style: .derive(...)` and the `XStyleSpec` Type Design

Authoring a rule containing derivations looks very similar to authoring a plain literal rule; the only difference is replacing `.values(...)` on the `style:` parameter with `.derive(...)`. Inside `.derive(...)`, every field parameter accepts derivation sources (such as `.fromToken(...)` or `.fromField(...)`); conversely, when you want to mix plain literal values into a `.derive(...)` block alongside derivations, you wrap those literals in `.value(...)`:

```dart
...<ButtonRule>[
  .when(
    appearance: {.filled},
    disabled: false,
    style: .derive(
      // 1. Directly reference a global token:
      backgroundColor: .fromToken(.primaryColor),
      foregroundColor: .fromToken(.primaryContrastingColor),
      // 2. Directly track a sibling field on the same component instance:
      focusColor: .fromField(.backgroundColor),
      // 3. When mixing a plain literal value inside .derive(...), wrap it in .value(...):
      borderRadius: .value(12.0),
    ),
  ),
]
```

In the underlying type hierarchy, the `style:` parameter on `ButtonRule.when` has the base type `ButtonStyleSpec`, and both `.derive` and `.values` are named constructors on `ButtonStyleSpec`:
- **`ButtonStyleSpec.derive(...)`**: Each field parameter accepts the wrapper type `ButtonSource<T>` (or dedicated source subclasses like `ButtonColorSource` for color fields), which provide named constructors such as `.fromToken(...)`, `.fromField(...)`, and `.value(...)`;
- **`ButtonStyleSpec.values(...)`**: A redirecting `const factory` constructor pointing to the subclass `ButtonStyle` (`final class ButtonStyle extends ButtonStyleSpec`), where each field parameter directly accepts bare value types like `Color` and `double`.

You can therefore view `.values(...)` as syntactic sugar over `.derive(...)`: when every field in a rule is a direct literal value, using `.values(...)` saves you from wrapping every single property in `.value(...)`. Moreover, because both `.values(...)` and `.derive(...)` expose only a single named parameter slot per property, setting both a literal value and a derivation on the same field in a single rule is syntactically impossible.

### 3. Color Transformation Operators: Why Provide Dedicated `.opacity` for Colors?

While `.fromField` and `.fromToken` handle reading another field or token's value verbatim, **color (`Color`) holds a uniquely special status** among all property types. Across real-world component specifications (both Material 3 and iOS HIG), rules that scale a source color's opacity by a factor appear everywhere—for example, M3's disabled foreground color is `onSurface` multiplied by `0.38`, hover ripple is `primary` multiplied by `0.08`, and iOS's `tinted` button background color is `primaryColor` multiplied by `0.15` (or `0.28` in dark high-contrast mode).

At the same time, **inventing a general-purpose functional operator DSL** just for derivation transforms is undesirable (at least at this stage), because non-color properties like padding, corner radius, and alignment rarely need arithmetic transformations. A pragmatic approach is therefore taken: **only the highest-frequency, essential color opacity transforms are hand-picked and built in as declarative operators**.

Specifically, on the color source subclass `XColorSource` (such as `ButtonColorSource`), two declarative opacity transformation operators are provided:
- **`.opacity(source, factor)`**: Multiplies the opacity of the inner color `source` (which can be `.fromToken`, `.fromField`, `.value`, or another nested transform) by `factor` (clamped to `[0, 1]`), e.g., `backgroundColor: .opacity(.fromToken(.primaryColor), 0.15)`;
- **`.opaque(source)`**: Preserves the RGB channels of the inner color source while resetting its alpha channel to `1.0` (for example, `.opacity(.opaque(source), 0.5)` ignores any semi-transparency on the source color and forces it to 50% opacity).

Because both `.opacity` and `.opaque` are `const` constructors, they keep rules readable while fully preserving `const`-ness, value equality (`==`), and debug introspectability.

### 4. General Computed Callback Derivations: Division of Labor Between `.computed(fn)` and Declarative Combinators

For the small fraction of complex calculations not covered by the built-in operators—such as computing a focus ring color dynamically from the background color's HSL lightness, or combining multiple fields and environmental dimensions in custom arithmetic—`XSource<T>` provides a general callback derivation entry point **`.computed(T Function(XView s) fn)`**:

```dart
focusColor: .computed((ButtonView s) {
  final Color bg = s.field(.backgroundColor);
  return HSLColor.fromColor(bg).withLightness(0.8).toColor();
}),
```

Note that **`.computed(fn)` accepts any regular function or inline closure in its type signature**. During evaluation, the callback's `XView` parameter (such as `ButtonView`) can read the final resolved values of sibling fields under the same state (`s.field(...)`), global tokens (`s.token(...)`), and current state dimensions (such as `s.brightness`) on demand.

However, due to Dart language constraints, **no inline closure (even one that captures no external variables) is a `const` expression**, and evaluating a closure literal allocates a new function instance each time, causing `==` equality checks to return `false`. Consequently:
- If a developer passes an inline closure for an ad-hoc customization, the code works as expected, except that the rule containing the closure cannot be marked `const` and will be treated as a new rule whenever the parent widget rebuilds;
- In component default rule tables or reusable theme configurations where preserving `const` and cross-frame cache hits matters, developers can extract the calculation into a top-level function or static method and pass its tear-off (such as `focusColor: .computed(_focusRingFromBg)`, detailed in [Section 6.2](06-design-details-and-codegen.md)).

This also answers a natural design question: **if `.computed(fn)` can already express arbitrary derivation logic, why provide declarative combinators like `.fromField`, `.fromToken`, and `.opacity` at all?**
1. **Avoid forcing everyday scenarios to choose between inline closures that break `const` / `==` and verbose top-level helper functions**: Tracking a sibling field, referencing a token, and scaling color opacity account for over 95% of all derivation use cases. If even these basic operations required a function callback, developers would either write inline closures like `(s) => s.field(.foregroundColor)`—sacrificing `const` and equality caching—or extract a separate top-level function for every single simple reference just to keep `const`. Providing built-in declarative combinators lets those 95% of everyday rules stay inline, `const`, and value-comparable, reserving `.computed(fn)` for genuinely custom arithmetic.
2. **Keep reference relationships transparent to debugging tools and static checks**: Function callbacks are opaque black boxes to the engine, whereas `.fromField`, `.fromToken`, and `.opacity` are introspectable data objects. Debug provenance tools (`debugSources`) can print out the full dependency chain `focusColor ← field .backgroundColor ← token primaryColor` without executing code, and the engine can statically detect circular cross-field references when building rule chains (see Section 7).

### 5. Global and Custom `TokenGroup` (Replacing `ThemeExtension`)

In the preceding subsections, component rules referenced built-in global tokens via `.fromToken(.primaryColor)`. In real-world applications or enterprise design systems, however, the fixed fields on standard `ColorScheme` or `CupertinoToken` are rarely enough—developers also need to define **app-specific custom tokens** such as `accent`, `success`, `textPrimary`, `textMuted`, custom corner `radius`, or semantic color groups.

In existing Flutter, **`ThemeExtension` was introduced specifically for this purpose**: it lets developers attach custom tokens to `ThemeData.extensions` to propagate down the theme tree and participate in `AnimatedTheme` interpolation transitions without writing a custom `InheritedWidget` from scratch. Yet a full audit of **91 `ThemeExtension` subclasses (1,149 fields total)** across 21 production Flutter projects revealed three major engineering pain points with legacy `ThemeExtension`:
1. **Heavy, error-prone mechanical boilerplate**: 82 of the 91 extension classes (90%) were written by hand, averaging **12.8 lines** of method body code per field (roughly **10,500 lines** of boilerplate across 770 hand-written fields). Inside `lerp` methods alone, the audit found **739 non-null assertions `X.lerp(a, b, t)!`** and **81 `??` fallbacks**, while **18 classes (20%)** had incomplete or degenerate `lerp` implementations that simply returned `this` or `other`.
2. **No declarative references from component styles and no inter-token derivation model**: `ButtonStyle` and `XThemeData` cannot declaratively bind to `ThemeExtension` fields; developers have to manually copy values into component themes when constructing `ThemeData`. Derivations inside an extension rely on hand-written alias getters (49 found in the audit) or eager precomputation in constructors (32 opacity variants, 37 `ColorScheme` references, and 10 fallback getters). Because there is no derivation recomputation mechanism, overriding a base color via `copyWith` causes precomputed derived fields (such as 30 opacity variants precomputed by a factory in one project) to **silently go stale**.
3. **No per-field merging**: `ThemeData.copyWith(extensions: ...)` replaces the entire extensions map wholesale. Across the 21 audited projects, all 8 subtree theme overrides had to rebuild the entire `ThemeData` via a factory, 2 projects had to write their own `patchExtensions` merge helpers, and 1 nested `ThemeData` registered only 5 of the app's 10 extensions—causing the other 5 extensions to vanish silently inside that subtree.

Following the rule-chain model from the first four steps, the custom `TokenGroup` mechanism that replaces `ThemeExtension` can be derived in three sub-steps:

#### (1) Define a Token Enum and Write-Side Rule Class (Eliminating `copyWith` and `lerp` Boilerplate)

In legacy `ThemeExtension`, every field must be repeated four times across the constructor, field declarations, `copyWith`, and `lerp`:

```dart
// Legacy approach: ~12.8 lines of method body per field, with Color.lerp(...)! scattered across lerp
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({required this.accent, required this.success, required this.textPrimary});
  final Color accent;
  final Color success;
  final Color textPrimary;

  @override
  BrandColors copyWith({Color? accent, Color? success, Color? textPrimary}) => BrandColors(
        accent: accent ?? this.accent,
        success: success ?? this.success,
        textPrimary: textPrimary ?? this.textPrimary,
      );

  @override
  BrandColors lerp(covariant BrandColors? other, double t) {
    if (other is! BrandColors) return this;
    return BrandColors(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
    );
  }
}
```

In the new model, custom tokens adopt the same **read/write separation** as component styles (and do not even require a group-level read data class, for reasons explained in [Section 6.2](06-design-details-and-codegen.md)), consisting solely of **one token enum** plus **one write-side rule class**:

```dart
// 1. Token enum: serves as both the reference identifier and the direct read entry point.
// Standard types (Color, double, TextStyle, ShapeBorder, BoxShadow, etc.) automatically use the engine's built-in interpolation table;
// nested custom composite classes (like SemanticGroup) explicitly pass their static interpolation function via lerp:.
enum MyBrand<T extends Object> with GroupTokenMixin<T> {
  accent<Color>(),
  success<Color>(),
  textPrimary<Color>(),
  textMuted<Color>(),
  radius<double>(),
  info<SemanticGroup>(lerp: SemanticGroup.lerp);

  const MyBrand({this.lerp});
  @override
  final T? Function(T? a, T? b, double t)? lerp;

  static const TokenGroup group = TokenGroup('MyBrand', values);
}

// 2. Write-side rule class (pure-value TokenValueRule): all parameters are nullable; omitted tokens automatically fall back to earlier rules
final class const MyBrandRule({
  super.when,
  final Color? accent,
  final Color? success,
  final Color? textPrimary,
  final Color? textMuted,
  final double? radius,
  final SemanticGroup? info,
}) extends TokenValueRule {
  @override
  Map<Token<Object>, Object> get values => {
        MyBrand.accent: ?accent,
        MyBrand.success: ?success,
        MyBrand.textPrimary: ?textPrimary,
        MyBrand.textMuted: ?textMuted,
        MyBrand.radius: ?radius,
        MyBrand.info: ?info,
      };
}
```

- **Boilerplate and interpolation comparison**: Each token requires only **3 one-line entries**: the enum value, the rule class parameter, and the `values` map entry (if an app only has a couple of standalone tokens, it can even skip `MyBrandRule` and use zero-boilerplate `MyBrand.accent.set(x)` directly). There is no need to write `copyWith` (partial overrides work via rule stacking) or `lerp` (during theme transition animations, each token automatically interpolates via a three-tier fallback: the enum value's own `lerp:` → the engine's built-in type interpolation table covering **99%** of interpolatable fields in real projects → a discrete step at `t = 0.5`).
- **Explicit tradeoff**: Without relying on a code generator, the developer maintains the mapping between token keys and constructor parameters in `MyBrandRule.values` by hand. If a key is accidentally omitted from the map and no other rule on the chain sets it, the compiler cannot catch the omission at compile time; instead, reading that token at runtime throws a `RuleError` naming the missing token.

#### (2) Configure Light/Dark Environments via `TokenWhen`, Read Directly Outside Components, and Reference Inside Component Rules

When designing custom tokens, a central question is **which layer should handle light/dark mode differences**. An audit of a large codebase showed that out of 1,403 theme constructions, only 70 (5%) mentioned brightness, and 0 button styles inside themes mentioned brightness (only 7 out of 485 `resolveWith` closures checked brightness)—developers almost never branch on brightness directly inside component themes; instead, components get their light/dark differences indirectly through `ColorScheme` and tokens (which themselves take different values in light and dark modes). This aligns with the layering preference here where **light/dark differences live primarily at the token layer, and component rules rarely need to write `when: brightness`** (note: because roughly 14,600 files in that codebase share a single token-driven M3 theme wrapper library, those ratios partly reflect that wrapper library's design choices, so they align with this approach rather than serving as universal proof). At the same time, the codebase had **567 occurrences of `isDark ? ...` and 372 occurrences of `== Brightness.dark`** scattered across application widget code; among the 91 audited `ThemeExtension` classes, roughly **60** distinguished light and dark modes (**7** distinguished high contrast), and around **85%** of reads happened inside regular widget `build` methods. Under the new model, those ad-hoc light/dark ternary checks scattered across app widgets can be consolidated cleanly into custom `TokenGroup`s. Compare the old and new approaches:

```dart
// Legacy approach: build two separate full instances for light and dark; manually copy values into component themes when constructing ThemeData;
// reading requires verbose Theme.of(context).extension<BrandColors>()! (~70% of files wrote custom helper functions just for this).
ThemeData buildTheme(BrandColors brand, double radius) => ThemeData(
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        ),
      ),
      extensions: [brand],
    );
// Reading inside a widget:
Text('Paid', style: TextStyle(color: Theme.of(context).extension<BrandColors>()!.success));
```

In the new model, all tokens live in a global channel conditioned solely on environmental dimensions. Because tokens are shared across different components and read directly outside components, their conditions cannot include component-local dimensions like `pressed` or `appearance`; instead, they use the generated global environment condition class **`TokenWhen`**, which covers all built-in environmental dimensions of the component library (such as `brightness` and `highContrast`, from which each component's `XWhen` selects a subset as needed). Note that **the system does not support adding custom environmental dimensions to `TokenWhen` or `XWhen`** (for custom environmental conditions like a third theme mode, brand skin, or screen breakpoint, the app simply reads that state outside and passes the corresponding rule list to `StyleTheme` or `StyleScope` conditionally, without injecting custom dimensions into the rule engine). Furthermore, because `MyBrandRule` is hand-written by application developers, accepting a single `TokenWhen?` parameter via `super.when` takes just one line, sparing developers from copying every environmental dimension parameter into the constructor of every custom rule class (which is why it uses `when: TokenWhen(...)` rather than flattening environment parameters like the generated `ButtonRule.when`).

Consequently, light/dark and high-contrast configurations are just regular sequential rules with a `TokenWhen` condition (staying `const`, participating in per-environment caching, and interpolating smoothly during environment switches), while unchanged values like `radius: 12` automatically carry over from earlier rules. Outside components, widgets call **`MyBrand.success.of(context)`** built into `GroupTokenMixin<T>` to read a non-null value directly (projects that prefer a `context.brand(.accent)` dot-shorthand style can add a one-line `BuildContext` extension); inside component rules, `.fromCustomToken(...)` declaratively binds to the token (converting a `double` radius into a shape or `BorderRadius` is done via `.computed`, avoiding a redundant extra token):

```dart
BorderRadius brandRadius(ButtonView s) => BorderRadius.circular(s.customToken(MyBrand.radius));

// 1. Put light/dark configurations and component rule references in the same rule list (or package them as a static const List<Rule> preset)
StyleTheme(
  groups: [MyBrand.group],
  rules: const [
    MyBrandRule(accent: teal700, success: green700, textPrimary: ink, radius: 12, info: infoLight),
    // The dark rule only specifies tokens that change; radius: 12 automatically carries over from the previous rule
    MyBrandRule(when: TokenWhen(brightness: .dark), accent: teal200, success: green300, textPrimary: paper, info: infoDark),
    ButtonRule.when(appearance: {.filled}, style: .derive(
      backgroundColor: .fromCustomToken(MyBrand.accent),
      borderRadius: .computed(brandRadius),
    )),
  ],
  child: app,
);

// 2. Read non-null Color directly inside a regular widget's build method (zero helper functions)
Text('Paid', style: TextStyle(color: MyBrand.success.of(context)));
```

#### (3) Inter-Token Derivations (`TokenSourceRule` vs. `.setFrom`) and Local `StyleScope` Overrides

In the codebase audit, many extension fields derived from other tokens (roughly 49 aliases, 32 opacity variants, and 10 fallback getters). For example, a designer might specify that secondary text color `textMuted` is always 60% opacity of primary text color `textPrimary`, and that `success` falls back to the component library's built-in semantic color when not overridden by the brand. In legacy `ThemeExtension`, if you store `textPrimary.withValues(alpha: 0.6)` into the `textMuted` field at construction time, calling `copyWith(textPrimary: newColor)` later leaves `textMuted` stale; if you write it as a getter `Color get textMuted => textPrimary.withValues(alpha: 0.6)`, you can no longer override `textMuted` independently on a specific page.

In the new model, inter-token derivations are also regular sequential rules—dynamically computed from the currently active upstream token during resolution so they never go stale, while still allowing subsequent rules to override and pin them to a literal value. To serve both "mostly pure values" and "derivation-heavy" scenarios, the engine provides two rule base classes (corresponding to the `.values(...)` and `.derive(...)` tiers in component styles):

- **Lightweight option (keep `TokenValueRule` + single `.setFrom`)**: If a group has only one or two derivations, `MyBrandRule` continues to extend `TokenValueRule`, and the derivation is written as a standalone rule `MyBrand.textMuted.setFrom(.opacity(.fromCustomToken(MyBrand.textPrimary), 0.6))`.
- **Full source option (switch to `TokenSourceRule`)**: If a group has many derivations (or is code-generated like `CupertinoTokenRule`), `MyBrandRule` can extend **`TokenSourceRule`**, changing its parameter types to the shared `TokenColorSource?` (which includes `.opacity` and `.opaque`) and `TokenSource<T>?`. Literal values and derivations can then sit side by side in the same `const MyBrandRule(...)` (at the cost of wrapping literal values in `.value(...)`):

```dart
final class const MyBrandRule({
  super.when,
  final TokenColorSource? accent,
  final TokenColorSource? success,
  final TokenColorSource? textPrimary,
  final TokenColorSource? textMuted,
  final TokenSource<double>? radius,
  final TokenSource<SemanticGroup>? info,
}) extends TokenSourceRule {
  @override
  Map<Token<Object>, DeriveSource> get sources => {
        MyBrand.accent: ?accent,
        MyBrand.success: ?success,
        MyBrand.textPrimary: ?textPrimary,
        MyBrand.textMuted: ?textMuted,
        MyBrand.radius: ?radius,
        MyBrand.info: ?info,
      };
}

StyleTheme(
  groups: [MyBrand.group],
  rules: const [
    // Default derivation rule: textMuted = textPrimary × 0.6; success falls back to built-in token by default
    MyBrandRule(
      textMuted: .opacity(.fromCustomToken(MyBrand.textPrimary), 0.6),
      success: .fromToken(.primaryColor),
    ),
    MyBrandRule(accent: .value(teal700), textPrimary: .value(ink), radius: .value(12), info: .value(infoLight)),
    MyBrandRule(when: TokenWhen(brightness: .dark), accent: .value(teal200), textPrimary: .value(paper), info: .value(infoDark)),
  ],
  child: app,
);
```

When you need to locally override the brand or primary text color in a subtree (such as a promotional banner), you do not replace the entire extension table as with `ThemeData.copyWith(extensions: ...)`; you simply append a rule in `StyleScope`:

```dart
StyleScope(
  rules: const [MyBrandRule(accent: .value(pumpkin), textPrimary: .value(brown))],
  child: promoBanner,
);
```

Inside that subtree, buttons referencing `MyBrand.accent`, `MyBrand.textMuted` derived from `MyBrand.textPrimary` (automatically updating to `brown × 0.6`), `MyBrand.accent.of(context)` calls in regular widgets, and dialogs launched from that subtree all update automatically, while unspecified tokens and other extension groups remain intact (for a complete end-to-end walkthrough, see [Chapter 5, Scenario 3](05-walkthrough.md); for underlying edge cases and testing practices, see [Section 6.2](06-design-details-and-codegen.md)).

---

## Step 5: Partial Overrides and Patching of Composite Values — The Three-Tier Value Model and `.parts(...)`

### 1. Starting Point: Atomic Override Principle of Existing Flutter Value Types and the Need for Partial Patching

Under Flutter's existing API design, most style value types (such as `BorderSide`, `EdgeInsets`, `Color`, and `Size`) have non-nullable fields and, in principle, only support **atomic whole-value replacement**—which is why the derivation in the first four steps treated each style field as a single atomic unit of replacement without discussing sub-property merging.

Among native Flutter value types, the only one with built-in sub-property merging is **`TextStyle`**: by design, all of its visual property fields (such as `color`, `fontSize`, and `fontWeight`) are nullable, where `null` already means "unspecified; inherit from upstream style (`merge`)." Consequently, modifying literal sub-properties on `TextStyle` requires no new mechanism at all—writing `.values(textStyle: TextStyle(fontSize: 16))` in an earlier rule and `.values(textStyle: TextStyle(color: red))` in a later rule naturally performs a partial override across non-null fields (note: during rule merging, **`TextStyle(inherit: false)` is deliberately ignored** rather than treated as a whole-value replacement flag that wipes out earlier sub-properties; see [Section 6.3](06-design-details-and-codegen.md) for details). As for icon styling, the legacy `IconThemeData` is a holdover `ThemeData` class; in the new system, as the `Icon` widget joins the rule system and generates its own **`IconStyle`** class (where all fields are likewise nullable and `null` means `unset`), icon styles naturally merge field-by-field just like `TextStyle` and other nested sub-component `XStyle` classes.

Beyond these naturally mergeable literals, however, component library maintenance and everyday customization repeatedly run into two high-frequency needs around multi-component composite values that direct literal passing cannot solve:
1. **Partial overrides (local patching) on common non-null composite types composed of independent values, such as `BorderSide` and `EdgeInsets`**: For example, `OutlinedButton` defines `side: BorderSide(width: 1.5, color: outline)` in its base rule, and in the `focused` state or a custom theme, a developer wants to change only the border's `color` while preserving the existing `width: 1.5`. Because Flutter's `BorderSide` constructor assigns non-null defaults to every parameter (`width = 1.0`), passing `BorderSide(color: brand)` directly is an easy trap that resets the stroke width back to `1.0`. Similarly, for frequently written padding types like `EdgeInsets` and `EdgeInsetsGeometry`, if partial overrides are unsupported, changing only horizontal padding (`horizontal`) while preserving top and bottom padding (`vertical`) becomes painful. (By contrast, the channels of a `Color` act as components of a single color value, and an audit of a large codebase showed that 100% of the 7.3% alpha adjustments in button styles multiplied an explicit source color by an opacity factor—covered by Step 4's `.opacity(source, factor)`—with zero use cases of "keep the previous rule's color and only replace its alpha.")
2. **Binding derivation references to individual sub-properties of a composite value during a partial override**: Even for naturally mergeable types like `TextStyle` and `IconStyle`, native `TextStyle(color: ...)` constructor parameters only accept concrete `Color` literals and cannot hold a derivation reference like `.fromField(.foregroundColor)`. Yet component default rule tables frequently need a base rule to define font size and weight while having `textStyle.color` and `iconStyle.color` dynamically track the button's `foregroundColor`.

Therefore, on top of the core model established in the first four steps, a unified **partial override (`.parts(...)`)** mechanism for common composite values is introduced as an **independent extension feature**. It is important to distinguish the two concepts clearly: **Step 4's "Declarative Derivation" solves how a property's value is dynamically computed from sibling fields or global tokens, whereas Step 5's "Partial Override" ensures the rule model does not get in the way of ergonomic component style API design.** If the model could not cleanly support partial overrides on composite values, component authors designing `XStyle` would be forced into an unpleasant dilemma between banning composite values altogether (flattening `BorderSide`, `EdgeInsets`, and even `TextStyle` into top-level scalar fields) and keeping composite values that are frustrating to use (where changing a border color forces you to re-specify stroke width, or sub-properties cannot reference tokens).

### 2. The Three-Tier Value Model (`Mergeable` / `Patchable` / `Atomic`) and `.parts(...)`

A naive way to support partial overrides on types like `BorderSide` and `EdgeInsets` would be to invent a parallel mirror class with all-nullable fields for each of them (such as `BorderSideStyle` and `EdgeInsetsStyle`). However, doing so would not only invasively alter public APIs in `flutter/painting`, but also saddle every composite type with two nearly identically named classes that differ only by a suffix yet have completely different merge semantics (and abstract base classes like `EdgeInsetsGeometry` cannot be mirrored that way at all).

Instead, **native Flutter value types are kept unchanged**. At the syntax level, the wrapper parameter slots of `style: .derive(...)` (i.e., `XStyleSpec`) are reused, a projection-patching constructor **`.parts(...)`** is provided on the dedicated source subclasses of composite fields (placed inside `.derive(...)` simply because the parameter static types of `.values(...)` are the native value types themselves and cannot accept partial patch descriptors or sub-property derivation sources), and all style property value types are partitioned cleanly into a **three-tier value model**:

1. **`Mergeable` types — `TextStyle`, `IconStyle` (replacing `IconThemeData`), and all nested sub-component `XStyle` classes**:
   - **Characteristics**: All fields on the value type itself are nullable, and `null` means "unspecified; retain the result from earlier rules" (recursively applying Step 1's `null = unset` rule inside the value type; once an earlier rule sets a sub-property, later rules cannot reset it back to `null`, and `TextStyle(inherit: false)` is ignored). In the large codebase audit, 89% of the 5,620 `textTheme.X.copyWith(...)` calls only modified color, which merges directly across non-null sub-properties when written as `.values(textStyle: TextStyle(color: red))`.
   - **Usage**: When modifying only literal sub-properties, no special wrapper is needed—pass a plain instance directly inside `.values(...)`. When a sub-property needs to bind to a derivation reference, use **`.parts(...)`** inside `.derive(...)`:
     ```dart
     style: .derive(
       iconStyle: .parts(color: .fromField(.foregroundColor)),
       textStyle: .parts(color: .fromField(.foregroundColor)),
     )
     ```
2. **`Patchable` types — hand-picked `BorderSide` and `EdgeInsets`**:
   - **Characteristics**: Fields on the value type itself are non-nullable (representing a combination of independent values), so passing a literal instance inside `.values(...)` retains the exact **whole-value replacement** semantics of existing Flutter. However, the code generator emits dedicated source subclasses with **`.parts(...)`** for these two high-frequency composite types (such as `ButtonBorderSideSource`), allowing rules inside `.derive(...)` to patch only specific sub-properties or shorthand components (accepting either `.value(...)` literals or derivation references) while unmentioned components automatically carry over from earlier rules on the chain:
     ```dart
     style: .derive(
       // Patch only the border color (accepts a .value(red) literal or a .fromToken / .fromField derivation), preserving stroke width from earlier rules:
       side: .parts(color: .fromToken(.primaryColor)),
     )
     ```
   - The common types currently included in `Patchable` and their `.parts` parameters are:
     - **`BorderSide`**: `.parts(color:, width:, style:, strokeAlign:)`;
     - **`EdgeInsets`**: `.parts(left:, top:, right:, bottom:, horizontal:, vertical:)` (where `horizontal` sets both left and right, and `vertical` sets both top and bottom; for whether the abstract base class `EdgeInsetsGeometry` should also be included, see [Section 6.3](06-design-details-and-codegen.md)).
3. **`Atomic` types — the default tier for all remaining value types (such as `Color`, `double`, `AlignmentGeometry`, `MouseCursor`, etc.)**:
   - **Characteristics**: Support whole-value replacement only, using the generic `XSource<T>` (or the color transform subclass `XColorSource` for `Color`) inside `.derive(...)`.
   - **Deliberately keeping the initial API surface small with a smooth upgrade path**: Not providing `.parts` for `Color` (such as `.parts(alpha:)`) or other types is **not an architectural limitation, but a deliberate choice to keep the initial API surface small where real-world demand is low**. By design, the model supports upgrading any type from `Atomic` to `Patchable`: simply changing that slot's source type in `XStyleSpec` from the generic `XSource<T>` to a dedicated subclass with `.parts` leaves both the component property's value type and all call sites using dot shorthands unaffected. If reviewers feel certain additional types (or `Color.parts(alpha:)`) merit support—or feel the assumption that apps widely use dot shorthands is too strong and worry about breaking changes when narrowing slot types later—`.parts` can be generated for them directly in the initial release.

### 3. Rule Idempotence Principle and Technical Details Deferred to Section 6.3

To keep cross-frame rule-chain caching, debug provenance, and static default-table checks simple and reliable, all partial merges and patches obey one fundamental axiom: **rules must be idempotent**—applying the exact same rule twice in a row on a chain must produce the exact same result as applying it once ($f(f(v)) = f(v)$).

It immediately follows that **any operation reading the result of earlier rules on the same field can only be a projection replacement (i.e., `.parts`: replacing specified components with new values while retaining earlier results for all other components)**. The system does not provide non-idempotent operations such as "add `2.0` to the previous stroke width (`prev + delta`)" or "pass the previous result into an arbitrary callback (`.inherited()`)" (note: Step 4's `.opacity(source, factor)` computes opacity against the `source` explicitly given in the current rule without reading the previous rule's value on the same field, so it is naturally idempotent).

Further low-level technical details of the three-tier value model—including why `Mergeable` types do not support clearing sub-properties set by earlier rules and why they ignore `TextStyle(inherit: false)`, the public getter reconstruction requirements for `Patchable` types, and the **two design options (Option A vs. Option B) for whether the abstract base class `EdgeInsetsGeometry` should also be made `Patchable`**—are covered in detail in **[Section 6.3](06-design-details-and-codegen.md)**.

---

## Step 6: Tree Distribution, Per-Component Channel Notifications, Cross-Route Rule Capture, and Call-Site Design

### Top-Level `StyleTheme`, Local `StyleScope`, and Per-Component Channel Notifications via `InheritedModel`

The new model no longer defines a separate `XTheme` widget and `XThemeData` class for each component. Only two theme containers exist on the widget tree:
- At the root (typically mounted inside `MaterialApp` or `CupertinoApp`), **`StyleTheme(rules: [...], child: ...)`**;
- For local overrides within a subtree, **`StyleScope(rules: [...], environment: ..., child: ...)`**.

Neither a centralized `FThemeData` monolith aggregating all component fields like `Forui` nor a generic `ComponentTheme<ButtonStyle>` per component like `shadcn_flutter` is adopted:
- A centralized theme object statically couples all component style classes together, defeating tree-shaking (see [Section 7.2](07-engineering-validation.md) for details) and causing coarse-grained rebuild notifications on local tweaks;
- A generic `ComponentTheme<T>` requires nesting multiple widgets whenever a local scope adjusts several components at once, and makes it difficult to statically traverse unknown generic types during cross-route `InheritedTheme.capture`.

Therefore, `StyleScope(rules: [...])` accepts a `List<StyleRule>` mixing rules for any number of components. Each component rule `XRule` implements a virtual method `addTo(RuleChannels)` that routes the rule into its component's dedicated channel when building the chain (without relying on `runtimeType` reflection or a central dispatch `switch` table).

Under the hood, `StyleScope` is built on Flutter's **`InheritedModel`**, where each component channel maps to an independent aspect (plus one global token aspect):
- Inside `build()`, a component subscribes only to its own channel (for example, `Button` subscribes only to the button channel);
- When a `StyleScope` updates a `ButtonRule`, `InheritedModel.updateShouldNotifyDependent` compares the persistent linked-list nodes (`ChannelLink`) for each channel: **only `Button` widgets subscribed to the button channel rebuild, while `Switch` and `Slider` widgets in the same subtree experience 0 rebuilds**.
- Each `StyleScope` node maintains a **persistent singly linked list** per channel pointing to the parent node's corresponding channel (if a `StyleScope` level does not touch a given component channel, it reuses the parent's `ChannelLink` pointer directly, skipping empty nodes in `O(1)` time). Resolution traverses from the inside out, turning "last rule wins" into "first rule encountered wins" and terminating the scan early as soon as all fields are resolved.

### Propagating Local Rules Across Routes and Overlays

When launching an overlay or dialog from inside a local `StyleScope`, the two mounting mechanisms work as follows:

- **`OverlayPortal`-based overlays** (such as `Tooltip` and `MenuAnchor`): Because they remain children of the call site on the Element tree, they naturally inherit and react live to the call site's entire `StyleScope` chain.
- **Dialogs pushed as standalone routes via `Navigator.push`** (such as `showDialog`, `showCupertinoDialog`, and bottom sheets): The dialog route mounts under the target `Navigator`, detaching from the call-site subtree. To handle this, the internal `InheritedModel` of `StyleTheme` and `StyleScope` implements `InheritedTheme`. When a dialog route calls `InheritedTheme.capture`, **it packages only the local `StyleScope` chain accumulated from outside in at the call site into a static snapshot replayed onto the new route, while excluding the root `StyleTheme` from the snapshot** (as long as `StyleTheme` is mounted above the `Navigator`, the dialog reads it live from the root of the tree).

This design—capturing a full-chain snapshot of local `StyleScope`s while reading the root `StyleTheme` live—naturally fixes two structural defects that are very difficult to patch in the existing theme model:
1. **Eliminates lost ancestor properties when capturing multi-level local themes ([#196177](https://github.com/flutter/flutter/issues/196177))**: Existing `InheritedTheme.capture` only captures the single nearest instance of each `InheritedWidget` type (and `InheritedTheme` has no cross-node merging protocol), causing an inner `IconButtonTheme` to silently drop properties set by an outer ancestor `IconButtonTheme` after cross-route capture. In the new model, every `StyleScope` node already holds the persistent outer-to-inner singly linked rule chain, so capturing preserves the entire local chain intact and maintains exact incremental per-field stacking semantics across routes.
2. **Local customization and live global updates are no longer mutually exclusive ([#106642](https://github.com/flutter/flutter/issues/106642))**: In the existing system, if the call site has even a single local `Theme` override, `InheritedTheme.capture` freezes the entire merged `ThemeData` at that moment into a static snapshot wrapped around the new route. If the global theme updates dynamically (or switches between light and dark modes) while the dialog is open, the dialog is locked inside the frozen snapshot and fails to respond. In the new model, only the incremental rule snapshot from local `StyleScope`s is captured; the root `StyleTheme` (mounted above `Navigator`) and the brightness environment dimension from the route context remain live, so the dialog preserves call-site local customizations while reacting in real time to global theme changes. (To make this work across all dialogs, the missing `InheritedTheme.capture` calls in `flutter/framework`'s multi-window `DialogWindow` and `cupertino_ui` dialog entry points such as `showCupertinoDialog` and `showCupertinoModalPopup` will also be filled in.)

### Sub-Parts of Composite Components: Explicit Slot Fields

For composite components that contain internal sub-parts, such as `AlertDialog` and `DatePicker`, CSS-style descendant selectors are avoided; instead, sub-parts are handled in two categories based on their nature:
1. **Non-standalone internal visual parts** (such as a `Switch`'s thumb, a `Slider`'s track, or a `DatePicker`'s year cell): Defined directly on the parent component's `XStyle` as prefixed plain fields (such as `thumbColor`, `trackColor`, and `yearCellBackgroundColor`).
2. **Semantic slots that reuse standalone public components** (such as the confirm and cancel buttons inside a `DatePicker`): Declared on the parent component's `DatePickerStyle` as slot fields `confirmButton: List<ButtonRule>?` and `cancelButton: List<ButtonRule>?`. When the parent component builds the confirm button subtree, it wraps that slot internally in a local `StyleScope(rules: resolvedStyle.confirmButton)`. This reuses the exact same `ButtonRule` type while strictly scoping the rules to that specific slot, without leaking into other regular `Button` widgets inside the dialog's content area.

### Call-Site Design: Constructor Flat Parameters, `states:`, and Dynamic Colors

**1. Curated Flat Parameters + `states:` Local Rules**
Widget constructors do not accept a raw `XStyle` object directly, nor are their flat parameters auto-generated. Instead, component maintainers hand-pick the most commonly customized properties and state regions from the rule regions partitioned in Step 3 and expose them as flat constructor parameters (such as `color` and `disabledColor` on `Button`, or `thumbColor` and `inactiveThumbColor` on `Switch`), all typed as plain nullable values like `Color?` and `double?`. Inside the component, the maintainer maps these flat parameters to call-site rules by calling the generated region constructors (for example, mapping `Button`'s `color` to the enabled regions so it never clobbers the default `disabled` style) and places them **ahead of** the call site's `states: [ButtonRule...]` parameter.

As a result, simple everyday call sites never need to touch `states:`. When an individual widget instance needs to tweak its pressed or hovered state, the developer simply appends a rule for that state in `states:`, while the resting value set via flat parameters and all other states from the default table are automatically preserved.

**2. Native Support for `CupertinoDynamicColor` (CDC), Uniformly Decomposed by the Engine at Chain-Building Time**
Although Section 2.1 highlighted how legacy `CupertinoDynamicColor` is easily left unresolved by components, the new model continues to support passing `CupertinoDynamicColor` (such as `CupertinoColors.systemRed`) directly into any `Color` parameter or slot, without forcing developers to manually write two separate `XRule`s for `brightness: .light` and `brightness: .dark`.

The reason is straightforward: **unlike ordinary interactive states, light and dark modes (`light` / `dark`) assign different RGB values to the vast majority of colors in a well-crafted modern app.** If passing dynamic colors directly were not supported, developers would have to rewrite every color argument in flat constructor parameters or region constructors into multiple conditional rules whenever they wanted to support dark mode, dramatically increasing the authoring burden of dark-mode adaptation.

Structurally, `CupertinoDynamicColor` is not an opaque black-box closure, but a `const` pure data object containing **8 fixed environment slots** (`brightness × highContrast × interfaceLevel`), where a plain `Color` is simply the special case in which all 8 slots hold the same value.

It is therefore handled uniformly during the engine's **chain-building flattening phase**: whether a developer passes a `CupertinoDynamicColor` in a widget's flat parameter, a region constructor, an `XRule`'s `style:`, or a global token, the engine **decomposes and expands it at chain-building time into plain `Color` sub-rules carrying the corresponding environment conditions** (if the outer `XWhen` already specifies `brightness: .dark`, expansion automatically intersects the conditions and extracts only the dark slots). Once expansion finishes, both the evaluation engine internals and the component's `build()` method receive plain `Color` instances exclusively, and component implementations never need to call `CupertinoDynamicColor.maybeResolve` by hand.

Note: If a developer calls `cdc.withValues(alpha: 0.5)` on a dynamic color before passing it into a component, it already degrades to its light variant outside the system; such cases should instead use `.opacity(.value(cdc), 0.5)` or `.opacity(.fromToken(...), 0.5)`. If a dynamic color is placed inside an unknown custom nested container (such as a custom `Gradient`), the static expandability check during chain building throws an assertion error in debug mode pointing to the exact field path.

**3. Treatment of `WidgetStateProperty` (`WSP`) in Constructor Parameters**
In existing Material components, per-instance state branches are often expressed by typing widget constructor parameters as `WidgetStateProperty<T?>?` (such as `Checkbox.fillColor` and `Switch.thumbColor`). In the new system, the `WidgetStateProperty` class in `flutter/framework` remains unchanged, but a clear line is drawn regarding its role in widget constructors: **new constructor parameters uniformly replace `WSP` with plain value types paired with `states:`, while existing `WSP` parameters are preserved intact for backward compatibility.**

For new components in `cupertino_ui` and all newly added parameters, constructor parameters uniformly use plain value types `T?` paired with `states:` rather than accepting `WSP`, for three reasons:
- **More direct authoring**: Modifying a single field uses a region constructor (such as `states: [.trackColor(selected: purple)]`), where the default table's state partitions appear directly as named parameters and unmentioned states automatically keep their defaults; modifying multiple fields simultaneously requires writing the condition only once in `.when(...)`, without writing separate `resolveWith` closures for each property.
- **Can be declared `const` and hit caches**: Rules inside `states:` support `const` and value equality, hitting caches directly across rebuilds; by contrast, inline `resolveWith` closures allocate a new instance on every `build` and trigger rule-chain reconstruction (measured at ~26µs vs. 1.6µs per frame for a single `Button` in the prototype), and rules containing closures cannot enter the binding cache.
- **Compile-time state validation**: `WSP` is tied to the globally shared `WidgetState` enum, so it cannot prevent developers at compile time from writing unsupported state branches for a component, nor can it express component-specific `appearance` or `size` dimensions.

This design comes with an explicit **expressiveness tradeoff**: because condition types in the new model (`ButtonWhen`, `ChipWhen`) are generated per component, developers cannot define a single cross-component `WidgetStateProperty<Color>` variable and pass it simultaneously to `Button`, `Chip`, and `Checkbox` as in the legacy system. Sharing concrete color values across components is handled by `TokenGroup`, but sharing a "state-to-value mapping function itself" across different component types has no direct equivalent in the new model. This tradeoff is made deliberately in exchange for component-specific dimension expressiveness and compile-time state checking.

Meanwhile, for **existing `WSP` usages in `material_ui`**—including both `WSP` parameters on widget constructors (like `Checkbox.fillColor` and `Switch.thumbColor`) and **`WSP` fields on `ThemeData`, `XThemeData`, and legacy `ButtonStyle`**—all existing APIs are **preserved intact** without breaking changes as part of `material_ui`'s overall backward-compatibility strategy. Internally, the system automatically bridges incoming `WSP` instances into compatibility rules at the corresponding level (`WidgetStateMap` expands directly into regular declarative rules, while `resolveWith` closures are wrapped as compatibility rules evaluated on demand), working seamlessly alongside the new `states:` parameter and `StyleTheme` / `StyleScope` rule chains. For the complete compatibility and migration mechanism covering legacy `WSP` in widget constructors and `ThemeData` within `material_ui`, see **[Section 8.2](08-rollout-and-migration.md)**.

---

[← Previous: 3. Design Goals and Evaluation of Existing Options](03-requirements-and-existing-options.md) | [Back to Index](00-intro.md) | [Next: 5. End-to-End Code Walkthrough →](05-walkthrough.md)
