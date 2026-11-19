# frozen_string_literal: true

module FHIRStubServer
  # Answers requests from Demo Data and records what answered each one.
  # Adapters build the request Hash and send the [status, headers, body] response back.
  class Stub
    READ_PATH = %r{\A/(?<type>[A-Z][A-Za-z]+)/(?<id>[A-Za-z0-9\-.]{1,64})\z}

    attr_reader :served, :unmatched

    def initialize(config)
      @demo_data = Sources.load(config.dig('fhir', 'sources') || [])
      @pairs = Pairs.load(config.dig('fhir', 'pairs') || [])
      @served = []
      @unmatched = []
    end

    # `answered_by` in #served is the index of the Pair that answered, :demo_data or :miss.
    def respond(request)
      answered_by, response = answer(request)
      @served << { kind: :request, request:, answered_by: }
      @unmatched << { request: } if answered_by == :miss
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

    # The Demo Data key for a plain `GET /<Type>/<id>` FHIR read, nil for anything else.
    def self.read_key(request)
      match = READ_PATH.match(request[:path])
      "#{match[:type]}/#{match[:id]}" if match && request[:role] == :fhir && request[:method] == 'GET'
    end

    private

    # A Pair first, so it can override a read; then a Demo Data read; then a miss.
    def answer(request)
      pair_answer(request) || read_answer(request) || [:miss, Responses.not_found(request)]
    end

    def pair_answer(request)
      index = pair_index(request)
      return unless index

      status, body = @pairs.fetch(index)[:response]
      [index, Responses.raw(status, body)]
    end

    def pair_index(request)
      key = Pairs.key(request)
      @pairs.index { |pair| pair[:key] == key }
    end

    def read_answer(request)
      resource = @demo_data[Stub.read_key(request)]
      [:demo_data, Responses.fhir(200, resource)] if resource
    end
  end
end
