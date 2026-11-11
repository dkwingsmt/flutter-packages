# 1. Background

[← Back to Roadmap](00-intro.md) | [Next: 2. Problems →](02-problems.md)

---

## 1.1 Motivation

`material_ui` and `cupertino_ui` have been decoupled from the core framework into standalone packages and are undergoing simultaneous major evolutions: `cupertino_ui` is rewriting its components for iOS 26 Liquid Glass, with its [roadmap](https://docs.google.com/document/d/16qjTT2IRrN0F2NNaf4l4oZR48hAkP0JWw_mUlTcdD5w/edit?tab=t.0#heading=h.ycveqjxmtruj) scheduling the first-ever per-component theming mechanism for Cupertino in Phase 4 (under the `lg.export-alongside-legacy` decision, new unprefixed widgets export alongside legacy `Cupertino*` widgets with no legacy theming baggage); meanwhile, `material_ui` is planning to introduce Material 3 Expressive (M3E), which adds new size and shape dimensions.

Before rewriting dozens of Liquid Glass widgets and expanding multi-dimensional variants for M3E, the structural flaws in the existing styling foundation need to be addressed. Landing and validating the new model first during `cupertino_ui`'s greenfield window—and then following up in `material_ui` via a compatibility bridge—carries the lowest engineering risk.

## 1.2 Scope and non-goals

To keep complexity and blast radius under control, this proposal sets five boundaries:

1. **Pure Dart expression**: Rely on Dart's type system and compile-time capabilities (`const`), without introducing external CSS-like DSLs, string selectors, or runtime selector parsers.
2. **Do not push into the `widgets` layer**: Theming infrastructure belongs in the design-system packages (`material_ui`, `cupertino_ui`). No new theme base classes are added to `flutter/framework`, and `WidgetStateProperty` is neither modified nor deprecated (the only change touching `flutter/framework` is fixing a missing cross-route `InheritedTheme.capture` call in multi-window `DialogWindow`).
3. **Expand build-time code generation while keeping runtime packages independent**: Extend `material_ui`'s existing `gen_defaults` approach so that style classes, rule classes, equality, and interpolation boilerplate are all generated and checked into the repository. Both packages share the build-time code generator but share no runtime engine code—avoiding a third shared dependency package—and downstream app developers never need to run any build tools.
4. **First-party built-in widgets only**: Do not expose the code generator to custom app widgets for now (custom app-defined global token extensions are not subject to this restriction). Composite app widgets should continue to be written as standard `StatelessWidget` compositions or local theme scopes.
5. **No theming retrofits for legacy Cupertino widgets**: The new model targets only next-generation Liquid Glass components and future `material_ui`, without retrofitting themes onto `CupertinoButton`, `CupertinoSwitch`, or other legacy widgets scheduled for deprecation.

---

[← Back to Roadmap](00-intro.md) | [Next: 2. Problems →](02-problems.md)
