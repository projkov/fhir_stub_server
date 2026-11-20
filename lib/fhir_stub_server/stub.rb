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
      @roles = { fhir: FHIRRole.new(fhir, demo_data, dir), validator: Validator.new(validator.to_h) }
      @reports = { served:, unmatched: [], context_mismatches: [] }
    end

    def served = @reports[:served]
    def unmatched = @reports[:unmatched]
    def context_mismatches = @reports[:context_mismatches]

    # Whether the config has a `validator:` block; without one the adapters route only the FHIR role.
    def validator? = @validator

    # #served starts with the load-time entries; each request adds `answered_by`: the index of
    # the Pair that answered (in `fhir.pairs` or `validator.pairs`, by the request's role),
    # :demo_data or :miss. The role builds the report entries; Stub only appends them.
    def respond(request)
      answered_by, response, reports = @roles.fetch(request[:role]).answer(request)
      served << { kind: :request, request:, answered_by: }
      reports.each { |name, entries| @reports.fetch(name).concat(entries) }
      response
    end
  end
end
