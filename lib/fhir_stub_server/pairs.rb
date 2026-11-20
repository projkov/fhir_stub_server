# frozen_string_literal: true

module FHIRStubServer
  # Loads `fhir.pairs`: each Pair is one expected request and the response configured for it.
  #
  #   - request:  { method: POST, path: /Patient/_search, query: { ... }, body: { family: Smith } }
  #     response: { status: 200, body_file: bundle.json }
  #
  # The response has exactly one body kind: `body_file` (literal JSON), `resource` (a FHIRPath
  # expression yielding exactly one resource) or `select` (FHIRPath, answered as a searchset;
  # an optional `include` adds resources with search.mode include). Expressions run once, over
  # a collection Bundle of all Demo Data, when the Stub is built.
  #
  # `path` is relative to the FHIR base and required; `method` defaults to GET, `status` to 200.
  # `query` and `body` map names to a value or a list of values. `body` is the form body and
  # only counts for `POST .../_search`; other writes match whatever body they send.
  # When several Pairs match a request, the first one answers.
  module Pairs
    BODY_KINDS = %w[body_file select resource].freeze

    def self.load(pairs, demo_data, dir)
      bundle = { 'resourceType' => 'Bundle', 'type' => 'collection',
                 'entry' => demo_data.values.map { |resource| { 'resource' => resource } } }
      pairs.each_with_index.map { |pair, index| build(with_dir(pair, dir), bundle, "fhir.pairs[#{index}]") }
    end

    # The Pair with its `body_file` relative to `dir`.
    def self.with_dir(pair, dir)
      response = pair['response'].to_h
      file = response['body_file']
      file ? pair.merge('response' => response.merge('body_file' => File.expand_path(file, dir))) : pair
    end

    # What a request and a Pair must share to match: method, path, query and, for
    # `POST .../_search`, the form body. Queries are { name => sorted values }, so order is ignored.
    def self.key(request)
      method = request[:method]
      path = request[:path]
      form = Stub.parse_query(request[:body].to_s) if method == 'POST' && path.end_with?('/_search')
      [method, path, request[:query], form]
    end

    # [index, response] of the first Pair matching the request; nil when none does.
    def self.answer(pairs, request)
      index = match(pairs, request)
      return unless index

      pair = pairs.fetch(index)
      [index, Responses.raw(pair[:status], pair[:body].call(request))]
    end

    def self.match(pairs, request)
      key = key(request)
      pairs.index { |pair| pair[:key] == key }
    end

    # The Pair an unmatched request most likely meant: same method and path, fewest
    # differing parameters, the first on a tie. Differences are keyed by parameter name: expected
    # holds the Pair's values (nil: extra in the request), actual the request's (nil: missing).
    def self.near_miss(pairs, request)
      index, differences = candidates(pairs, key(request)).min_by { |candidate| candidate.last.size }
      { nearest_pair: index, differences: differences || {} }
    end

    # [index, differences] for each Pair with the request's method and path.
    def self.candidates(pairs, key)
      pairs.each_with_index.filter_map do |pair, index|
        pair_key = pair[:key]
        [index, differences(pair_key, key)] if pair_key.take(2) == key.take(2)
      end
    end

    # Query and form body differences in one Hash; a name differing in both keeps the form body's.
    def self.differences(pair_key, request_key)
      diff(pair_key[2], request_key[2]).merge(diff(pair_key[3].to_h, request_key[3].to_h))
    end

    def self.diff(expected, actual)
      (expected.keys | actual.keys).sort.filter_map do |name|
        values = { expected: expected[name], actual: actual[name] }
        [name, values] unless values[:expected] == values[:actual]
      end.to_h
    end

    def self.build(pair, bundle, where)
      response = pair['response'].to_h
      { key: key(request(pair['request'].to_h, where)), status: response.fetch('status', 200),
        body: body(response, bundle, where) }
    end

    # The Pair's request, normalized exactly like an incoming one.
    def self.request(config, where)
      path = config['path'].to_s
      raise Error, "#{where}: the request needs a path starting with /" unless path.start_with?('/')

      Stub.request(
        role: :fhir, method: config.fetch('method', 'GET').upcase, base_url: '', path:,
        query: URI.encode_www_form(config['query'].to_h), body: URI.encode_www_form(config['body'].to_h)
      )
    end

    # A lambda building the body for a matched request. Only a searchset needs the request:
    # its fullUrls and self link use the request's base URL.
    def self.body(config, bundle, where)
      return literal_body(config, bundle, where) unless body_kind(config, where) == 'select'

      matches = evaluate(config['select'], bundle, where)
      includes = evaluate(config['include'], bundle, where).uniq - matches # each fullUrl once
      ->(request) { Responses.searchset(request, matches, includes) }
    end

    # The fixed body of a `body_file` or `resource` response.
    def self.literal_body(config, bundle, where)
      body = if config.key?('body_file')
               FHIRStubServer.read_file(config['body_file'])
             else
               JSON.generate(one_resource(evaluate(config['resource'], bundle, where), where))
             end
      ->(_request) { body }
    end

    def self.body_kind(config, where)
      kinds = BODY_KINDS & config.keys
      raise Error, "#{where}: the response needs exactly one of #{BODY_KINDS.join(', ')}" unless kinds.one?
      raise Error, "#{where}: include needs select" if config['include'] && kinds != ['select']

      kinds.first
    end

    def self.evaluate(expression, bundle, where)
      return [] unless expression

      resources_only(Fhirpath.evaluate(bundle, expression), "#{where}: #{expression}")
    rescue Fhirpath::Error => error
      raise Error, "#{where}: #{expression}: #{error.message}"
    end

    def self.resources_only(results, label)
      return results if results.all? { |result| result.is_a?(Hash) && result['resourceType'] }

      raise Error, "#{label} must yield resources only"
    end

    def self.one_resource(results, where)
      return results.first if results.one?

      raise Error, "#{where}: resource must yield exactly one resource, got #{results.size}"
    end

    private_class_method :with_dir, :match, :candidates, :differences, :diff, :build, :request, :body,
                         :literal_body, :body_kind, :evaluate, :resources_only, :one_resource
  end
end
