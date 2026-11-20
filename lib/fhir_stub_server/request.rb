# frozen_string_literal: true

module FHIRStubServer
  # The request Hash Stub#respond takes, built the same way by every adapter and for every Pair,
  # and what a request and a Pair must share to match.
  # @api private
  module Request
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

    # Raw non-ASCII bytes (a form body sent as UTF-8) are percent-encoded first:
    # URI.decode_www_form rejects them.
    def self.parse_query(query)
      ascii = query.b.gsub(/[^\x00-\x7F]/n) { |byte| format('%%%02X', byte.ord) }
      URI.decode_www_form(ascii).group_by(&:first).sort.to_h { |name, pairs| [name, pairs.map(&:last).sort] }
    end

    # Method, path, query and, for `POST .../_search`, the form body (nil otherwise).
    def self.key(request)
      method = request[:method]
      path = request[:path]
      form = parse_query(request[:body].to_s) if method == 'POST' && path.end_with?('/_search')
      { method:, path:, query: request[:query], form: }
    end
  end
end
