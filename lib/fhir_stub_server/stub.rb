# frozen_string_literal: true

module FHIRStubServer
  # Hands each request to its role (FHIRRole or Validator) and records what answered it.
  # Adapters build the request Hash and send the [status, headers, body] response back.
  class Stub
    def initialize(config)
      fhir = config['fhir'].to_h
      demo_data, served = Sources.load(fhir['sources'].to_a)
      validator = config['validator']
      @validator = validator ? true : false
      @roles = { fhir: FHIRRole.new(fhir, demo_data), validator: Validator.new(validator.to_h) }
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

    # Turns the raw values an adapter reads (query and body as strings) into the request
    # #respond takes, the same way for every adapter: path percent-decoded, query as
    # { name => sorted values } (repeats kept, order ignored), the body as UTF-8 (Rack hands it
    # over as binary) and an empty body as nil.
    def self.request(raw)
      body = raw[:body].to_s.dup.force_encoding(Encoding::UTF_8)
      {
        role: raw[:role], method: raw[:method], base_url: raw[:base_url],
        path: URI.decode_uri_component(raw[:path]), query: parse_query(raw[:query]),
        body: (body unless body.empty?)
      }
    end

    # Raw non-ASCII bytes (a form body sent as UTF-8) are percent-encoded first:
    # URI.decode_www_form rejects them.
    def self.parse_query(query)
      ascii = query.b.gsub(/[^\x00-\x7F]/n) { |byte| format('%%%02X', byte.ord) }
      URI.decode_www_form(ascii).group_by(&:first).sort.to_h { |name, pairs| [name, pairs.map(&:last).sort] }
    end
  end
end
