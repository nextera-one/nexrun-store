---
name: javelle-project-builder
description: Use when building, modifying, documenting, or generating any Javelle project, app, module, template, .jvl file, UI, Maven configuration, CLI scaffold, plugin usage, utility usage, routing, state, forms, i18n, native target, test, or example. Enforces Java-first Javelle development, latest released Maven Central artifacts for consumer projects, Javelle components/plugins/utilities instead of raw JavaScript or browser frameworks, and no native HTML controls in app templates.
---

# Javelle Project Builder

Javelle is a Java-first UI framework. Build with Java, Maven, `.jvl` or `.html` templates, Javelle components, Javelle plugins, Javelle utilities, and the module boundaries in this repository.

## First Reads

Before editing Javelle framework code, docs, examples, templates, generated app code, plugin usage, UI, runtime, or CLI scaffolds, read the relevant local contracts:

- `AGENTS.md`
- `idel/javelle-codex.idel`
- `idel/javelle-components.idel`
- `idel/javelle-ecosystem.idel`
- `idel/javelle-subprojects.idel`
- `docs/agents.md`
- `docs/javelle-examples.md`
- `docs/create-javelle-projects.md` when creating or documenting app projects
- `docs/npm-interop.md` only when explicitly working on npm wrapper interop

Then inspect the concrete source of truth for the task:

- `pom.xml` and `javelle-bom/pom.xml` for modules, versions, and dependency management.
- `javelle-ui-components/src/main/java/io/javelle/ui/components/JComponentRegistry.java` for component tags.
- `javelle-plugins/src/main/java/io/javelle/plugins/PluginRegistry.java` for default plugins.
- `javelle-ui-directives/src/main/java/io/javelle/ui/directives/` for directives.
- `javelle-utils/src/main/java/io/javelle/utils/` for utility facades.
- Existing canonical examples in `javelle-docs`, `javelle-cli/src/main/resources/templates`, and `projects`.

If the Javelle source tree is not present because you are inside a consumer app, use the app POM, generated resources, installed Javelle CLI help, Maven artifact metadata, and public docs. Do not copy source modules into the app.

## Java-First Contract

- Generate Java 21, Maven, `.jvl`, `.html`, Javelle component tags, Javelle plugin calls, and Javelle utility calls.
- Do not generate React, Vue, Angular, Svelte, raw browser frameworks, app-level `<script>` blocks, or hand-written app JavaScript.
- Do not call browser APIs directly when a Javelle plugin or utility exists.
- Do not copy Javelle source into consumer apps. Consumer apps depend on released Maven artifacts.
- Inside this monorepo, edit the owning Javelle module source. Outside this monorepo, consume Javelle from Maven.
- Keep `javelle-runtime.js` focused on core hydration, components, routing, patches, lifecycle, and generic browser/native plugin surfaces.

## Maven Release Rule

For generated or consumer Javelle projects, always resolve the current released Maven version from Maven Central at task time. Do not use the local checkout version as the consumer dependency version unless the user explicitly asks for a local framework development setup.

Use the released BOM:

```bash
JAVELLE_VERSION="$(curl -fsSL https://repo.maven.apache.org/maven2/one/nextera/openat/javelle/javelle-bom/maven-metadata.xml | sed -n 's:.*<release>\([^<]*\)</release>.*:\1:p' | head -n 1)"
```

If `<release>` is unavailable, try `<latest>` from the same metadata. If Maven Central cannot be reached, ask before guessing a version.

Generated app POMs should import the BOM once:

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>one.nextera.openat.javelle</groupId>
      <artifactId>javelle-bom</artifactId>
      <version>${javelle.version}</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>
```

Then depend on needed modules without module-level versions:

```xml
<dependency>
  <groupId>one.nextera.openat.javelle</groupId>
  <artifactId>javelle-ui</artifactId>
</dependency>
```

When using the CLI to create an app, pass the resolved version:

```bash
javelle new my-app --package dev.example.app --javelle-version "$JAVELLE_VERSION"
```

## Use Javelle Modules

- Core model and routing: `javelle-core`, `javelle-quorium`, `javelle-devtools`.
- Templates and rendering: `javelle-template`, `javelle-runtime`, `javelle-ui-core`.
- UI system: `javelle-ui`, `javelle-ui-core`, `javelle-ui-foundation`, `javelle-ui-components`, `javelle-ui-icons`, `javelle-canvas`, `javelle-ui-directives`.
- Routing and pages: `javelle-core`, `javelle-mvc`, `javelle-panel`.
- State and stores: `javelle-reactive`.
- Ecosystem: `javelle-plugins`, `javelle-utils`, `javelle-forms`, `javelle-i18n`, `javelle-tes`, `javelle-springfabric`, `javelle-testing`.
- Native and delivery: `javelle-native`, `javelle-cli`, `javelle-bom`, `javelle-docs`.

Compatibility-only Maven coordinates (`javelle-router`, `javelle-store`, and
the former split UI foundation artifacts) forward to their current owners. Do
not add implementation code to compatibility modules.

Use the most specific Javelle module that already owns the capability. Do not invent app-local framework code until checking components, plugins, directives, utilities, forms, i18n, state, routing, and testing helpers.

## UI Rules

Use Javelle components for app-level controls and generated examples:

- Layout: `j-app`, `j-layout`, `j-page`, `j-section`, `j-page-container`, `j-header`, `j-footer`, `j-drawer`, `j-toolbar`, `j-row`, `j-col`.
- Actions and navigation: `j-button`, `j-icon-button`, `j-button-group`, `j-button-dropdown`, `j-button-toggle`, `j-tabs`, `j-route-tab`, `j-menu`, `j-dropdown`, `j-breadcrumbs`, `j-pagination`, `j-stepper`.
- Display: `j-card`, `j-list`, `j-table`, `j-markup-table`, `j-data-grid`, `j-chip`, `j-badge`, `j-avatar`, `j-icon`, `j-img`, `j-calendar`, `j-chart`, `j-tree`, `j-timeline`.
- Forms: `j-form`, `j-input`, `j-textarea`, `j-select`, `j-file`, `j-checkbox`, `j-radio`, `j-toggle`, `j-slider`, `j-range`, `j-color-picker`, `j-date-picker`, `j-time-picker`, `j-field`, `j-editor`.
- Feedback: `j-alert`, `j-banner`, `j-dialog`, `j-snackbar`, `j-tooltip`, `j-progress`, `j-linear-progress`, `j-circular-progress`, `j-spinner`, `j-skeleton`, `j-rating`.
- Advanced: `j-virtual-scroll`, `j-infinite-scroll`, `j-uploader`, `j-splitter`, `j-scroll-area`, `j-expansion-panel`, `j-fab`, `j-popup-proxy`, `j-pull-to-refresh`, `j-flow`, `j-separator`, `j-intersection`, `j-resize-observer`, `j-scroll-observer`, `j-lazy`.

Forbidden in app templates and generated examples:

- `<button>`
- `<input>`
- `<textarea>`
- `<select>`
- `<option>`
- `<form>`
- `<dialog>`
- Native checkbox or radio inputs

Native HTML controls are allowed only inside framework component implementations where the component intentionally renders a platform primitive.

## Template Rules

- Prefer `.jvl` single-file components when Java behavior, scoped styles, and template markup belong together.
- Keep `.jvl` files structured as `<template>`, `<code lang="java">`, and optional `<style scoped>`.
- Use `data-jvl-on-*` for events and registered Javelle directives for bindings and behavior.
- Keep app UI in multiple focused pages/components instead of one oversized page when the feature naturally has routes or screens.
- Use routing from `javelle-core`, `javelle-reactive` for local and global state, `javelle-forms` validators for forms, and `javelle-i18n` for localization.

## Plugins And Utilities

Use `PluginRegistry.defaults()` and existing plugins for browser/native capabilities, including notification, dialog, loading, storage, clipboard, theme, dark mode, screen/platform, metadata, location, network, keyboard, app/native bridge, device, media, Bluetooth, Wi-Fi, sensors, payments, printing, and related capabilities.

Use `io.javelle.utils` for common helpers, including dates, formatting, colors, CSS classes, CSS variables, event bus, JSON, unique ids, type checks, DOM descriptors, scrolling, metadata, file export, throttling, debounce, cloning, and URL opening.

Use `io.javelle.forms` validators such as `Required`, `Email`, `Min`, `Max`, `MinLength`, `MaxLength`, `Pattern`, and `SameAs`.

## NPM Interop Boundary

Do not use npm or JavaScript for normal Javelle app code. If the user explicitly requests a browser npm package, use the Javelle CLI npm wrapper workflow from `docs/npm-interop.md` so the app-facing surface remains Java:

```bash
javelle npm init
javelle npm add chart.js --java-package app.npm
javelle npm wrapper chart.js --from-dts node_modules/chart.js/dist/types/index.d.ts --java-package app.npm --class ChartJs
```

Keep npm bundles, `extra-runtime.js`, and generated wrappers app-owned. Do not move package-specific runtime code into Javelle core.

## Verification

Run focused tests for edited modules first, then broaden for shared contracts:

```bash
./mvnw -pl javelle-ui-components test
./mvnw -pl javelle-plugins test
./mvnw -pl javelle-utils test
./mvnw -pl javelle-cli test
./mvnw -pl javelle-docs test
./mvnw test
```

When editing `.jvl` templates or generated app resources, also run the CLI validator when available:

```bash
javelle jvl src/main/resources --check --strict
```
