# RFC-STORE-001: NexRun catalog, releases, and publisher trust

Status: accepted for initial vertical slice

## Decision

NexRun Store is split into three contracts:

1. The **Store** is a public Javelle application for discovery, documentation,
   compatibility review, and installation planning.
2. The **Catalog** is a searchable metadata service describing applications,
   versions, publishers, requirements, and verification results.
3. The **IDEL Registry** stores signed immutable IDEL Container manifests and
   their content-addressed blobs.

NexRun remains the only component that verifies, configures, and deploys a
package on a target host. The public Store does not connect directly to a
privileged local daemon.

## Terminology

- **Application**: the human-facing catalog entry.
- **Release**: an immutable, signed package version identified by digest.
- **Instance**: a configured deployment created on a user's NexRun host.
- **Source kit**: reviewed manifests and operational documentation that have
  not yet passed the registry publishing pipeline.

The Store distributes releases and source kits, never preconfigured running
instances. Secrets and user data belong to an instance and must not appear in
catalog metadata or release layers.

## Ownership

Catalog-specific records belong to the NexRun product boundary. They should be
implemented in a future `nexrun-catalog` service or crate, not in vendor-neutral
`idel-*` crates. Existing `idel-store` manifest, signature, digest, push, and
pull behavior remains the registry source of truth.

## Catalog entry

The canonical JSON shape is defined by
`schemas/catalog-entry.schema.json`. Each record includes:

- stable publisher and application slugs;
- display metadata, category, license, source, and documentation links;
- supported platforms and architectures;
- declared ports, volumes, secrets, resources, and capabilities;
- release availability and lifecycle status;
- immutable manifest digest and signer for published releases;
- SBOM, provenance, vulnerability, and conformance evidence links; and
- minimum and maximum compatible NexRun versions.

Mutable tags may be offered as discovery aliases, but an installation plan
must resolve them to a digest before approval.

## Trust model

The first release supports three presentation levels:

- `official`: published by a Nextera-controlled identity and passing all
  required conformance gates;
- `verified`: identity verified and automated gates passed, but not maintained
  by Nextera; and
- `community`: cryptographically intact but carrying no Nextera endorsement.

A valid embedded signature proves integrity and signer possession only. The
installer must match the signer or signing identity against explicit trusted
publisher policy before execution. The UI must never label an arbitrary signed
artifact as trusted.

Published releases must be immutable and include expiry-aware repository
metadata so clients can reject rollback and freeze attacks. Signer rotation and
revocation are catalog security events and must not mutate historical release
content.

## Publishing pipeline

An official release progresses through these gates:

1. Parse and strictly validate every IDEL resource.
2. Reject mutable OCI references for retained or stateful releases.
3. Compile and inspect the exact capability plan.
4. Build in a constrained builder and retain signed SLSA provenance.
5. Produce an SBOM and vulnerability report.
6. Verify declared ports, secrets, volumes, identities, and resource bounds.
7. Install on a clean NexRun host and wait for readiness.
8. Exercise restart and uninstall behavior; stateful packages also require a
   backup and restore drill.
9. Sign the release using the publisher identity and publish immutable blobs.
10. Publish catalog metadata only after the registry confirms every digest.

The initial Store ships source-kit previews while this pipeline is implemented.

## API boundary

The future catalog service exposes read-only public routes:

```text
GET /v1/catalog/apps
GET /v1/catalog/apps/{publisher}/{slug}
GET /v1/catalog/apps/{publisher}/{slug}/versions
GET /v1/catalog/apps/{publisher}/{slug}/versions/{version}
GET /v1/catalog/security/advisories
```

Publisher submission routes are authenticated and separate from registry blob
upload. Catalog records reference registry releases; they never proxy secrets
or accept arbitrary host paths.

The existing registry routes remain responsible for bytes:

```text
GET/PUT /v1/manifests/{reference}
GET/PUT /v1/blobs/{digest}
```

## Installation flow

The current low-level flow remains pull, inspect, configure, and deploy. A
future convenience command may provide:

```text
nexrun install nextera/mysql@1.0.0
```

It must expand into a visible plan that:

1. resolves the version to an immutable digest;
2. verifies repository metadata and publisher trust;
3. displays required capabilities, ports, resources, secrets, and volumes;
4. collects instance configuration without persisting plaintext secrets;
5. requests operator approval;
6. pulls and verifies every blob; and
7. deploys and records signed lifecycle evidence.

Until that command and a published release exist, the Store labels entries as
source kits and links users to reviewed source instructions instead of showing
nonfunctional install commands.

## Initial implementation

The initial Javelle application uses bundled seed metadata and provides routes
for catalog discovery, a MySQL package detail, and the trust model. The next
slice will introduce a read-only catalog service and replace bundled metadata
with the same schema over HTTP.
