# frozen_string_literal: true

module FHIRStubServer
  # Answers requests from Demo Data and records what answered each one.
  # Adapters build the request Hash and send the [status, headers, body] response back.
  class Stub
    READ_PATH = %r{\A/(?<type>[A-Z][A-Za-z]+)/(?<id>[A-Za-z0-9\-.]{1,64})\z}

    attr_reader :served, :unmatched

    def initialize(config)
      @demo_data = Sources.load(config.dig('fhir', 'sources') || [])
      @served = []
      @unmatched = []
    end

    def respond(request)
      resource = @demo_data[Stub.read_key(request)]
      return serve(request, :demo_data, Responses.fhir(200, resource)) if resource

      @unmatched << { request: }
      serve(request, :miss, Responses.not_found(request))
    end

    # The Demo Data key for a plain `GET /<Type>/<id>` FHIR read, nil for anything else.
    def self.read_key(request)
      match = READ_PATH.match(request[:path])
      "#{match[:type]}/#{match[:id]}" if match && request[:role] == :fhir && request[:method] == 'GET'
    end

    private

    def serve(request, answered_by, response)
      @served << { kind: :request, request:, answered_by: }
      response
    end
  end
end
