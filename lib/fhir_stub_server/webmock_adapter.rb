# frozen_string_literal: true

begin
  require 'webmock'
rescue LoadError
  raise FHIRStubServer::Error, 'FHIRStubServer::WebMockAdapter needs the webmock gem: add it to your Gemfile'
end

module FHIRStubServer
  # Sends requests WebMock intercepts under the given base URLs to a Stub, for in-process runs.
  # Requests outside these base URLs are left to WebMock (and `disable_net_connect!`).
  module WebMockAdapter
    def self.install(stub, fhir_base_url:, validator_base_url: nil)
      WebMock.enable! # a plain `require 'webmock'` intercepts nothing; webmock/rspec enables it
      { fhir: fhir_base_url, validator: validator_base_url }.compact.each do |role, base_url|
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
      {
        role:, method: request.method.to_s.upcase, base_url:,
        path: uri.path.delete_prefix(URI(base_url).path),
        query: URI.decode_www_form(uri.query || ''),
        body: request.body
      }
    end

    private_class_method :route, :stub_request
  end
end
