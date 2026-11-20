# Changelog

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions
follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
