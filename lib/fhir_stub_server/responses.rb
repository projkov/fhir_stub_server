# frozen_string_literal: true

module FHIRStubServer
  # Builds the Rack-style [status, headers, body] responses the Stub returns.
  # @api private
  module Responses
    CONTENT_TYPE = 'application/fhir+json'

    def self.fhir(status, resource)
      raw(status, JSON.generate(resource))
    end

    def self.raw(status, body)
      [status, { 'content-type' => CONTENT_TYPE }, body]
    end

    # The JSON body of a searchset's `page` (see Paging), nil past the last one. `total` counts the
    # matches of all pages; every page but the last links the `next`.
    def self.searchset(request, pages, page)
      number = page[:number]
      (matches, includes), following = pages[:entries].values_at(number - 1, number)
      return unless matches

      base_url = request[:base_url]
      JSON.generate({
                      'resourceType' => 'Bundle', 'type' => 'searchset', 'total' => pages[:total],
                      'link' => links(request, ("#{base_url}#{page[:path]}/#{number + 1}" if following)),
                      'entry' => entries(base_url, matches, 'match') + entries(base_url, includes, 'include')
                    })
    end

    def self.links(request, next_url)
      query = URI.encode_www_form(request[:query])
      self_url = ["#{request[:base_url]}#{request[:path]}", query].reject(&:empty?).join('?')
      [{ 'relation' => 'self', 'url' => self_url }, ({ 'relation' => 'next', 'url' => next_url } if next_url)].compact
    end

    def self.entries(base_url, resources, mode)
      resources.map do |resource|
        { 'fullUrl' => "#{base_url}/#{resource['resourceType']}/#{resource['id']}",
          'resource' => resource, 'search' => { 'mode' => mode } }
      end
    end

    # What Inferno's validator client reads: the issues of the first outcome.
    def self.validation(issues)
      [200, { 'content-type' => 'application/json' },
       JSON.generate({ 'sessionId' => 'stub', 'outcomes' => [{ 'issues' => issues }] })]
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
