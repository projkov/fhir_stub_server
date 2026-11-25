# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `- from: <path>` entries in `fhir.pairs` and `validator.pairs`: the Pairs of a shared
  YAML file, spliced in at that position, its paths relative to it.
- `Stub#unused_pairs` and `Stub#unused_pairs_report`: the Pairs no request used, in config
  order. `fhir-stub-server` logs them on shutdown.
- `page_size: n` on a `select` response: the searchset comes in pages of n matches, each
  but the last with a `next` link to a Stub-served continuation URL (`<base>/_page/...`).
- `Stub#empty_selects`: each `select` or `include` that yielded nothing at build time,
  but for Pairs whose response says `expect_empty: true`. Scenario replay logs them at
  start.
- `WebMockAdapter.uninstall`: restores the WebMock query notation `install` replaced, so
  `hash_including` query stubs match again after the example.

### Changed

- FHIRPath expressions are evaluated with the FHIR model of the packages' `fhirVersions`
  (R4 when no package states one), so choice elements resolve (`effective` finds an
  `effectiveDateTime`). Packages that share no FHIR version with a model (R4B alone,
  or R4 next to R5) raise when the Stub is built.
- `answered_by` and `nearest_pair` name the Pair by where it is written
  (`fhir.pairs[1]`, `fhir.pairs[0] (shared.yml[7])`) instead of giving its index.

## [0.1.0] - 2026-11-20

Initial release.

### Added

- Demo Data from FHIR NPM packages and Bundles, answering built-in reads
  (`GET /<Type>/<id>`, `GET /metadata`).
- Pairs matched on method, path, query and form body, answered from a file or with
  FHIRPath (`resource`, `select` with `include`).
- A validator role: canned issues per profile and resource, and `expected_context` checks.
- Reports: `#served`, `#context_mismatches` and `#unmatched`, each miss with its nearest
  Pair, the differences and a paste-ready `suggested_request`; `Stub#unmatched_report`.
- Adapters: in process through WebMock, over HTTP through `RackApp` and `HTTPServer` (Puma).
- YAML configs through `FHIRStubServer.load`, and Scenario replay with `fhir-stub-server`
  and `config.ru`.
