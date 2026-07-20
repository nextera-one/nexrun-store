# NexRun Store

NexRun Store is the public catalog for signed, versioned NexRun application
packages. It helps users understand an application's requirements and trust
status before they pull and deploy it with NexRun.

This first vertical slice contains:

- a Javelle catalog landing page;
- a detailed MySQL source-kit and installation-readiness page;
- a security and publisher trust page;
- a versioned catalog record schema and seed catalog; and
- the initial catalog, registry, and installation architecture RFC.

The seed entries are previews sourced from the NexRun repository. They are not
presented as downloadable registry releases until the publishing pipeline has
produced immutable digests and verified publisher signatures.

## Run locally

Requirements: Java 21, Maven, and the Javelle CLI.

```bash
./dev.sh
```

Build and validate:

```bash
mvn test
javelle dev --check --mode web
javelle jvl src/main/resources --check --strict
./build.sh web
```

## Project boundaries

- `src/` contains the Java-first Javelle application.
- `catalog/catalog.json` is bundled preview data for the first UI slice.
- `schemas/catalog-entry.schema.json` defines the catalog API record.
- `docs/RFC-STORE-001-catalog-and-trust.md` defines the service boundary and
  publishing roadmap.
