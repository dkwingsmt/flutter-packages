# A Component Styling and Theming Model for Flutter (Design Document)

> Working draft for internal team review. Class names are temporary placeholders; final naming will be decided separately.

## 0. Overview

### 0.1 Reading guide

Consider reading the 10-minute [Quick Version (`quick-version.md`)](../quick-version.md) first for the core flip from "properties wrapping states" to "conditions wrapping property blocks." The prototype repository in this directory (see `README.md` at the repository root and `packages/cupertino_style_poc/example/`, with a source index in Section 5.2) implements the rule engine, `InheritedModel`-based per-channel notifications, cross-route rule capture, and pixel-aligned `Button` and `Switch` widgets (including 448 default-appearance cases and 304 flat-parameter cases tested pixel for pixel).

### 0.2 Summary

This proposal unifies component defaults, global themes, local scope overrides, and call-site parameters under a single styling model built on immutable pure-data rules (`const`):

- **Ergonomic call sites and safe per-state tweaks**: Widget constructors keep familiar flat parameters (such as `Button(color: ...)`). At build time, the code generator statically analyzes each component's default rule table, automatically partitions reachable state combinations into mutually exclusive Rule Regions, and generates named constructors (used with Dart dot shorthands such as `.backgroundColor(tintedEnabled: ...)`), preventing local tweaks from clobbering dedicated states like `disabled` (see [Section 9.2](09-topics-and-tradeoffs.md) for dot-shorthand style guide compliance).
- **Spec coverage and pixel-level parity**: Rewriting the default styles of 17 core component groups in `material_ui` (including M3 Expressive variants) as declarative rules produced 0 diffs across 2,134,974 field comparisons over all reachable states and 6 color schemes, in 29% of the lines of code of the original `_XDefaultsM3` classes (1,017 lines vs. 3,529 lines). In the `cupertino_ui` prototype, `Button` and `Switch` match the original widgets pixel for pixel across all appearances and 8 environment combinations, while `CupertinoDynamicColor` values are automatically expanded into environment rules during chain construction.
- **Runtime caching and tree-shaking**: The evaluation engine uses two-stage caching (symbolic resolution cache + token-bound cache). In a 60-frame theme interpolation benchmark across 17 M3 component groups (JIT), the symbolic cache achieves a 100% hit rate on frames 2–60, cutting per-frame evaluation time to roughly one-third of rebuilding rules every frame (~205µs vs. 607µs; AOT numbers pending). Architecturally, there is no central component registry or monolithic theme object, allowing unused components and their rules to be tree-shaken by the compiler (unused region constructors add 0 bytes across AOT, dart2js, and wasm).
- **Code generation, observability, and smooth migration**: Component maintainers author a single declarative definition of fields and default rules; all boilerplate is generated and checked into the repository, so downstream app developers never run build-time codegen tools. The engine provides `debugSources` for per-field provenance and `X.resolveStyle` for static unit testing. `cupertino_ui` adopts the model directly in new Liquid Glass components, while `material_ui` retains existing `style:` parameters in place and wraps legacy `ThemeData` and `resolveWith` closures as lazily evaluated compatibility rules.

### 0.3 Document roadmap

- [Section 1: Background](01-context-and-goals.md) — Motivation and five architectural boundaries
- [Section 2: Problems](02-problems.md) — Three underlying bottlenecks in the current architecture
- [Section 3: Goals and existing options](03-requirements-and-existing-options.md) — Five design goals and an evaluation of `fromMap`, `Mix`, and `Forui`
- [Section 4: Design](04-core-derivation.md) — Six-step derivation of the core model from the design goals (jump directly to Sections 4 and 5 for the fastest overview of the new API)
- [Section 5: Walkthrough](05-walkthrough.md) — Four-layer customization example and navigation index for the PoC repository
- [Section 6: Technical details](06-design-details-and-codegen.md) — Rule region partitioning algorithm, token internals, component patterns, codegen architecture, and animation interpolation boundaries
- [Section 7: Engineering validation](07-engineering-validation.md) — Per-channel notifications, two-stage cache benchmarks, tree-shaking constraints, `debugSources`, and testing APIs
- [Section 8: Migration](08-migration-plan.md) — `cupertino_ui` initial rollout and `material_ui` compatibility bridge
- [Section 9: Trade-offs](09-topics-and-tradeoffs.md) — Cross-platform trade-offs, dot-shorthand style guide compliance, and evaluation TODOs
- [Section 10: Appendix](10-appendix.md) — Rule region API candidates, `ThemeExtension` survey data, and migration sampling alternatives
