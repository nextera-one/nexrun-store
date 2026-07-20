# NexRun Store Agent Rules

This repository is a consumer Javelle application for discovering trusted
NexRun application packages.

## Application contract

- Use Java 21 and Maven.
- Import the released `one.nextera.openat.javelle:javelle-bom` once and do not
  version individual Javelle modules.
- Use the Material `j-*` component family throughout the application.
- Prefer focused `.jvl` pages with `<template>` and optional `<style scoped>`
  sections.
- Use Javelle routing, components, plugins, utilities, forms, state, and i18n
  before introducing application-owned infrastructure.
- Do not add React, Vue, Angular, Svelte, handwritten JavaScript, `<script>`
  blocks, or direct browser API calls.
- Do not use native application controls such as `<button>`, `<input>`,
  `<textarea>`, `<select>`, `<option>`, `<form>`, or `<dialog>`. Use their
  Javelle equivalents.

## Product boundaries

- The Store is a public discovery and installation-instruction surface.
- The catalog owns searchable product metadata.
- The IDEL Registry owns immutable manifests and blobs.
- NexRun owns verification, configuration, and deployment on the target host.
- A signed artifact is not trusted until it matches an explicit publisher
  trust policy.
- Never put secrets into catalog records, installation commands, or workload
  manifests.

## Verification

Run before publishing:

```bash
mvn test
javelle dev --check --mode web
javelle jvl src/main/resources --check --strict
rg -n --glob '*.jvl' --glob '*.html' '<(button|input|textarea|select|option|form|dialog)([[:space:]>])' src/main/resources
rg -n --glob '*.jvl' --glob '*.html' '<script([[:space:]>])|\b(window|document|navigator|localStorage|sessionStorage)\b' src/main/resources
```
