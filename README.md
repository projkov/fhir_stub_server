# fhir_stub_server

[![CI](https://github.com/projkov/fhir_stub_server/actions/workflows/ci.yml/badge.svg)](https://github.com/projkov/fhir_stub_server/actions/workflows/ci.yml)
[API reference](https://rubydoc.info/gems/fhir_stub_server)

A strict stub for the FHIR server under test and for Inferno's validator, for regression
tests of FHIR test kits. It answers only the requests a Scenario declares, serves IG
examples as Demo Data without copying them, and reports every request it could not
answer with a diff against the nearest declared one. It behaves the same in the rspec
process (through WebMock) and over HTTP (for a child `inferno execute` process).

It is IG-agnostic: it knows FHIR packages, Bundles and FHIRPath, nothing about a
specific IG.

## Install

Add it to the test kit's Gemfile, never to its gemspec, together with the gems of the
adapters you use:

```ruby
group :development, :test do
  gem 'fhir_stub_server', '~> 0.1'
  gem 'webmock' # FHIRStubServer::WebMockAdapter
  gem 'puma'    # FHIRStubServer::HTTPServer and fhir-stub-server
  gem 'rackup'  # only for `bundle exec rackup`
end
```

For changes not released yet, use
`gem 'fhir_stub_server', github: 'projkov/fhir_stub_server', ref: '<sha>'` instead.

The core needs only `fhirpath-rb`. An adapter whose gem is missing raises a
`FHIRStubServer::Error` naming it. To work on the kit and this gem together:
`bundle config local.fhir_stub_server <path>`.

## Config

One YAML file per Scenario. It has no URLs or base paths, so it works in both modes.
Paths are relative to the file.

```yaml
fhir:
  sources:                       # Demo Data, in order: a later Source wins on the same Type/id
    - package: ../igs/1.0.0.tgz  # a FHIR NPM package archive
    - bundle: overrides.json     # a Bundle of any type: its entry.resource items
  pairs:
    - request: { path: /Patient, query: { family: Smith } }
      response:
        select: "Bundle.entry.resource.ofType(Patient).where(name.family = 'Smith')"
validator:                       # optional
  pairs:
    - { profile: au-core-patient|1.0.0, resource: Patient/p1, issues: [] }
  expected_context: { sv: 4.0.1 }
```

Quote dates and times (`birthdate: '1970-01-01'`): unquoted, YAML reads them as dates,
which the config does not accept.

`FHIRStubServer.load(path)` reads such a file, or the `server:` block of a kit's
`scenario.yml`, and returns a `FHIRStubServer::Stub`. `FHIRStubServer::Stub.new(hash, dir: '.')`
takes the same config as a Hash, its paths relative to `dir` (by default the working
directory).

Every config error raises a `FHIRStubServer::Error` naming the file or Pair when the
Stub is built, never when a request arrives: a missing or invalid file, the same
`Type/id` twice in one package, several server CapabilityStatements, a Pair response
with zero or several body kinds, `include` without `select`, a `resource` expression
yielding zero or several resources, an included file that is no list, an include cycle.

### Sources and Demo Data

- A package contributes every `*.json` with a `resourceType` key, conformance resources
  included. Files without one (`package.json`, `.index.json`, `openapi/`) and `xml/` are
  ignored. A Bundle in a package stays whole, as `Bundle/<id>`.
- A resource without an `id` is skipped and recorded as a load-time entry in `#served`.
- Without any Pair, Demo Data answers `GET /<Type>/<id>`, and `GET /metadata` with the
  one CapabilityStatement whose `rest.mode` is `server` (an IG's responder). Only a read
  without query parameters is answered; `GET /Patient/p1?x=1` is a miss unless a Pair
  declares it.

### Pairs

A Pair is one expected request and the response configured for it.

- `request`: `path` (relative to the FHIR base, required), `method` (default `GET`),
  `query` and, for `POST .../_search`, the form `body`: each maps a name to a value or a
  list of values.
- A request matches on method, path and its query (and form body) as an unordered
  multiset of exact values. Headers are ignored. The first matching Pair answers, and a
  Pair wins over a Demo Data read, so it can force a 404 or an altered resource.
- `response`: optional `status` (default 200) and exactly one body kind:
  - `body_file`: a file sent as it is;
  - `resource: <fhirpath>`: the one resource the expression yields;
  - `select: <fhirpath>`, optionally with `include: <fhirpath>`: a `searchset` Bundle of
    the matches (`search.mode: match`, counted in `total`) and includes
    (`search.mode: include`), with `fullUrl`s and a `self` link built from the request's
    base URL. No paging.
- Expressions are literal FHIRPath, evaluated once over a `collection` Bundle of all
  Demo Data (after overrides).
- Writes (`POST`, `PUT`) get their Pair's response and never change Demo Data.
- Any other request gets a 404 OperationOutcome and is recorded in `#unmatched`.

Pairs that several Scenarios share go in their own file. An entry `- from: <path>` in
`fhir.pairs` or `validator.pairs` is replaced by the Pairs of that file, a YAML list that
may itself have `from:` entries; paths in it (`from`, `body_file`) are relative to it.
Only splicing: a Scenario that needs a different Pair writes its own, and the first
matching Pair still answers.

```yaml
# scenario.yml
fhir:
  pairs:
    - from: ../_shared/patient_searches.yml
    - request: { path: /Observation }
      response: { select: "Bundle.entry.resource.ofType(Observation)" }
```

```yaml
# ../_shared/patient_searches.yml
- request: { path: /Patient, query: { family: Smith } }
  response: { body_file: smith.json } # ../_shared/smith.json
```

### Validator

The Stub can stand in for Inferno's validator wrapper. `POST /validate` is matched on
the profile (`filesToValidate[0].fileName` without `.json`) and the `Type/id` of the
file's content; `sessionId` is ignored. Inferno names the file after the last segment
of the profile URL, version included, so a Pair for
`http://example.org/StructureDefinition/au-core-patient|1.0.0` says
`profile: au-core-patient|1.0.0`. A matching Pair answers
`{ "sessionId": "stub", "outcomes": [{ "issues": issues }] }`.

`expected_context` lists the validator settings to check: each key is compared exactly
with the request's `cliContext` (or `validationContext`), and other keys are ignored. A
mismatch is recorded in `#context_mismatches`, and the call is still answered. Without a
`validator:` block the adapters route only the FHIR role, so the real validator can be
used.

## Reports

Reports name a Pair by where it is written: `fhir.pairs[1]`, `validator.pairs[0]`, or,
for a Pair from an included file, the entry that includes it and its place in each file
along the way, paths relative to the config: `fhir.pairs[0] (../_shared/patient_searches.yml[7])`.

After a run, each in arrival order and the same for both adapters:

- `stub.unmatched`: `{ request:, nearest_pair:, differences:, suggested_request: }` per
  unanswered request. `nearest_pair` names the Pair with the same method and path and the
  fewest differing parameters; `differences` maps each differing parameter to
  `{ expected:, actual: }` (`nil` for a parameter missing on one side).
  `suggested_request` is what to paste as the `request` of a new Pair, as the config
  writes it: `method` only when not GET, `path`, `query` and, for `POST .../_search`, the
  form `body`, a single value unwrapped. For a validator miss it is `{ 'profile' =>,
  'resource' => }` (add `issues`), or `nil` when the request is no validate call.
- `stub.context_mismatches`: `{ request:, key:, expected:, actual: }`.
- `stub.served`: `{ kind: :load, skipped:, reason: }` for each skipped resource, then
  `{ kind: :request, request:, answered_by: }` per request, `answered_by` naming the
  answering Pair, or `:demo_data` or `:miss`.

`stub.unused_pairs` lists, in config order (`fhir.pairs`, then `validator.pairs`), the
Pairs no request was answered by: `{ role:, pair:, request: }`, `pair` naming where it
is written and `request` the request it matches, shaped like a `suggested_request`
(`{ 'profile' =>, 'resource' => }` for a validator Pair). As a kit changes, Pairs stop being requested;
assert `expect(stub.unused_pairs).to be_empty, stub.unused_pairs_report` to notice.

## In process: WebMock

```ruby
stub = FHIRStubServer.load('spec/fixtures/scenario.yml')
FHIRStubServer::WebMockAdapter.install(stub, fhir_base_url: 'http://fhir.stub.test/fhir',
                                             validator_base_url: 'http://validator.stub.test')
# run the suite against http://fhir.stub.test/fhir, then:
expect(stub.unmatched).to be_empty, stub.unmatched_report
expect(stub.unused_pairs).to be_empty, stub.unused_pairs_report
```

`install` registers one catch-all WebMock stub per base URL. Requests outside them
still raise through `WebMock.disable_net_connect!`.

- `install` sets `WebMock::Config.instance.query_values_notation = :flat_array`
  globally, so repeated query parameters are kept. In the same process,
  `hash_including` and `hash_excluding` query stubs stop matching; plain Hash and
  URL-string queries still work.
- `webmock/rspec` resets stubs after every example, so install per example.

## Over HTTP: Rack and Puma

```ruby
server = FHIRStubServer::HTTPServer.new(stub)
base_url = server.start # e.g. http://127.0.0.1:53214, FHIR under /fhir, validator under /validator
# run `inferno execute` against "#{base_url}/fhir"
server.stop
```

`HTTPServer` serves the Stub with Puma on a random free port of `127.0.0.1`, in a
background thread. `FHIRStubServer::RackApp.new(stub, fhir_base_path: '/fhir',
validator_base_path: '/validator')` is the Rack app behind it, for any Rack server.
Requests outside both base paths get a plain 404 and are not recorded.
`HTTPServer.new` also takes any other Rack app (such as a `Replay`) and serves it as it is;
`#wait` blocks until `#stop`.

## Scenario replay

To point Inferno's UI at one Scenario's Stub:

```bash
bundle exec fhir-stub-server spec/fixtures/scenario.yml
# FHIR base URL: http://127.0.0.1:53214/fhir
```

or, with Rack tooling and a port of your choice:

```bash
STUB_SERVER_CONFIG=spec/fixtures/scenario.yml bundle exec rackup "$(bundle info --path fhir_stub_server)/config.ru" -p 9292
```

Both log load-time skips at start and each unmatched request with its nearest Pair and
differences; nothing fails on a miss. `fhir-stub-server` also logs the unused Pairs on
shutdown.

## Working with LLM agents

An agent maintaining a kit's Scenarios works in a loop:

1. Run the kit's specs. Assert with `expect(stub.unmatched).to be_empty, stub.unmatched_report`:
   a failure then lists one line per request the Stub could not answer, with its nearest
   Pair, the differences and a suggested request:

   ```text
   Unmatched fhir GET /Observation?_count=10&code=8867-4&patient=p2; nearest fhir.pairs[1]: _count expected nil, got ["10"]; patient expected ["p1"], got ["p2"]; request: {"path":"/Observation","query":{"_count":"10","code":"8867-4","patient":"p2"}}
   ```

2. Decide for each line whether the kit changed on purpose or regressed. A regression is
   fixed in the kit, never by declaring the request: the Stub is strict so that drift shows.
3. For an intended request, paste the JSON after `request:` into `fhir.pairs` as
   `- request: <JSON>` (JSON is valid YAML) and write its `response`. A validator line ends
   with `pair: <JSON>`: paste it into `validator.pairs` as `- <JSON>` and add `issues`.
   When the nearest Pair is in a shared file (`nearest fhir.pairs[0] (../_shared/x.yml[7])`)
   and the change holds for every Scenario that includes it, edit the shared file;
   otherwise add the Pair to the Scenario, above the `from:` entry so that it answers first.
4. Rerun until the report is empty; check `stub.context_mismatches` too.
5. Assert `expect(stub.unused_pairs).to be_empty, stub.unused_pairs_report`: each line
   names a Pair no request used and its request:

   ```text
   Unused fhir.pairs[0] (../_shared/x.yml[7]): {"path":"/Observation","query":{"patient":"p1"}}
   ```

   Remove the Pair, or fix it when the kit still sends that request in another form (an
   `Unmatched` line then names it as the nearest Pair). Remove a Pair from a shared file
   only when no Scenario that includes it uses it.

Pitfalls:

- Quote dates and times in the YAML (`birthdate: '1970-01-01'`).
- Built-in reads (`GET /<Type>/<id>`, `GET /metadata`) answer only without query
  parameters; a read that sends one needs a Pair.
- When several Pairs match a request, the first answers, and a Pair wins over Demo Data.
- `package`, `bundle`, `body_file` and `from` paths are relative to the file that names them.

To point a kit's own agents here, add a line to its `AGENTS.md`:

```markdown
- Stub configs use fhir_stub_server: read "Working with LLM agents" in its README (`bundle info --path fhir_stub_server`) before changing them.
```

## Development

```bash
bin/setup
bundle exec rake # specs, then rubocop, reek, flay, flog and steep
```

CI runs the same `bundle exec rake` on Ruby 3.3 and 4.0 for every push to `main` and every
pull request.

To release:

1. Set `VERSION` in `lib/fhir_stub_server/version.rb`, run `bundle install` to update
   `Gemfile.lock`, and rename `## [Unreleased]` in `CHANGELOG.md` to
   `## [<VERSION>] - <date>` above a new, empty `## [Unreleased]`. Commit and push.
2. Publish a GitHub release tagged `v<VERSION>` whose notes link to that `CHANGELOG.md`
   section. The Release workflow checks the tag and the changelog, runs `bundle exec rake`
   and pushes the gem to RubyGems through trusted publishing.

Whether RubyGems treats it as a prerelease depends on `VERSION` (`0.2.0.rc1`), not on
GitHub's pre-release checkbox.

## License

Apache-2.0. See [LICENSE.txt](LICENSE.txt).
