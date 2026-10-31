# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and this project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Security

- Bumped `@modelcontextprotocol/sdk` 1.31.0 -> 1.32.0 (CVE-2026-111767,
  CVE-2026-111768), `undici` 8.10.2 -> 8.12.2 (CVE-2026-109869), `body-parser`
  2.2.2 -> 2.4.0 (CVE-2026-111181) and the stray hoisted `zod` 3.25.76 -> 4.6.6
  (CVE-2023-54404; OpenClaw declares zod 4.x). Trivy had main red since
  2026-10-27.

## [1.1.2] - 2026-10-18

### Security

- Bumped `@modelcontextprotocol/sdk` 1.29.0 -> 1.31.0 (CVE-2026-104850) and
  `proxy-addr` 2.0.7 -> 2.0.8 (CVE-2026-90711 CRITICAL). Dropped the unused
  devDependency `oxfmt` and its exact-pinned `tinypool` 2.1.0
  (CVE-2026-104848, CVE-2026-104849). `braces` 3.0.3 (CVE-2026-93687) has no
  fix yet and is in `.trivyignore`. Trivy blocked the v1.1.1 build on these,
  so v1.1.1 never published.

## [1.1.1] - 2026-10-18

### Fixed

- The build's OpenRouter smoke test now overrides the image's `openclaw`
  entrypoint with `node`. Before this, the v1.1.0 build failed at that step
  and published nothing.

## [1.1.0] - 2026-10-18

### Added

- The OpenRouter image generation provider honors
  `models.providers.openrouter.request.allowPrivateNetwork`, so image
  generation can route through Trentina's private `/llm/openrouter` proxy
  (RT #1534). This is a build-time patch, because upstream hardcodes a
  private-network deny.

### Changed

- Constitution is now a v1.18.0 manifest: fleet and profile rules apply by
  reference, and the file keeps only what is specific to this repo.
- Constitution validation is pinned to the inherited release via
  `.github/workflows/constitution.yml`.
- Dependabot auto-merges GitHub Actions minor and patch updates.

## [1.0.1] - 2026-09-20

### Security

- Bumped CVE-flagged npm dependencies (17 findings, 15 HIGH + 2 CRITICAL):
  `tar` 7.5.11 -> 7.5.22 (CVE-2026-59873 CRITICAL gzip-bomb DoS, plus two more
  DoS CVEs), `undici` 8.5.0 -> 8.10.2 (CVE-2026-13697), `fast-uri` 3.1.2 ->
  3.1.8 (6 CVEs, mostly SSRF via URL/hostname parsing confusion), `ip-address`
  10.2.0 -> 10.7.2 (CVE-2026-69192 SSRF), `brace-expansion` 5.0.6 -> 5.0.12
  (3 DoS CVEs). All same-major-line bumps. Also found and fixed a second,
  untouched copy of vulnerable `tar` nested under
  `node_modules/@openclaw/fs-safe` that the existing top-level override never
  reached -- overridden separately from within that subpackage.
  `mcporter`'s independently-resolved copies of fast-uri/ip-address were
  already clean at these same target versions, which is how the targets here
  were chosen rather than jumping to a new major (e.g. fast-uri 4.x).
  Verified: `openclaw --version` runs, npm remains stripped from the runtime
  image, no pre-fix version of any of the five packages remains anywhere in
  the built image.

## [1.0.0] - 2026-09-20

First tagged release. This image has been running in production since before
it had version control. No changes are recorded prior to this point --
RT #1484 added this file on 2026-09-19, before this repo's first tag.
