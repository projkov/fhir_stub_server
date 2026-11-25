# frozen_string_literal: true

module FHIRStubServer
  # Answers FHIR requests from `fhir.pairs` and Demo Data, the way Stub expects of a role:
  # [answered_by, response, { report name => entries }].
  # @api private
  class FHIRRole
    def initialize(config, demo_data, model, dir)
      @pairs = Pairs.load(config['pairs'].to_a, Pairs.fhirpath(demo_data, model), dir)
      @reads = Sources.reads(demo_data)
    end

    # A Pair first, so it can override a read; then a built-in read; then a miss, reported with
    # the Pair it most likely meant.
    def answer(request)
      found = Pairs.answer(@pairs, request) || read_answer(request)
      return [found[0], found[1], {}] if found

      miss = { request:, **Pairs.near_miss(@pairs, request), suggested_request: FHIRRole.config(Request.key(request)) }
      [:miss, Responses.not_found(request), { unmatched: [miss] }]
    end

    # One entry per Pair, in config order, for Stub#unused_pairs.
    def pairs = FHIRRole.listed(@pairs)

    # Each `select` or `include` that yielded nothing, in config order, for Stub#empty_selects.
    def empty_selects = @pairs.flat_map { |pair| pair[:empty_selects] }

    # One `{ role:, pair:, request: }` per Pair: where it is written and its request.
    def self.listed(pairs)
      pairs.map { |pair| { role: :fhir, pair: pair[:where], request: config(pair[:key]) } }
    end

    # A key as the config writes a Pair's `request`: `method` only when not GET, a single value
    # unwrapped, the form `body` only for `POST .../_search`.
    def self.config(key)
      method = key[:method]
      { 'method' => (method unless method == 'GET'), 'path' => key[:path],
        'query' => config_values(key[:query]), 'body' => config_values(key[:form]) }.compact
    end

    def self.config_values(params)
      params = params.to_h
      params.transform_values { |values| values.one? ? values.first : values } unless params.empty?
    end

    private_class_method :config_values

    # The path of a GET without query parameters, which a built-in read may answer; nil for
    # anything else, so a read that gains a parameter is a miss unless a Pair declares it.
    def self.read_path(request)
      request[:path] if request[:method] == 'GET' && request[:query].empty?
    end

    private

    def read_answer(request)
      resource = @reads[FHIRRole.read_path(request)]
      [:demo_data, Responses.fhir(200, resource)] if resource
    end
  end
end
