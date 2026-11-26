# frozen_string_literal: true

module FHIRStubServer
  # The request Hash Stub#respond takes, built the same way by every adapter and for every Pair,
  # and what a request and a Pair must share to match.
  # @api private
  module Request
    # The methods a Pair may declare; a JSON body counts for the writes among them.
    METHODS = %w[GET POST PUT PATCH DELETE].freeze
    JSON_WRITES = %w[POST PUT PATCH].freeze

    # Turns the raw values an adapter reads (query and body as strings) into a request: path
    # percent-decoded, query as { name => sorted values } (repeats kept, order ignored), the body
    # as UTF-8 (Rack hands it over as binary) and an empty body as nil.
    def self.build(raw)
      body = raw[:body].to_s.dup.force_encoding(Encoding::UTF_8)
      {
        role: raw[:role], method: raw[:method], base_url: raw[:base_url],
        path: URI.decode_uri_component(raw[:path]), query: parse_query(raw[:query]),
        body: (body unless body.empty?)
      }
    end

    # A Pair's `request`, normalized exactly like an incoming one.
    def self.pair(config, where)
      path = config['path'].to_s
      raise Error, "#{where}: the request needs a path starting with /" unless path.start_with?('/')

      method = config.fetch('method', 'GET').to_s.upcase
      raise Error, "#{where}: the request method must be one of #{METHODS.join(', ')}, not #{method}" unless
        METHODS.include?(method)

      build(role: :fhir, method:, base_url: '', path:, query: URI.encode_www_form(config['query'].to_h),
            body: pair_body(config['body'], { method:, path: }, where))
    end

    # A Pair's `body` as a request sends it: a form for `POST .../_search`, JSON for other writes.
    def self.pair_body(body, request, where)
      return URI.encode_www_form(body.to_h) if !body || search?(request)

      method = request[:method]
      raise Error, "#{where}: a #{method} request has no body" unless JSON_WRITES.include?(method)
      raise Error, "#{where}: the body must be a JSON object or array" unless body.is_a?(Hash) || body.is_a?(Array)

      JSON.generate(body)
    end

    # Raw non-ASCII bytes (a form body sent as UTF-8) are percent-encoded first:
    # URI.decode_www_form rejects them.
    def self.parse_query(query)
      ascii = query.b.gsub(/[^\x00-\x7F]/n) { |byte| format('%%%02X', byte.ord) }
      URI.decode_www_form(ascii).group_by(&:first).sort.to_h { |name, pairs| [name, pairs.map(&:last).sort] }
    end

    # Method, path, query, and the form body of `POST .../_search` or the JSON body of another write.
    def self.key(request)
      method = request[:method]
      body = request[:body]
      search = search?(request)
      { method:, path: request[:path], query: request[:query], form: (parse_query(body.to_s) if search),
        json: (json(body) if !search && JSON_WRITES.include?(method)) }
    end

    # Whether a request's key matches a Pair's: a Pair without a JSON body takes any.
    def self.match?(pair_key, key)
      pair_key == (pair_key[:json] ? key : key.merge(json: nil))
    end

    def self.search?(request) = request[:method] == 'POST' && request[:path].end_with?('/_search')

    # The body parsed when it is a JSON object or array, else the body as it is. Invalid UTF-8
    # is not parsed: JSON.parse accepts it, JSON.generate (in the reports) raises on it.
    def self.json(body)
      text = body.to_s
      parsed = JSON.parse(text) if text.valid_encoding?
      parsed.is_a?(Hash) || parsed.is_a?(Array) ? parsed : body
    rescue JSON::ParserError
      body
    end

    private_class_method :pair_body, :json
  end
end
