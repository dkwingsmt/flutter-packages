# A Component Theming Model for Flutter (Quick Version)

> Working draft for internal team discussion. Class names are temporary placeholders; final naming will be decided separately. For the full derivation, engineering benchmarks, and migration plan, see the [full design document (`design-doc/00-intro.md`)](design-doc/00-intro.md).

## TL;DR

Flutter's current component theming model has structural flaws. In `material_ui`, themes and widget constructors maintain two separate hand-written field lists, and interaction states hang off individual properties, causing layered overrides to wipe each other out. `cupertino_ui` is in a worse spot: interaction states and brightness/contrast use two separate resolution mechanisms that do not compose, so user-supplied colors regularly render with the wrong brightness in dark mode.

This article proposes a new model: each component has a single style class, and every visual variation—interaction states, appearance variants, brightness, and contrast—is expressed as the same kind of conditional pure-data rule. Flat widget constructor parameters remain convenient shortcuts for common properties and read just like they do today; you only write rules when you need to target a specific state or link properties together.

The Liquid Glass component set in `cupertino_ui` is being written from scratch and has no existing theming users. That opens a rare window to adopt this model without a migration, making it the natural place to start. `material_ui` needs a smooth migration and coexistence path, which the full design doc lays out in detail.

## The Problem

Start with `material_ui`. Every customizable property on a component is written twice: once on the widget constructor and once on `XThemeData`, with each widget manually wiring `widget.x ?? theme.x ?? defaults.x`. Adding a single property touches 9 places. The goal has always been parity between widget parameters and theme fields, but two hand-maintained lists inevitably drift apart: `ProgressIndicatorThemeData` was missing `strokeWidth`, `borderRadius`, and several other properties for over a year before it was fixed ([#131690](https://github.com/flutter/flutter/issues/131690)); `TextField` has a `style` parameter for input text, yet its theme still has no corresponding field—changing the input font globally requires passing `style` at every call site ([#118267](https://github.com/flutter/flutter/issues/118267), still open).

State handling is an even subtler trap. `WidgetStateProperty` bundles "what value to use in each state" inside an opaque closure. Closures cannot be compared by value (creating a new closure on rebuild makes `ThemeData ==` evaluate to `false`, triggering unnecessary subtree rebuilds and spurious interpolation animations; see [#89127](https://github.com/flutter/flutter/issues/89127)), and they cannot be merged by state. If a theme author only wants to change a button's hovered background color, they have to replace the entire closure; if they forget the `disabled` branch, disabled buttons no longer look disabled. Derived relationships between properties (for example, an icon's color following `foregroundColor`) are hard-coded inside each widget's `build` method. Theme authors cannot see or customize those relationships, and during `ThemeData.lerp` interpolation animations, intermediate frames produce non-null translucent colors that short-circuit the `iconColor ?? foregroundColor` null fallback.

`cupertino_ui` fares no better. Its components use `WidgetStateProperty` to resolve interaction states and `CupertinoDynamicColor` to resolve brightness and contrast. Which step runs first—or whether it runs at all—is hand-written per property in every widget. While built-in default colors are mostly resolved properly, user-supplied colors frequently skip brightness resolution. `CupertinoSwitch` is the clearest example: pass a dynamic color with distinct light and dark values under a dark theme, and `trackOutlineColor`, `activeTrackColor`, and `thumbColor` all render their light-mode values. The same bug affects `fillColor` and `checkColor` on `CupertinoCheckbox`, and even `foregroundColor` and `focusColor` on `CupertinoButton`—silently, with no errors. I have confirmed all of these with tests.

Both packages suffer from the same underlying structure: interaction states and environment dimensions are attached to individual properties as wrapper types. In theory, every property could support every dimension from day one, but then callers would have to wrap every value they pass (such as `WidgetStatePropertyAll(...)`), which nobody wants to write. In practice, state support is only added to a handful of properties up front and retrofitted onto others one by one as users file issues. Every upgrade changes a property's type from `Color` to `WidgetStateProperty<Color>`, rippling through constructor parameters, theme fields, `lerp` and `merge`, and every call site that reads it—much like function coloring. To avoid breaking changes, Flutter either keeps twin parameters side by side (like `activeColor` alongside `fillColor` on `Checkbox`, or `activeTrackColor` alongside `trackColor` on `Switch`, each requiring its own precedence rules) or disguises the wrapper type as a `Color` so callers don't have to wrap values, sacrificing type safety in the process. Both `WidgetStateColor` and `CupertinoDynamicColor` take the second route, which is directly responsible for the switch bugs above. Retrofitting dimensions onto one property at a time drains both user effort and engineering bandwidth, and every new dimension multiplies that cost. This model does not scale.

Stepping back, what a theming system actually does is merge: a component's appearance comes from the design spec (library defaults), the app designer (global theme), a specific screen (subtree override), and the widget call site, and all of those intents must merge into a single result. Merging requires one canonical field list, pure data values that can be compared and merged, a unified way to express conditions across every dimension, and unambiguous precedence. The current model lacks all four. Hand-wiring bugs are just a symptom; the deeper issue is that it is impossible to design a clean API on top of this structure that satisfies all of these requirements at once.

## Direction

The proposed approach flips the table around. You can think of a component's appearance as a "property × state" matrix: today, each property carries its own values across all states; in the new model, you group by state instead. A component's **style** (`XStyle`) is the collection of all its customizable properties—just data fields, no resolution logic, and every field holds a plain value (`null` solely means "unset here; fall back to earlier rules"). Visual variations are written as **rules** (`XRule`): each rule pairs a condition with a style, meaning "when this condition holds, set these properties to these values."

A condition is made up of **dimensions**. Interaction states (`hovered`, `pressed`, `disabled`) are dimensions; component appearance variants (such as a button's `appearance`) are dimensions; built-in environment settings like brightness (`brightness`) and contrast (`highContrast`) are dimensions too. Expressing "foreground color when pressed in dark mode" works the exact same way as "foreground color when pressed"—it just constrains one more dimension in the condition. The composition bug in `cupertino_ui` disappears because everything resolves in a single pass. Every dimension in a condition is optional, and omitting one means "unconstrained," so adding a new dimension later just adds an optional parameter to the condition without changing the meaning of existing rules or causing a breaking change.

Components no longer have a separate `XThemeData` class—only a style class and a rule class—and a theme is simply a list of component rules. Library defaults, the global theme (`StyleTheme`), subtree overrides (`StyleScope`), call-site flat parameters, and call-site `states:` rules concatenate in that order into a single chain where later rules win. Subtree overrides no longer replace the outer theme wholesale; they append to the outer rules. The chain merges independently per property; for composite properties like `TextStyle`, `BorderSide`, and `EdgeInsets`, the engine supports sub-property merging or partial patching via `.parts(...)` so the rule model never gets in the way of using composite value types in style APIs.

`XStyle`, the condition class `XWhen`, and the rule class `XRule` (including **region constructors** like `ButtonRule.backgroundColor(tintedEnabled: ...)` automatically partitioned from the default rule table) are generated from a single declarative definition and cover every customizable property on the component, so themes never miss a field. For widget constructors, maintainers hand-pick the most common properties from those automatically partitioned rule regions and expose them as flat parameters. Everyday call sites read just like they do today, while under the hood those flat parameters call the generated region constructors to target the appropriate state regions without clobbering dedicated states like `disabled`. For properties not exposed on the widget constructor, or when you need fine-grained state control, you write `states:` at the call site or add rules to the theme. The goal is to preserve what Flutter has always been good at: simple things stay simple, and complex things always have a clear place to go.

The model also supports declarative derivations directly in rules. Defaults or themes can declare inside `style: .derive(...)` that "this property takes the final resolved value of another property on the same component" (`.fromField`, such as making icon color follow foreground color) or "this property reads a global token" (`.fromToken` / `.fromCustomToken`), and can multiply a color source by an opacity factor (`.opacity(source, factor)`) or pass a pure callback function (`.computed`). Beyond built-in color and typography tokens, apps can define their own custom `TokenGroup`s for brand colors and semantic roles with minimal code (replacing boilerplate-heavy `ThemeExtension`s), configure them by brightness, declare cross-token derivations, and read non-null values directly in both component rules and ordinary widgets. Because these derivations and references are `const` pure data rather than hard-coded expressions inside a widget's `build` method, theme authors can see them and override or rewire them at any time with ordinary rules.

## Why Now, and Why Start with `cupertino_ui`

`cupertino_ui` has almost no component theming today: `CupertinoThemeData` takes 8 inputs and has zero per-component themes. Historically, limited staffing kept the focus on out-of-the-box fidelity—how widgets look with no configuration. Legacy Cupertino widgets will eventually be removed without retrofitting themes onto them; the upcoming Liquid Glass widgets, however, must have a component theming layer, and the only question is whether to design it around the old pattern or the new model.

The Liquid Glass widgets are being built from scratch right now, and widget-specific theme APIs are scheduled for Phase 4. Until then, no users depend on theming for these widgets—making this the only window to establish a theming paradigm without a migration. Arriving at Phase 4 without a new model means taking the path of least resistance and copying `material_ui`'s `XThemeData` + `WidgetStateProperty` pattern, repeating every problem listed above in a brand-new set of components: drifting field lists, clobbered state closures, and dimensions retrofitted one property at a time.

`material_ui` and `cupertino_ui` have always aimed to share a consistent programming paradigm, a tradition worth continuing, so `material_ui` needs to follow too. It cannot switch overnight: existing framework and third-party widgets still read `ThemeData`, so the new model must coexist with it. Because both packages can now make major releases and the new model is designed to stay close to familiar Flutter idioms, a staged migration is realistic; see [Section 8 of the full design doc](design-doc/08-migration-plan.md) for the complete plan.

## Current Status

The rule layer has a working prototype validated against the defaults of 17 core component groups in `material_ui` (including M3 Expressive variants): after expressing the defaults as `const` declarative rules, I compared every field across all reachable state combinations and 6 color schemes—2,134,974 comparisons with 0 diffs, in about 29% of the lines of code of the original `_XDefaultsM3` implementations (1,017 lines vs. 3,529 lines). The evaluation engine uses two-stage caching (symbolic resolution cache + token-bound cache): across a 60-frame theme interpolation animation, the symbolic cache hits 100% after the first frame, cutting per-frame evaluation time to roughly one-third of rebuilding rules every frame.

The widget-layer prototype is also complete, covering `StyleTheme`, `StyleScope`, per-component channel notifications built on `InheritedModel` (updating button rules does not rebuild switches in the same subtree), and cross-route rule capture. To validate against an existing baseline pixel for pixel, the prototype implements unprefixed `Button` and `Switch` widgets using the visual specifications of the existing Cupertino button and switch (matching the naming of future widgets—note that legacy widgets will not receive theme retrofits; the prototype only borrows their visuals as a pixel-level regression baseline). Default appearances and flat parameters match the original widgets pixel for pixel across every appearance, size, state, and all 8 environment combinations (448 default cases + 304 flat-parameter cases); the only difference in default rendering is fixing the bug where the original focus ring failed to resolve dynamic colors.

## Main Trade-offs

* **Authors writing raw `When` conditions must mind the scope of order-based overrides.** Rules evaluate strictly in order (last write wins), so a broad `.when(...)` condition written by hand will overwrite narrower state branches from earlier rules on the same property (for example, writing `disabled: false` in a local scope will overwrite a `pressed: true` value set on the same property by an outer theme). To mitigate this, the code generator **automatically partitions** each property based on the component's default rule table and generates per-property region constructors on `XRule` (such as `ButtonRule.backgroundColor(tintedEnabled: ...)` and `SwitchRule.trackColor(selected: ...)`). Callers do not need to derive condition boundaries by hand: IDE autocomplete shows the existing state partitions for that property and lets you override the exact region you want, making everyday single-property state customization more direct than writing `resolveWith` branches. Authors only need to reason about condition boundaries themselves when an outer theme introduces custom state branches beyond the default rule table, or when writing complex multi-property `When` rules by hand.
* **API conciseness relies heavily on Dart 3.10 dot shorthands.** Rules, styles, and derivations involve several generated classes (`ButtonRule`, `ButtonStyleSpec`, `ButtonSource`, `ButtonField`, and so on). Spelling out full class names everywhere makes call sites verbose, whereas using dot shorthands like `.when(...)`, `.values(...)`, and `.fromField(.foregroundColor)` across the board conflicts with the current Flutter repository style guide rule against dot shorthands in positional arguments. The proposed plan is to have the generator emit full class names inside `material_ui` and `cupertino_ui` default rule tables to comply with framework repository rules, while using dot shorthands in user-facing API docs and examples (see [Section 9.5 of the full design doc](design-doc/09-topics-and-tradeoffs.md) for a detailed assessment).
* **Migrating `material_ui` is a large effort and requires long-term coexistence with `ThemeData`.** To keep migration risk under control, this proposal includes a two-way bridge layer and lazy-evaluated compatibility rules for `resolveWith`, ensuring that migrated components behave identically to their legacy versions when no new rules are configured and allowing incremental migration one component family at a time (see [Section 8 of the full design doc](design-doc/08-migration-plan.md)).

## Non-Goals

* **No theming infrastructure in `flutter/framework` (the `widgets` layer).** Existing framework mechanisms (including `WidgetStateProperty`) remain untouched. Theming belongs to the design-system layer (`cupertino_ui` and `material_ui`); the two packages share only the build-time code generator, while generated outputs live inside each package with no shared runtime engine classes.
* **No universal "one-size-fits-all Style class" across all components, and no goal of reducing the number of classes.** Each component keeps its own strongly typed `XStyle` and `XRule`, exposing only the properties and state dimensions that actually apply to that component (multiple widgets representing visual tiers of the same component, such as Material's five common buttons, can share a single `CommonButtonRule` and generate scoped subclasses like `OutlinedButtonRule`).
* **No theming retrofits for legacy Cupertino widgets being phased out, and no public code generator for custom app widgets.** The new model targets only next-generation components in the two first-party packages (such as Liquid Glass) and future `material_ui` (custom app-defined global `TokenGroup`s are not subject to this limitation and require no code generation).
* **Not a replacement for custom widget composition in app code, and no custom app-defined environment dimensions on `When`.** Domain-specific widgets like "a business button with debounce, loading overlay, and permission analytics" should still be encapsulated as custom `StatelessWidget`s in app code. For scenarios beyond the built-in environment dimensions (such as a third custom theme mode or screen breakpoints), the app reads the condition outside and switches the rule list passed to `StyleTheme` or `StyleScope`.

---

The sections below are aimed at readers who plan to read the full design doc.

## Design Skeleton

The code below shows how the new model addresses the core problems described earlier (for a complete walkthrough, see [Section 5 of the full design doc](design-doc/05-walkthrough.md)).

**1. Everyday call sites: keep common flat parameters, and replace closures with `states:` for per-state tweaks**

The vast majority of call sites only need flat parameters (82% of existing button styling lives at call sites, and 94% of it involves no state branching) and never touch rules. Widget constructors keep maintainer-curated flat parameters like `color` and `disabledColor` (or `thumbColor` and `inactiveThumbColor` on switches), and dynamic colors from `CupertinoColors` work as usual:

```dart
Button(
  appearance: ButtonAppearance.filled,
  color: CupertinoColors.systemRed,
  disabledColor: CupertinoColors.systemGrey4,
  onPressed: save,
  child: const Text('Save'),
)
```

Inside the component, flat parameters map to rules for their corresponding state regions via generated region constructors (for example, `color` only sets the enabled region without clobbering `disabled`, while `disabledColor` sets the disabled region) and sit ahead of `states:` from the same call site. When you need to tweak other states on a single instance, you pass just the states you want to change in `states:` using dot shorthands—without copying every state branch like in `WidgetStateProperty.resolveWith`—and the entire list remains a compile-time `const`:

```dart
Button(
  appearance: ButtonAppearance.filled,
  color: CupertinoColors.systemRed,
  states: const [
    // Region constructor (equivalent to the disabledColor flat parameter above):
    .backgroundColor(filledDisabled: CupertinoColors.systemGrey4),
    // Conditional rule: only append the multi-property change for pressed; all other states stay intact:
    .when(
      pressed: true,
      style: .values(
        foregroundColor: CupertinoColors.systemYellow,
        textStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  ],
  onPressed: save,
  child: const Text('Save'),
)
```

**2. Themes and local overrides: combine region constructors with conditional rules, and compose brightness with interaction states directly**

Rules concatenate into a single chain—`component defaults → StyleTheme → outer-to-inner StyleScope → call-site flat parameters → call-site states:`—where later rules win and each property competes independently. Use region constructors (`.backgroundColor(tintedEnabled: ...)`) when changing a single property's literal value within library-default state regions, and use `.when(...)` when changing multiple properties together under one condition or combining dimensions:

```dart
StyleTheme(
  rules: const [
    ...<ButtonRule>[
      // Region constructor: only change the tinted enabled background; default disabled styling stays intact
      .backgroundColor(tintedEnabled: CupertinoColors.systemTeal),
      // Conditional rule: change border radius across all non-disabled buttons
      .when(disabled: false, style: .values(borderRadius: 12)),
      // Dark mode + pressed: environment dimension and interaction state live in the same condition, resolved in one pass
      .when(
        pressed: true,
        brightness: .dark,
        style: .values(foregroundColor: Color(0xFFFFD60A)),
      ),
    ],
    ...<SwitchRule>[
      .trackColor(selected: CupertinoColors.systemTeal),
    ],
  ],
  child: CupertinoApp(
    home: StyleScope(
      // Local overrides append to outer rules: only change the filled enabled button background to orange
      // (dynamic colors automatically expand by environment), while the outer border radius, dark-pressed gold,
      // and tinted teal all remain intact.
      // Because this Scope only touches the button channel, Switches in the subtree do not rebuild.
      rules: const [
        ButtonRule.backgroundColor(filledEnabled: CupertinoColors.systemOrange),
      ],
      child: const CheckoutPanel(),
    ),
  ),
)
```

**3. Derivations, partial overrides, and custom `TokenGroup`s (replacing `ThemeExtension`)**

When a property needs to reference a sibling field on the same component (`.fromField`), read a global token (`.fromToken` / `.fromCustomToken`), apply an opacity transform (`.opacity`), or patch specific sub-properties of a composite value (`.parts`), replace `.values(...)` in `style:` with `.derive(...)`. Derivations evaluate lazily after the entire rule chain finishes merging:

```dart
// Component default rule: background color reads global primaryColor; icon and text colors follow the final resolved foreground color
const ButtonRule.when(
  appearance: {.filled},
  disabled: false,
  style: .derive(
    backgroundColor: .fromToken(.primaryColor),
    iconStyle: .parts(color: .fromField(.foregroundColor)),
    textStyle: .parts(color: .fromField(.foregroundColor)),
  ),
)
```

Because derivations evaluate after the entire rule chain merges, modifying `foregroundColor` at a call site (or overriding it only in dark mode) automatically updates the icon and text colors to match. If a theme wants to break that link, it can append a rule later in the chain that assigns a concrete color to `iconStyle`, and the later rule wins.

Beyond the built-in `CupertinoToken`, apps can define their own brand and semantic tokens using **one token enum + one write-side rule class**—with no need to hand-write `copyWith`, `lerp`, or a whole-group data class, since the engine's built-in interpolation table covers `Color`, `double`, `TextStyle`, and 99% of common types automatically:

```dart
// 1. Define the token enum (serves as both the reference key and the MyBrand.x.of(context) read entry point)
enum MyBrand<T extends Object> with GroupTokenMixin<T> {
  accent<Color>(),
  textPrimary<Color>(),
  textMuted<Color>();

  static const TokenGroup group = TokenGroup('MyBrand', values);
}

// 2. Define the write-side rule class (extend TokenValueRule when mainly passing literals, specifying only tokens that change)
final class const MyBrandRule({this.accent, this.textPrimary, this.textMuted, super.when})
    extends TokenValueRule {
  final Color? accent;
  final Color? textPrimary;
  final Color? textMuted;

  @override
  Map<Enum, Object> get values => {
    MyBrand.accent: ?accent,
    MyBrand.textPrimary: ?textPrimary,
    MyBrand.textMuted: ?textMuted,
  };
}

// 3. Configure per brightness and declare cross-token derivations in StyleTheme; read directly in component rules and ordinary widgets:
StyleTheme(
  groups: [MyBrand.group],
  rules: [
    const MyBrandRule(accent: teal700, textPrimary: ink),
    const MyBrandRule(when: TokenWhen(brightness: .dark), accent: teal200, textPrimary: paper),
    // Cross-token derivation: whichever layer overrides textPrimary, textMuted automatically recomputes at 60% opacity
    MyBrand.textMuted.setFrom(.opacity(.fromCustomToken(MyBrand.textPrimary), 0.6)),
    // Component rule referencing custom tokens:
    const ButtonRule.when(
      appearance: {.tinted},
      disabled: false,
      style: .derive(
        foregroundColor: .fromCustomToken(MyBrand.accent),
        backgroundColor: .opacity(.fromCustomToken(MyBrand.accent), 0.15),
      ),
    ),
  ],
  child: Builder(
    builder: (context) => Text(
      'Caption',
      // Read non-null value directly outside components:
      style: TextStyle(color: MyBrand.textMuted.of(context)),
    ),
  ),
)
```

## Anticipated Questions

**Why not adopt the design of Mix, Forui, or Compose's Styles API?** The question here is borrowing their design, not adding a dependency. `Mix` is a styling layer for custom atomic primitives; it has no concept of first-party component default rule tables or regions, and its method chains cannot be `const`. `Forui` is the closest to this proposal and proves that "one style class per component + code generation" works in Flutter, but it eagerly evaluates tokens into concrete values when constructing the theme, so it does not support symbolic lazy derivations, sibling-field references, or per-state partial merging. Compose introduced an experimental `Styles API` in 2026 that similarly shifts toward "per-component styles + state blocks wrapping properties," validating this direction, but its styles are runtime closures, whereas Dart's most important optimization is compile-time `const` canonicalization. See [Section 3](design-doc/03-requirements-and-existing-options.md) and [Section 9.1](design-doc/09-topics-and-tradeoffs.md) of the full design doc for a point-by-point comparison.

**How does this coexist with `ThemeData`?** It has to. Framework and third-party widgets will continue reading `ThemeData`, and migrating `material_ui` requires a transition period. During the transition, global `ColorScheme` and `TextTheme` sync bidirectionally with the token channel, existing `style: ButtonStyle?` parameters on widget constructors remain in place as `@Deprecated`, and existing `XThemeData` objects automatically bridge forward into rules. See [Section 8.2 of the full design doc](design-doc/08-migration-plan.md) for details.

**Will `WidgetStateProperty` in the framework be deprecated?** No—the `WidgetStateProperty` class in `flutter/framework` stays untouched. In the design-system packages, new components and newly added parameters in `cupertino_ui` no longer take `WidgetStateProperty` (replaced across the board by plain-value flat parameters paired with `states:`), while existing `WidgetStateProperty` usages in `material_ui` (including widget constructor parameters, `ButtonStyle`, and `XThemeData` fields) remain intact for backward compatibility and bridge into rules under the hood (`fromMap` expands into ordinary declarative rules, while `resolveWith` closures wrap into lazily evaluated compatibility rules).

**Why not just use `WidgetStateProperty.fromMap` everywhere (or extend per-property state maps with all dimensions)?** As it exists today, `fromMap` only solves closure inspectability: its keys are limited to the fixed `WidgetState` interaction states, so it cannot express component appearance variants (like `appearance`), environment dimensions (`brightness`, `highContrast`), or derived relationships like "icon color follows foreground color" (a codebase audit shows `fromMap` accounts for less than 2% of usages, while 98% still use `resolveWith`). If you add all of those dimensions and derivations into per-property state maps on `Style` (and since condition objects with custom `==` cannot be keys in a `const Map`, they would have to be written as lists of key-value pairs), the underlying model is already isomorphic to the rule model proposed here—the only difference left is whether to organize it as `state → properties` (flipped) or `property → state map` (unflipped). This proposal flips the table because a single state or variant (such as `appearance: .filled` or `disabled: true`) or a theme customization usually modifies foreground, background, radius, padding, and several other properties together: with `state → properties`, you write the condition once on the outside and every field inside `Style` is a plain `Color` or `double`; with `property → state map`, every field you touch has to wrap its own state table and repeat the same condition over and over.

**What happens to Cupertino's dynamic colors?** Flat widget constructor parameters, region constructors, rule `style`s, and global tokens can all accept `CupertinoDynamicColor` values like `CupertinoColors.systemRed` directly (under the hood, a `CupertinoDynamicColor` is a `const` data object with 8 fixed environment slots). When building the rule chain, the engine automatically expands dynamic colors into environment-conditioned plain-`Color` sub-rules (intersecting with any environment condition already present on the outer rule). By the time evaluation and painting run, every color is a plain `Color`, so individual widgets never have to call `resolveFrom` by hand.

**What about performance and binary size?** Rules, conditions, and declarative derivations are all `const` pure data that support value equality; two-stage caching gives a 100% symbolic cache hit rate after the first frame during 60fps theme animations; and `StyleScope` uses `InheritedModel` to notify rebuilds per component channel. Architecturally, the design forbids any central registry that references all component types: a component's default rule table is referenced only by the component itself, allowing unused components, their rule classes, and their region constructors to be tree-shaken by the compiler (measurements show 0 bytes for unused region constructors across AOT, Web, and Wasm, and ~21 bytes per region in AOT when all regions are referenced). See [Section 7 of the full design doc](design-doc/07-engineering-validation.md) for details.

**Does this rely on code generation?** Yes, and that is an intentional design choice. `material_ui` already uses `gen_defaults` to generate default values, and many existing bugs come directly from forgetting to update one of the 9 hand-synchronized boilerplate locations. The generator produces `XStyle`, `XRule`, `XWhen`, and region constructors from a single source of truth and checks them into the repository, so downstream app developers never run a build-time code generator (and custom `TokenGroup`s are lightweight hand-written classes that require no code generation either).

## What the Full Design Doc Covers

The full design document lives in [`design-doc/`](design-doc/00-intro.md) and is organized into the following chapters:
1. **[Context and Scope](design-doc/01-context-and-goals.md)**: The Liquid Glass opportunity, the boundary between sharing a generator at build time and staying independent at runtime, and the four non-goals.
2. **[Problem Analysis of the Current Model](design-doc/02-problems.md)**: Why `WidgetStateProperty` and `CupertinoDynamicColor` fail to compose, null-fallback and `lerp` interpolation artifacts, the maintenance cost of dual hand-written field lists, and empirical data from the codebase.
3. **[Design Goals and Evaluation of Existing Options](design-doc/03-requirements-and-existing-options.md)**: The five core design goals, and why patching the old architecture or adopting `Mix` or `Forui` falls short.
4. **[Core Design Derivation](design-doc/04-core-derivation.md)**: A six-step derivation covering the `XStyle` full-coverage invariant, flipped state rules (`XRule` / `XWhen`), pure declaration-order precedence and rule regions, declarative derivations and custom `TokenGroup`s, the three-tier partial override model for composite values (`.parts`), and tree distribution (`StyleTheme` / `StyleScope`) with call-site design.
5. **[End-to-End Code Walkthrough](design-doc/05-walkthrough.md)**: Complete Before vs. After code comparisons across five representative scenarios.
6. **[Detailed Mechanics and Code Generation](design-doc/06-design-details-and-codegen.md)**: Rule region partitioning and naming statistics, derivation source classes and token internals (including `.computed`, virtual fields, and `paddingScaler`), composite partial overrides and idempotence boundaries, codegen architecture, and shared rule subclasses for Material's multi-button family (`CommonButtonRule` / `OutlinedButtonRule`).
7. **[Engineering Validation](design-doc/07-engineering-validation.md)**: Two-stage caching benchmarks, tree-shaking constraints, `debugSources` provenance tracking, static and runtime diagnostics, and unit-test resolution APIs.
8. **[Migration and Evolution Plan](design-doc/08-migration-plan.md)**: Landing in `cupertino_ui` first, followed by `material_ui` component-family consolidation criteria, keeping deprecated `style:` parameters, lazy evaluation of `resolveWith` compatibility rules (vs. truth-table sampling), and two-way `ThemeData` compatibility boundaries.
9. **[Cross-Platform Comparison and Special Topics](design-doc/09-topics-and-tradeoffs.md)**: Cross-platform trade-offs, interpolation and animation boundaries on environment switches, impact on AI-assisted coding, the `FilledButton.tonal` asymmetry, and a compliance and risk assessment of dot shorthands under the Flutter style guide and internal codebases.
