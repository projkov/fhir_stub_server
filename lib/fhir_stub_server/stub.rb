# frozen_string_literal: true

module FHIRStubServer
  # Answers requests from Demo Data and records what answered each one.
  # Adapters build the request Hash and send the [status, headers, body] response back.
  class Stub
    def initialize(config)
      demo_data, served = Sources.load(config.dig('fhir', 'sources') || [])
      @reads = Sources.reads(demo_data)
      @pairs = Pairs.load(config.dig('fhir', 'pairs') || [], demo_data)
      validator = config['validator']
      @validator = Validator.load(validator) if validator
      @reports = { served:, unmatched: [], context_mismatches: [] }
    end

    def served = @reports[:served]
    def unmatched = @reports[:unmatched]
    def context_mismatches = @reports[:context_mismatches]

    # Whether the config has a `validator:` block; without one the adapters route only the FHIR role.
    def validator? = @validator ? true : false

    # #served starts with the load-time entries; each request adds `answered_by`: the index of
    # the Pair that answered (in `fhir.pairs` or `validator.pairs`, by the request's role),
    # :demo_data or :miss.
    def respond(request)
      answered_by, response = answer(request)
      served << { kind: :request, request:, answered_by: }
      unmatched << { request:, **Pairs.near_miss(@pairs, request) } if answered_by == :miss
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

    # The path of a FHIR GET without query parameters, which a built-in read may answer; nil for
    # anything else, so a read that gains a parameter is a miss unless a Pair declares it.
    def self.read_path(request)
      request[:path] if request[:role] == :fhir && request[:method] == 'GET' && request[:query].empty?
    end

    private

    # A Pair first, so it can override a read; then a built-in read; then a miss.
    def answer(request)
      found = request[:role] == :validator ? validator_answer(request) : pair_answer(request) || read_answer(request)
      found || [:miss, Responses.not_found(request)]
    end

    # A context mismatch is reported, but a matching Pair still answers.
    def validator_answer(request)
      validator = @validator
      return unless validator

      index, mismatches = Validator.match(validator, request)
      context_mismatches.concat(mismatches)
      [index, Responses.validation(validator[:pairs].fetch(index).last)] if index
    end

    def pair_answer(request)
      index = pair_index(request)
      return unless index

      pair = @pairs.fetch(index)
      [index, Responses.raw(pair[:status], pair[:body].call(request))]
    end

    def pair_index(request)
      key = Pairs.key(request)
      @pairs.index { |pair| pair[:key] == key }
    end

    def read_answer(request)
      resource = @reads[Stub.read_path(request)]
      [:demo_data, Responses.fhir(200, resource)] if resource
    end
  end
end
