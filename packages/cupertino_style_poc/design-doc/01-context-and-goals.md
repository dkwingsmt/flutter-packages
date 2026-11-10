# 1. Context & Scope

[← Back to Introduction & Table of Contents](00-intro.md) | [Next: 2. Problems with the Current Model →](02-problems.md)

---

## 1.1 Why Now: Both Design Systems Face Major Architectural Upgrades

Flutter's first-party widget libraries are currently undergoing two major architectural shifts at once. First, `material` and `cupertino` have been split out of the main framework into standalone `material_ui` and `cupertino_ui` packages. Second, both design languages are going through major generational updates: `cupertino_ui` is rewriting its visual system for iOS 26 **Liquid Glass**, whose [roadmap plans](https://docs.google.com/document/d/16qjTT2IRrN0F2NNaf4l4oZR48hAkP0JWw_mUlTcdD5w/edit?tab=t.0#heading=h.ycveqjxmtruj) to introduce per-component theming to Cupertino for the first time in Phase 4; meanwhile, `material_ui` is planning for **Material 3 Expressive (M3E)**, which adds new size, shape, and style dimensions.

Before investing engineering effort into rewriting dozens of Liquid Glass widgets and expanding multidimensional variants for M3E, a fundamental question needs an answer: can the existing styling and theming foundation support this evolution?

This question is especially urgent for `cupertino_ui`. Historically, due to limited staffing, Cupertino focused on out-of-the-box visual fidelity; `CupertinoThemeData` has only 7 global fields and no per-component themes at all. Under the established Liquid Glass decision (`lg.export-alongside-legacy`), new unprefixed widgets (such as `Button` and `Switch`) will be exported alongside legacy `Cupertino`-prefixed widgets, while the legacy widgets will eventually be deprecated and removed without receiving new theming support. That means before the new Liquid Glass widgets reach Phase 4, their component theming APIs carry zero legacy baggage.

Entering Phase 4 without a new theming model means taking the path of least resistance and copying `material_ui`'s existing `XThemeData` plus `WidgetStateProperty` pattern. Yet as the next section will show, the current styling mechanisms in both `material_ui` and `cupertino_ui` have hit structural bottlenecks. Repeating known design flaws across a brand-new set of widgets would be a costly missed opportunity. Conversely, because `material_ui` and `cupertino_ui` have always maintained a consistent programming paradigm, landing and validating the new model first during `cupertino_ui`'s greenfield window—and then following up in `material_ui`'s major version update via a compatibility bridge—carries the lowest engineering risk.

## 1.2 Scope & Non-Goals

To keep system complexity and surface area under control, this proposal sets five boundaries:

**Solve this in pure Dart without introducing an external CSS-like styling language.** Developers write all style and theme configurations using ordinary Dart types and constructors, relying on the Dart compiler for type checking and constant optimization. This proposal does not introduce an external DSL, string class names, or a runtime selector matching engine like CSS.

**Keep theming infrastructure out of `flutter/framework` (the `widgets` layer).** Theming belongs to specific design-system packages (`material_ui` and `cupertino_ui`), not the low-level `widgets` framework layer. This proposal does not add base theme classes to `flutter/framework`, nor does it modify or deprecate `WidgetStateProperty` in `widgets`. The only change touching `flutter/framework` is fixing an existing oversight where multi-window dialogs (`DialogWindow`) fail to call `InheritedTheme.capture` across routes (missing dialog route captures in `cupertino_ui` itself are fixed inside the `cupertino_ui` package; see Step 6 in Section 4).

**Continue and expand build-time code generation, sharing the generator while keeping runtime packages independent.** Today, `material_ui` already uses a build-time code generator (`gen_defaults`) to generate `_XDefaultsM3` defaults from design tokens and checks the output directly into source control, which has proven effective at reducing manual maintenance. This design extends that approach to generate style classes, rule classes, equality checks, and interpolation boilerplate as well. `material_ui` and `cupertino_ui` share the same build-time code generator, but the generated code lives inside each respective package and is checked into source control; base component style classes remain package-private, and the two packages share no engine code at runtime. This keeps package dependencies clean—sharing runtime code would require extracting and maintaining a third shared foundation package, which is a non-goal at least for the current phase.

**Target built-in components in the two first-party packages only; do not open up code generation for custom app widgets yet.** Because generated files are checked into the first-party packages, downstream app developers do not need to install or run any code generation tools. At the same time, running this code generator for custom domain widgets in app code is out of scope for now (custom app-defined global token groups are not subject to this limitation). For composite domain widgets built by app teams (such as a business button with debounce, a loading overlay, and analytics hooks), developers should continue following standard Flutter idioms by composing base widgets inside a `StatelessWidget` or configuring subtree styles with local theme scopes.

**Do not retrofit themes onto legacy Cupertino widgets being phased out.** The new model serves only next-generation Liquid Glass widgets and future `material_ui`. Although the prototype implements unprefixed `Button` and `Switch` widgets using the visual specs of the existing Cupertino button and switch, it does so purely to have an existing pixel-for-pixel baseline for regression testing; soon-to-be-deprecated legacy widgets like `CupertinoButton` and `CupertinoSwitch` will not receive theming retrofits.

---

[← Back to Introduction & Table of Contents](00-intro.md) | [Next: 2. Problems with the Current Model →](02-problems.md)
