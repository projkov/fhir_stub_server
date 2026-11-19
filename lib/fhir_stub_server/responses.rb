# frozen_string_literal: true

module FHIRStubServer
  # Builds the Rack-style [status, headers, body] responses the Stub returns.
  module Responses
    CONTENT_TYPE = 'application/fhir+json'

    def self.fhir(status, resource)
      [status, { 'Content-Type' => CONTENT_TYPE }, JSON.generate(resource)]
    end

    def self.not_found(request)
      fhir(404, {
             'resourceType' => 'OperationOutcome',
             'issue' => [{ 'severity' => 'error', 'code' => 'not-found',
                           'diagnostics' => "No Pair or Demo Data for #{request[:method]} #{request[:path]}" }]
           })
    end
  end
end
