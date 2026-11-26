# frozen_string_literal: true

module FHIRStubServer
  # Loads `fhir.pairs`: each Pair is one expected request and the response configured for it.
  #
  #   - request:  { method: POST, path: /Patient/_search, query: { ... }, body: { family: Smith } }
  #     response: { status: 200, body_file: bundle.json }
  #
  # The response has exactly one body kind: `body_file` (literal JSON), `resource` (a FHIRPath
  # expression yielding exactly one resource) or `select` (FHIRPath, answered as a searchset;
  # an optional `include` adds resources with search.mode include, an optional `page_size` pages
  # the matches, see Paging); a `status: 204` may have none and answers an empty body.
  # Expressions run once, over a collection Bundle of all Demo Data with the FHIR model of its
  # version (see Sources), when the Stub is built. An empty `select` or `include` is listed in
  # Stub#empty_selects, unless the response says `expect_empty: true`.
  #
  # `path` is relative to the FHIR base and required; `method` (GET, POST, PUT, PATCH or DELETE)
  # defaults to GET, `status` to 200. `query` maps names to a value or a list of values, and so
  # does `body` for `POST .../_search`, the form body. On other POSTs, PUT and PATCH, `body` is a
  # JSON object or array, compared with the parsed request body (key order and whitespace
  # ignored); without it any body matches. GET and DELETE take no `body`.
  # When several Pairs match a request, the first one answers. An entry `{ from: <path> }` is
  # replaced by the Pairs of that file (see Includes).
  # @api private
  module Pairs
    BODY_KINDS = %w[body_file select resource].freeze

    def self.load(pairs, fhirpath, dir)
      Includes.splice(pairs, 'fhir.pairs', dir).map do |pair, pair_dir, where|
        build(with_dir(pair, pair_dir), fhirpath, where)
      end
    end

    # A lambda evaluating an expression over all Demo Data, with fhirpath-rb's `model` (e.g. `r4`).
    def self.fhirpath(demo_data, model)
      bundle = { 'resourceType' => 'Bundle', 'type' => 'collection',
                 'entry' => demo_data.values.map { |resource| { 'resource' => resource } } }
      ->(expression) { Fhirpath.evaluate(bundle, expression, {}, model) }
    end

    # The Pair with its `body_file` relative to `dir`.
    def self.with_dir(pair, dir)
      response = pair['response'].to_h
      file = response['body_file']
      file ? pair.merge('response' => response.merge('body_file' => File.expand_path(file, dir))) : pair
    end

    # [where, response] of the first Pair matching the request, or of the Pair whose continuation
    # URL it is while that page exists (see Paging); nil when none does.
    def self.answer(pairs, request)
      index, page = Paging.locate(pairs, Request.key(request))
      pair = pairs[index] if index
      body = pair && page && pair[:body].call(request, page)
      [pair[:where], Responses.raw(pair[:status], body)] if pair && body
    end

    # The Pair an unmatched request most likely meant: same method and path, fewest
    # differing parameters, the first on a tie. Differences are keyed by parameter name: expected
    # holds the Pair's values (nil: extra in the request), actual the request's (nil: missing).
    def self.near_miss(pairs, request)
      where, differences = candidates(pairs, Request.key(request)).min_by { |candidate| candidate.last.size }
      { nearest_pair: where, differences: differences || {} }
    end

    # [where, differences] for each Pair with the request's method and path.
    def self.candidates(pairs, key)
      pairs.filter_map do |pair|
        pair_key = pair[:key]
        [pair[:where], differences(pair_key, key)] if pair_key.slice(:method, :path) == key.slice(:method, :path)
      end
    end

    # Query and form body differences in one Hash, a name differing in both keeping the form
    # body's, and a `body` entry for a differing JSON body.
    def self.differences(pair_key, request_key)
      diff(pair_key[:query], request_key[:query]).merge(diff(pair_key[:form].to_h, request_key[:form].to_h))
                                                 .merge(json_diff(pair_key[:json], request_key[:json]))
    end

    def self.json_diff(expected, actual)
      expected && expected != actual ? { 'body' => { expected:, actual: } } : {}
    end

    def self.diff(expected, actual)
      (expected.keys | actual.keys).sort.filter_map do |name|
        values = { expected: expected[name], actual: actual[name] }
        [name, values] unless values[:expected] == values[:actual]
      end.to_h
    end

    def self.build(pair, fhirpath, where)
      key = Request.key(Request.pair(pair['request'].to_h, where))
      response = pair['response'].to_h
      body, empty_selects = body(response, fhirpath, where)
      { key:, status: response.fetch('status', 200), body:, where:, empty_selects: }
    end

    # A lambda building the body of a matched request's page (from 1; nil past the last), and its
    # Stub#empty_selects entries. Only a searchset needs the request: its URLs use its base URL.
    def self.body(config, fhirpath, where)
      return [literal_body(config, fhirpath, where), []] unless body_kind(config, where) == 'select'

      expressions = config.slice('select', 'include').compact # `include: ~` is no expression
      results = expressions.transform_values { |expression| evaluate(expression, fhirpath, where) }
      [Paging.body(config, results, where), empty_selects(config, results, where)]
    end

    # One entry per `select` or `include` that yielded nothing; none when the response expects that.
    def self.empty_selects(config, results, where)
      return [] if config['expect_empty']

      results.filter_map { |name, found| { role: :fhir, pair: where, expression: config[name] } if found.empty? }
    end

    # The fixed body of a `body_file` or `resource` response, empty for a 204 without either.
    def self.literal_body(config, fhirpath, where)
      body = if config.key?('body_file')
               FHIRStubServer.read_file(config['body_file'])
             elsif config.key?('resource')
               JSON.generate(one_resource(evaluate(config['resource'], fhirpath, where), where))
             else
               ''
             end
      ->(_request, page) { body if page[:number] == 1 }
    end

    def self.body_kind(config, where)
      kinds = BODY_KINDS & config.keys
      raise Error, "#{where}: the response needs exactly one of #{BODY_KINDS.join(', ')}" unless
        kinds.one? || (kinds.empty? && config['status'] == 204)

      searchset_only = (%w[include page_size] & config.compact.keys).first unless kinds == ['select']
      raise Error, "#{where}: #{searchset_only} needs select" if searchset_only

      kinds.first
    end

    def self.evaluate(expression, fhirpath, where)
      return [] unless expression

      resources_only(fhirpath.call(expression), "#{where}: #{expression}")
    rescue StandardError => error # a Fhirpath::Error, or a fhirpath-rb bug such as a TypeError
      raise if error.is_a?(Error) # from resources_only, already labelled

      raise Error, "#{where}: #{expression}: #{error.class}: #{error.message}"
    end

    def self.resources_only(results, label)
      return results if results.all? { |result| result.is_a?(Hash) && result['resourceType'] }

      raise Error, "#{label} must yield resources only"
    end

    def self.one_resource(results, where)
      return results.first if results.one?

      raise Error, "#{where}: resource must yield exactly one resource, got #{results.size}"
    end

    private_class_method :with_dir, :candidates, :differences, :diff, :json_diff, :build, :body, :empty_selects,
                         :literal_body, :body_kind, :evaluate, :resources_only, :one_resource
  end
end
