# frozen_string_literal: true

module FHIRStubServer
  # Builds the Rack-style [status, headers, body] responses the Stub returns.
  module Responses
    CONTENT_TYPE = 'application/fhir+json'

    def self.fhir(status, resource)
      raw(status, JSON.generate(resource))
    end

    def self.raw(status, body)
      [status, { 'content-type' => CONTENT_TYPE }, body]
    end

    # The JSON body of a searchset: `matches` (total counts only these), then `includes`. No paging.
    def self.searchset(request, matches, includes)
      base_url = request[:base_url]
      self_url = ["#{base_url}#{request[:path]}", URI.encode_www_form(request[:query])].reject(&:empty?).join('?')
      JSON.generate({
                      'resourceType' => 'Bundle', 'type' => 'searchset', 'total' => matches.size,
                      'link' => [{ 'relation' => 'self', 'url' => self_url }],
                      'entry' => entries(base_url, matches, 'match') + entries(base_url, includes, 'include')
                    })
    end

    def self.entries(base_url, resources, mode)
      resources.map do |resource|
        { 'fullUrl' => "#{base_url}/#{resource['resourceType']}/#{resource['id']}",
          'resource' => resource, 'search' => { 'mode' => mode } }
      end
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
