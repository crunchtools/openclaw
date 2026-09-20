# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/) and this project adheres to
[Semantic Versioning](https://semver.org/).

## [Unreleased]

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
