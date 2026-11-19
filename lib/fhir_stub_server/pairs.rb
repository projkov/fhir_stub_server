# frozen_string_literal: true

module FHIRStubServer
  # Loads `fhir.pairs`: each Pair is one expected request and the response configured for it.
  #
  #   - request:  { method: POST, path: /Patient/_search, query: { ... }, body: { family: Smith } }
  #     response: { status: 200, body_file: bundle.json }
  #
  # `path` is relative to the FHIR base and required; `method` defaults to GET, `status` to 200.
  # `query` and `body` map names to a value or a list of values. `body` is the form body and
  # only counts for `POST .../_search`; other writes match whatever body they send.
  # When several Pairs match a request, the first one answers.
  module Pairs
    BODY_KINDS = %w[body_file select resource].freeze

    def self.load(pairs)
      pairs.each_with_index.map do |pair, index|
        where = "fhir.pairs[#{index}]"
        { key: key(request(pair['request'].to_h, where)), response: response(pair['response'].to_h, where) }
      end
    end

    # What a request and a Pair must share to match: role, method, path, query and, for
    # `POST .../_search`, the form body. Queries are { name => sorted values }, so order is ignored.
    def self.key(request)
      method = request[:method]
      path = request[:path]
      form = Stub.parse_query(request[:body].to_s) if method == 'POST' && path.end_with?('/_search')
      [request[:role], method, path, request[:query], form]
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

    def self.response(config, where)
      kinds = BODY_KINDS & config.keys
      raise Error, "#{where}: the response needs exactly one of #{BODY_KINDS.join(', ')}" unless kinds.one?
      raise Error, "#{where}: #{kinds.first} is not supported yet" unless kinds == ['body_file']

      [config.fetch('status', 200), FHIRStubServer.read_file(config['body_file'])]
    end

    private_class_method :request, :response
  end
end
