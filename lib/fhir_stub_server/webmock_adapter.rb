# frozen_string_literal: true

FHIRStubServer.require_gem('webmock', 'FHIRStubServer::WebMockAdapter')

module FHIRStubServer
  # Sends requests WebMock intercepts under the given base URLs to a Stub, for in-process runs.
  # Requests outside these base URLs are left to WebMock (and `disable_net_connect!`), as are
  # validator calls when the Stub has no validator block.
  module WebMockAdapter
    def self.install(stub, fhir_base_url:, validator_base_url: nil)
      WebMock.enable! # a plain `require 'webmock'` intercepts nothing; webmock/rspec enables it
      # The default notation parses the query into a Hash and keeps only the last of repeated
      # parameters (`date=ge2020&date=le2021`). Global: hash_including query stubs stop matching.
      WebMock::Config.instance.query_values_notation = :flat_array
      { fhir: fhir_base_url, validator: (validator_base_url if stub.validator?) }.compact.each do |role, base_url|
        route(stub, role, base_url.chomp('/'))
      end
    end

    def self.route(stub, role, base_url)
      WebMock.stub_request(:any, %r{\A#{Regexp.escape(base_url)}(?=[/?]|\z)}).to_return do |request|
        status, headers, body = stub.respond(stub_request(request, role, base_url))
        { status:, headers:, body: }
      end
    end

    def self.stub_request(request, role, base_url)
      uri = request.uri
      Request.build(
        role:, method: request.method.to_s.upcase, base_url:,
        path: uri.path.delete_prefix(URI(base_url).path),
        query: uri.query.to_s,
        body: request.body
      )
    end

    private_class_method :route, :stub_request
  end
end
