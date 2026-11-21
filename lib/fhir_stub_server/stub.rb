# frozen_string_literal: true

module FHIRStubServer
  # Hands each request to its role (FHIRRole or Validator) and records what answered it.
  # Adapters build the request Hash and send the [status, headers, body] response back.
  class Stub
    # File paths in the config are relative to `dir`, by default the working directory.
    def initialize(config, dir: '.')
      fhir = config['fhir'].to_h
      demo_data, served = Sources.load(fhir['sources'].to_a, dir)
      validator = config['validator']
      @validator = validator ? true : false
      @roles = { fhir: FHIRRole.new(fhir, demo_data, dir), validator: Validator.new(validator.to_h, dir) }
      @reports = { served:, unmatched: [], context_mismatches: [] }
    end

    def served = @reports[:served]
    def unmatched = @reports[:unmatched]
    def context_mismatches = @reports[:context_mismatches]

    # #unmatched as one line per miss (see Unmatched.describe), empty when there is none:
    # a readable failure message for `expect(stub.unmatched).to be_empty, stub.unmatched_report`.
    def unmatched_report = unmatched.map { |miss| Unmatched.describe(miss) }.join("\n")

    # One `{ role:, pair:, request: }` per Pair no request was answered by, in config order:
    # `pair` names where it is written, `request` the request it matches, shaped like a
    # `suggested_request` (for a validator Pair, its profile and resource).
    def unused_pairs
      used = served.to_set { |entry| entry[:answered_by] }
      @roles.values.flat_map(&:pairs).reject { |entry| used.include?(entry[:pair]) }
    end

    # #unused_pairs as one line per Pair, empty when there is none.
    def unused_pairs_report
      unused_pairs.map { |entry| entry.values_at(:pair, :request) }
                  .map { |pair, request| "Unused #{pair}: #{JSON.generate(request)}" }.join("\n")
    end

    # Whether the config has a `validator:` block; without one the adapters route only the FHIR role.
    def validator? = @validator

    # #served starts with the load-time entries; each request adds `answered_by`: where the
    # answering Pair is written (see Includes), :demo_data or :miss. The role builds the report
    # entries; Stub only appends them.
    def respond(request)
      answered_by, response, reports = @roles.fetch(request[:role]).answer(request)
      served << { kind: :request, request:, answered_by: }
      reports.each { |name, entries| @reports.fetch(name).concat(entries) }
      response
    end
  end
end
