# 9. Trade-offs

[← Previous: 8. Migration](08-migration-plan.md) | [Back to Roadmap](00-intro.md) | [Next: 10. Appendix →](10-appendix.md)

---

This section summarizes the global trade-offs accepted by this proposal within the cross-platform design spectrum (9.1), evaluates how the core assumption of extensive Dart dot-shorthand usage interacts with the Flutter repository style guide and internal codebases (9.2), and lists follow-up evaluation TODOs (9.3).

---

## 9.1 Global trade-offs

Across UI frameworks, styling architectures reflect the runtime optimization model of the host language and the positioning of the widget library: Jetpack Compose (2026 `Styles API`) relies on Kotlin receiver lambdas and compiler snapshot observation; `Mix` targets atomic primitive assembly; SwiftUI and Angular Material tighten customization entry points (black-box protocols or top-level tokens only) to reduce maintenance surface.

Flutter's `material_ui` and `cupertino_ui` must provide full component-level property control across global, local, and instance layers while aligning with Dart's optimization model built around compile-time `const` canonicalization and value equality. Within these constraints, this proposal consciously accepts three global trade-offs:

1. **Conditional rule syntax is slightly longer than chained DSLs, and hand-written broad conditions require attention to state scope**: To preserve compile-time `const` and static type safety, rules are written as `.when(..., style: .values(...))`; under pure order precedence, writing a broad condition by hand instead of using a region constructor requires verifying whether dedicated states like `disabled` should be excluded.
2. **Relies on build-time code generation, emitting a set of helper types per component**: To eliminate manual synchronization across 9 boilerplate locations and power dot-shorthand autocomplete, each component generates `XStyle`, `XStyleSpec`, `XRule`, `XWhen`, and `XSource` classes (with unused components tree-shaken under the no-central-registry constraint in Section 7.2).
3. **Cannot share a single "state-to-value mapping object" across unrelated component types**: Because `XWhen` is generated per component, concrete values can be shared across components via `TokenGroup`, but a single state-mapping closure cannot be passed simultaneously to both `Button` and `Checkbox` like a legacy `WidgetStateProperty`.

---

## 9.2 Dot shorthands

As noted in Section 4 Step 2, API readability in this proposal rests on the assumption that developers will use Dart dot shorthands extensively when authoring rules. Writing `.when`, `.values`, `.derive`, `.fromField`, `.fromToken`, `.opacity`, and `.parts` keeps generated helper class names (`ButtonStyleSpec`, `ButtonColorSource`) out of user code and allows upgrading a field from `XSource<T>` to a `.parts`-enabled subclass without breaking shorthand callers (this experience also depends on IDEs surfacing static member completions reliably in dot-shorthand positions, which will be verified separately).

Compliance and feasibility across the official Flutter repositories, external third-party apps, and internal Google codebases break down as follows:

### 1. Conflict with the style guide

`flutter/flutter` and `flutter/packages` (including `material_ui` and `cupertino_ui`) follow the [Style guide for Flutter repo](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md). Against its ten rules on dot shorthands:
- **Compliant usages**: Named argument values (`style: .derive(...)`, `padding: .all(8)`), collection literals with explicit type arguments (`...<ButtonRule>[.when(...)]`, `appearance: <ButtonAppearance>{.tinted}`), and top-level/field initializers all comply.
- **Single substantive conflict — Rule 5 (no dot shorthands in positional arguments)**: The guide forbids dot shorthands in positional arguments. In the derivation API, the inner arguments of `.fromField(.foregroundColor)`, `.fromToken(.primaryColor)`, `.value(.all(8))`, and `.opacity(.fromField(...), 0.12)` are positional. Spelling out full class names under Rule 5 turns this into `ButtonColorSource.opacity(ButtonColorSource.fromField(ButtonField.foregroundColor), 0.12)`, roughly doubling code length. (Switching to named parameters like `.fromField(field: .foregroundColor)` or generating static constants per field/token on every source class was evaluated and rejected, as the former adds noise to all app code while the latter causes field/token name collisions and still leaves `.opacity(...)`'s outer positional argument unresolved.)

### 2. Three code environments

1. **Framework package code (`material_ui` and `cupertino_ui` default rule tables)**:
   Default rule tables and helper code inside the widget packages are emitted by the code generator (or maintained internally), so they can spell out full type names to comply with the Flutter style guide at zero human authoring cost (for official `example/` code and Dartdoc snippets, an exemption for self-describing factories like `.fromField` / `.fromToken` can be proposed to the style guide).
2. **External third-party apps**:
   External developers are not bound by the internal Flutter repo style guide; the assumption that third-party authors will use dot shorthands to avoid class-name prefix noise holds cleanly.
3. **Internal Google codebases (manageable minor risk)**:
   There is no global linter blocking dot shorthands internally, and Dart readability reviewers generally encourage concise shorthands. The only notable risk is the `customer: money` project, whose internal style guide advises avoiding dot shorthands "when the type is not immediately obvious." During internal rollout, a targeted exception for style rule APIs (where the enclosing rule context and `.fromField` / `.fromToken` factory names already identify the type) will be coordinated with that team.

---

## 9.3 TODO

- **TODO (`cupertino_ui` rollout phase)**: Build an AI Agent Coding Eval Benchmark (20 UI tasks) covering flat parameter customization, dark/high-contrast adaptation, local `StyleScope` overrides, and cross-field derivations to quantitatively compare first-pass compile rates and all-state/dark-mode pixel assertion pass rates between legacy `WidgetStateProperty` / `CupertinoDynamicColor` APIs and the new declarative rule API.

---

[← Previous: 8. Migration](08-migration-plan.md) | [Back to Roadmap](00-intro.md) | [Next: 10. Appendix →](10-appendix.md)
