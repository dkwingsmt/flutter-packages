# A Component Theming Model for Flutter (Quick Version)

> Working draft for internal discussion. Class names are temporary placeholders; naming will be decided separately. A full design doc is in progress—see the end of this document for what it will cover.

## TL;DR

Flutter's current component theming model has structural flaws. In `material_ui`, themes and widget constructors maintain two separate hand-written field lists, and interaction states are wrapped around individual properties, causing layered overrides to wipe each other out. `cupertino_ui` is in an even worse spot: interaction states and brightness/contrast use two separate resolution mechanisms that do not compose, so user-supplied colors regularly render with the wrong brightness in dark mode.

We propose a new model: each component has a single style class, and every visual variation—interaction states, appearance variants, brightness, and contrast—is expressed as the same kind of conditional rule. Widget constructor parameters remain convenient shortcuts for common properties and read just like they do today; you only write rules when you need to target a specific state.

The Liquid Glass component set in `cupertino_ui` is being written from scratch and has no existing theming users. That gives us a rare window to adopt this model without a migration, so we want to start there. `material_ui` will need a migration path, which the full design doc will lay out.

## The Problem

Start with `material_ui`. Every customizable property on a component is written twice: once on the widget constructor and once on `XThemeData`, with each widget manually wiring `widget.x ?? theme.x ?? defaults.x`. Adding a single property touches 9 places. The team has always aimed for parity between widget parameters and theme fields, but two hand-maintained lists inevitably drift apart: `ProgressIndicatorThemeData` was missing `strokeWidth`, `borderRadius`, and several other properties for over a year before it was fixed ([#131690](https://github.com/flutter/flutter/issues/131690)); `TextField` has a `style` parameter for input text, yet its theme still has no corresponding field—changing the input font globally requires passing `style` at every call site ([#118267](https://github.com/flutter/flutter/issues/118267), still open).

State handling is an even subtler trap. `WidgetStateProperty` bundles "what value to use in each state" inside an opaque closure, and closures cannot be merged. If a theme author only wants to change a button's hovered background color, they have to replace the entire closure; if they forget the `disabled` branch, disabled buttons no longer look disabled. Derived relationships between properties (for example, an icon's color following `foregroundColor`) are hard-coded inside each widget's `build` method. Theme authors cannot see those relationships or customize them, and changing the fallback order in the widget risks breaking existing apps.

`cupertino_ui` fares no better. Its components use `WidgetStateProperty` to resolve interaction states and `CupertinoDynamicColor` to resolve brightness and contrast. Which step runs first—or whether it runs at all—is hand-written per property in every widget. While built-in default colors are mostly resolved properly, user-supplied colors frequently skip brightness resolution. `CupertinoSwitch` is the clearest example: pass a dynamic color with distinct light and dark values under a dark theme, and `trackOutlineColor`, `activeTrackColor`, and `thumbColor` all render their light-mode values. The same bug affects `fillColor` and `checkColor` on `CupertinoCheckbox`, and even `foregroundColor` and `focusColor` on `CupertinoButton`—silently, with no errors. We have confirmed all of these with tests.

Both packages suffer from the same underlying structure: interaction states and environment dimensions are attached to individual properties as wrapper types. In theory, every property could support every dimension from day one, but then callers would have to wrap every value they pass (such as `WidgetStatePropertyAll(...)`), which nobody wants to write. In practice, we only add state support to a handful of properties up front and upgrade others one by one as users file issues. Every upgrade changes a property's type from `Color` to `WidgetStateProperty<Color>`, rippling through constructor parameters, theme fields, `lerp` and `merge`, and every call site that reads it—much like function coloring. To avoid breaking changes, Flutter either keeps twin parameters side by side (like `activeColor` alongside `fillColor` on `Checkbox`, or `activeTrackColor` alongside `trackColor` on `Switch`, each requiring its own precedence rules) or disguises the wrapper type as a `Color` so callers don't have to wrap values, sacrificing type safety in the process. Both `WidgetStateColor` and `CupertinoDynamicColor` take the second route, which is directly responsible for the switch bugs above. Retrofitting dimensions onto one property at a time drains both our users and our engineering bandwidth, and every new dimension multiplies that cost. This model does not scale.

Stepping back, what a theming system actually does is merge: a component's appearance comes from the design spec (library defaults), the app designer (global theme), a specific screen (subtree override), and the widget call site, and all of those intents must merge into a single result. Merging requires one canonical field list, inspectable values, a unified way to express conditions across every dimension, and unambiguous precedence. The current model lacks all four. Hand-wiring bugs are just a symptom; the deeper issue is that we cannot build an API on top of this structure that does everything we need cleanly.

## Direction

Our approach flips the table around. You can think of a component's appearance as a "property × state" matrix: today, each property carries its own values across all states; in the new model, you group by state instead. A component's **style** is the plain collection of all its customizable properties—just data fields, no resolution logic, and every field holds a direct value rather than a wrapper. Visual variations are written as **rules**: each rule pairs a condition with a partial style, meaning "when this condition holds, set these properties to these values."

A condition is made up of **dimensions**. Interaction states (`hovered`, `pressed`, `disabled`) are dimensions; component appearance variants (such as a button's `appearance`) are dimensions; brightness, contrast, and `StyleVariant` are dimensions too. Expressing "background color when pressed in dark mode" works the exact same way as "background color when pressed"—it just constrains one more dimension in the condition. The composition bug in `cupertino_ui` disappears because everything resolves in a single pass. Every dimension in a condition is optional, and omitting one means "unconstrained," so adding a new dimension later just adds an optional field to the condition without breaking existing rules.

Components no longer have a separate `XThemeData` class—only a style class and a rule class—and a theme is simply a list of component rules. Library defaults, the global theme, subtree overrides, and call-site rules concatenate in that order into a single chain where later rules win. Subtree overrides no longer replace the outer theme wholesale; they append to the outer rules. The chain merges per property, and composite properties like `TextStyle` deep-merge field by field.

Because the style class and rule class are generated from a single property definition, they automatically include every customizable property on the component—themes can never fall out of sync again. Widget constructors expose only the most common properties as flat parameters, keeping everyday call sites as concise as they are today and translating those arguments into rules behind the scenes. For less common properties, or when you need per-state control at a call site, you pass `states:` on the widget or put a rule in the theme. This preserves what Flutter has always been good at: simple things stay simple, and complex things have a clear place to go.

We also support derived properties directly in rules: defaults or themes can declare that "this property takes the resolved value of another property on the same component" (such as `iconColor` following `foregroundColor`) or "this property reads a global token" (such as `tintColor` reading the global primary color). Beyond built-in color and typography tokens, apps can define their own custom token groups for brand colors or semantic values—covering what `ThemeExtension` does today—and reference them both inside component rules and in app code. Because these derivations live in rules instead of being buried inside `build` methods, theme authors can inspect them and override or rewire them with ordinary rules.

## Why Now, and Why Start with `cupertino_ui`

`cupertino_ui` has almost no component theming today: `CupertinoThemeData` takes 8 inputs and has zero per-component themes. Historically, limited staffing kept our focus on out-of-the-box fidelity rather than customization. Legacy Cupertino widgets will eventually be deprecated and removed, so we will not retrofit themes onto them; the upcoming Liquid Glass widgets, however, must have component theming, and the only question is whether we build it on the old paradigm or the new one.

We are building the Liquid Glass widgets from scratch right now, and per-widget theme APIs are scheduled for Phase 4. Until then, no users depend on theming for these widgets—making this our only window to establish a new theming paradigm without a migration. If we arrive at Phase 4 without a new model, the path of least resistance will be copying `material_ui`'s `XThemeData` + `WidgetStateProperty` pattern, repeating every problem described above in a brand-new package: drifting field lists, clobbered state closures, and dimensions retrofitted one property at a time.

`material_ui` and `cupertino_ui` have always shared a consistent programming paradigm, and we want to keep it that way, so `material_ui` will follow too. It cannot switch overnight, of course: existing framework and third-party widgets still read `ThemeData`, so the new model must coexist with it. Because both packages can now make major releases and the new model stays close to familiar Flutter idioms, a staged migration is realistic; the full design doc will detail the plan.

## Current Status

We have a working prototype of the rule engine and have validated it against all M3 defaults in `material_ui`: after expressing the defaults for 17 component groups as rules, we compared every field across all state combinations and 6 color schemes—2.13 million comparisons with 0 diffs, in less than 0.3x the lines of code of the hand-written originals. Switching those defaults to `const` rules that reference tokens still produces 0 diffs, and during theme interpolation animations, the resolution cache only misses on the first frame.

We have also completed a widget-layer prototype covering `StyleTheme`, `StyleScope`, per-component channel notifications (updating button rules in a scope does not rebuild switches in the same subtree), and cross-route rule capture. To validate against an existing baseline pixel for pixel, the prototype implements `Button` and `Switch` using the visual specification of the current Cupertino button and switch (dropping the `Cupertino` prefix to match the naming of upcoming widgets—note that we are not retrofitting themes onto legacy widgets, only borrowing their visuals as a regression oracle). Default rendering matches the original widgets pixel for pixel across every appearance, size, interaction state, and all 8 environment combinations—the only difference is fixing the bug where the original focus ring failed to resolve dynamic colors (see the [prototype repository](README.md)).

Next up: building a production Liquid Glass component with the new model, and completing the full design doc.

## Main Trade-offs

* **Rules are more verbose than flat values, and authors have to think about which states a rule covers.** Resolution is strictly order-based, so a broad condition later in the chain will overwrite a narrower state rule earlier in the chain if both set the same property (for example, a subtree rule matching `disabled: false` will overwrite an outer theme rule that set the same property for `pressed: true`). Code generation mitigates this for library defaults by exporting pre-partitioned state constants per property, but authors writing custom theme rules still need to mind their condition scope.
* **Migrating `material_ui` is a large effort**, and the new model will have to coexist with `ThemeData` during a long transition period.

## Non-Goals

* **No changes to `flutter/framework`, and no theming infrastructure in the `widgets` layer.** Theming belongs to the design-system packages (`cupertino_ui`, `material_ui`). Only the code generator is shared; generated code lives inside each package.
* **No single universal `Style` class across all components, and no goal of reducing the number of classes.** Each public component still gets its own strongly typed `XStyle` and `XRule`, exposing only the properties that actually apply to that component.
* **No theming retrofits for legacy Cupertino widgets.** Legacy widgets will be deprecated once Liquid Glass components are ready; the prototype only borrows their visual spec for pixel-level regression testing.
* **Not a replacement for custom widget composition in app code.** App-specific widgets that bundle business logic (such as a button with debounce, loading overlays, and analytics) should still be written as custom `StatelessWidget`s; the theming system only handles merging and inheriting visual style properties.

---

The sections below are aimed at readers who plan to read the full design doc.

## Design Skeleton

The snippets below use a hypothetical Liquid Glass `Button` to illustrate how the model addresses the problems above. A runnable version of the same rule and widget mechanics (implemented for `Button` and `Switch`) is available in the [prototype repository](README.md).

**1. Everyday call sites: common cases look the same as today, and per-state tweaks don't require closures**

Most call sites only use flat parameters and never touch rules; `CupertinoColors` dynamic colors work out of the box:

```dart
Button(
  appearance: ButtonAppearance.prominent,
  tintColor: CupertinoColors.systemRed,
  onPressed: save,
  child: const Text('Save'),
)
```

You only reach for `states:` when tweaking a specific state on a single widget instance. Flat parameters desugar into rules placed right before `states:`, so `states:` only needs to specify the state being changed—unlike `WidgetStateProperty.resolveWith`, where you have to spell out every state branch to avoid wiping out defaults:

```dart
Button(
  appearance: ButtonAppearance.prominent,
  tintColor: CupertinoColors.systemRed,
  states: [
    ButtonRule(ButtonWhen(pressed: true),
        style: ButtonStyle(foregroundColor: CupertinoColors.systemYellow)),
  ],
  onPressed: save,
  child: const Text('Save'),
)
```

**2. Themes and subtree overrides: touch only the states and properties you specify, and combine brightness with interaction states directly**

Rules assemble into a single chain—`component defaults → StyleTheme → outer-to-inner StyleScope → call-site flat params → call-site states:`—where later rules win per property. Conditions are flat, and omitted dimensions are unconstrained:

```dart
StyleTheme(
  rules: [
    // Only customize border radius and tint when enabled; default disabled styling stays intact
    ButtonRule(ButtonWhen(disabled: false),
        style: ButtonStyle(borderRadius: 12),
        derive: ButtonDerive(tintColor: Brand.green)),      // Brand is an app-defined token group
    // Dark mode + pressed: brightness and interaction state live in the same condition, resolved in one pass
    ButtonRule(
        ButtonWhen(pressed: true, brightness: {Brightness.dark}),
        style: ButtonStyle(foregroundColor: Color(0xFFFFD60A))),
  ],
  child: CupertinoApp(
    home: StyleScope(
      // Subtree overrides append to outer rules: only tintColor changes here (dynamic colors expand per environment),
      // while borderRadius: 12 and the dark+pressed foregroundColor from StyleTheme are preserved automatically
      rules: [
        ButtonRule(ButtonWhen(disabled: false),
            style: ButtonStyle(tintColor: CupertinoColors.systemOrange)),
      ],
      child: CheckoutPanel(),
    ),
  ),
)
```

Rules for different components can live in the same `rules` list, and each rule routes itself to its component's channel; updating rules for one component only notifies widgets subscribed to that channel.

**3. Derived properties and global tokens: fallback relationships are explicit and overridable**

Relationships like "icon color follows foreground color" or "background color reads a global brand token" live in a rule's `derive` block and are evaluated after the entire rule chain finishes resolving:

```dart
// Inside component defaults: iconColor follows the final foregroundColor, and tintColor reads the global primaryColor token
const ButtonRule(ButtonWhen(disabled: false),
  derive: ButtonDerive(
    iconColor: FieldRef(.foregroundColor),
    tintColor: CupertinoTokens.primaryColor,
  ),
)
```

Because derivation runs after the full rule chain resolves, passing `foregroundColor: CupertinoColors.white` at a call site (or overriding `foregroundColor` only in dark mode) automatically updates `iconColor` in that environment. If a theme wants to break that link, it simply writes an ordinary `ButtonRule` that assigns a concrete color or a different reference to `iconColor`, and the later rule wins.

## Anticipated Questions

**Why not adopt the design of Mix, forui, or Compose's Styles API?** We mean adopting their design, not adding a package dependency. Mix is built for styling custom widgets and serves that goal well, but it has no concept of per-component library defaults or "override all Checkboxes in this subtree," and its fluent builder chains cannot be `const` and depart from standard Flutter constructor idioms. forui is the closest to our approach and proves that per-component style classes backed by code generation work well in Flutter; we make different trade-offs around rule precedence, when token derivations evaluate, and how overrides compose, which the full design doc will compare point by point. Compose explicitly rejected component style objects in its 2023 API guidelines and reversed course in 2026, which validates the overall direction, but its `Style` API is lambda-based, still experimental, and not yet used by Compose Material components.

**How does this coexist with `ThemeData`?** It has to. Framework and third-party widgets will continue reading `ThemeData`, and migrating `material_ui` requires a transition period. The full design doc covers the coexistence mechanism.

**Will `WidgetStateProperty` in the framework be deprecated?** This proposal does not modify the framework. Individual widget constructors can still choose to accept map-backed `WidgetStateProperty` instances (`WidgetStateProperty.fromMap`, not opaque closures from `resolveWith`) as a shorthand to avoid five or six separate state parameters for a single color, expanding the map into rules under the hood. Theme `XStyle` classes do not use `WidgetStateProperty`.

**What happens to `CupertinoDynamicColor`?** Both widget constructor parameters and a rule's `style` can accept dynamic colors like `CupertinoColors.systemRed` directly (the outer `When` condition usually omits environment dimensions; if specified, only the dynamic color's values within those matching environments are used). The system expands them into environment-specific rules in one place, so individual widgets never have to call `resolveFrom` by hand.

**What replaces `ThemeExtension`?** Global tokens let apps define their own custom token groups for brand colors, semantic roles, and other settings, configured per brightness or environment dimension. These tokens can be referenced both inside a component rule's `derive` block and directly in widget build code, covering the use cases of `ThemeExtension`. We have verified this in the prototype; full API details will be in the design doc.

**What about performance?** In our assessment, rebuild scope—not style resolution math—dominates theming overhead. See "Current Status" for the cache hit rates and per-channel notification results from our rule and widget prototypes; detailed benchmarks will be in the full design doc.

**How will `material_ui` migrate?** That is the hardest part of this effort. We are clear-eyed about the scope, and the full design doc will present a concrete migration plan.

**Does this rely on code generation?** Yes, and we consider that a strength. `material_ui` already relies heavily on code generation, and without macros in Dart, generation is virtually unavoidable; many of the bugs in the current system exist specifically because boilerplate was written by hand. Generated code is checked into the package repository, so app developers never run a generator.

## What the Full Design Doc Will Cover

The step-by-step derivation from current problems to this design; a point-by-point comparison with existing alternatives, including why rules use declaration order instead of CSS-style specificity; the `material_ui` migration plan and `ThemeData` coexistence architecture; cross-route theme capture; caching and performance benchmarks; the scope of the code generator; and final naming.
