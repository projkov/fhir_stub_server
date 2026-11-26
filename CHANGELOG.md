# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Write Pairs: `request.method` takes `GET`, `POST`, `PUT`, `PATCH` or `DELETE` (any
  case); another method is a config error. On `POST` (except `POST .../_search`), `PUT` and
  `PATCH`, `request.body` is the expected JSON body, an object or array (a JSON Patch
  included), compared with the parsed request body regardless of key order and
  whitespace. A write Pair without `body` still matches any body. A differing body is one
  `body` entry in a miss's `differences`, and `suggested_request` and `unused_pairs` carry
  the parsed body.
- A response with `status: 204` may have no body kind; it answers with an empty body and
  no `content-type`.

### Changed

- A `body` on a `GET` or `DELETE` Pair, formerly ignored, is a config error.

## [0.1.0] - 2026-11-25

Initial release.

### Added

- Demo Data from FHIR NPM packages and Bundles, answering built-in reads
  (`GET /<Type>/<id>`, `GET /metadata`).
- Pairs matched on method, path, query and form body, answered from a file or with
  FHIRPath (`resource`, `select` with `include`). Expressions are evaluated with the FHIR
  model of the packages' `fhirVersions` (R4 when no package states one), so choice
  elements resolve (`effective` finds an `effectiveDateTime`).
- `page_size: n` on a `select` response: the searchset comes in pages of n matches, each
  but the last with a `next` link to a Stub-served continuation URL (`<base>/_page/...`).
- `- from: <path>` entries in `fhir.pairs` and `validator.pairs`: the Pairs of a shared
  YAML file, spliced in at that position, its paths relative to it.
- A validator role: canned issues per profile and resource, and `expected_context` checks.
- Reports: `#served`, `#context_mismatches` and `#unmatched`, each miss with its nearest
  Pair, the differences and a paste-ready `suggested_request`; `Stub#unmatched_report`.
  They name a Pair by where it is written (`fhir.pairs[1]`, `fhir.pairs[0] (shared.yml[7])`).
- `Stub#unused_pairs` and `Stub#unused_pairs_report`: the Pairs no request used, in config
  order.
- `Stub#empty_selects`: each `select` or `include` that yielded nothing at build time,
  but for Pairs whose response says `expect_empty: true`.
- Adapters: in process through WebMock (`WebMockAdapter.install`, and `uninstall` to
  restore the query notation `install` replaced), over HTTP through `RackApp` and
  `HTTPServer` (Puma).
- YAML configs through `FHIRStubServer.load`, and Scenario replay with `fhir-stub-server`
  and `config.ru`: load-time skips and empty selects are logged at start, each miss as it
  arrives and, by `fhir-stub-server`, the unused Pairs on shutdown.
