# frozen_string_literal: true

module FHIRStubServer
  # Loads the optional `validator:` block, which answers Inferno's validator calls:
  #
  #   pairs: [{ profile: au-core-patient, resource: Patient/p1, issues: [...] }]
  #   expected_context: { sv: 4.0.1 }
  #
  # A call is matched on the profile (`filesToValidate[0].fileName` without `.json`) and the
  # `Type/id` of the file's content; `sessionId` is ignored.
  module Validator
    def self.load(config)
      { pairs: config['pairs'].to_a.map { |pair| [pair.values_at('profile', 'resource'), pair['issues'].to_a] },
        expected_context: config['expected_context'].to_h }
    end

    # The index of the Pair answering the request (nil: a miss) and the request's
    # #context_mismatches entries.
    def self.match(validator, request)
      call = call(request)
      return [nil, []] unless call

      key, context = call
      [validator[:pairs].index { |pair| pair.first == key }, mismatches(validator[:expected_context], context, request)]
    end

    # [[profile, Type/id], context] of a `POST /validate`; nil for any other request.
    def self.call(request)
      return unless request[:method] == 'POST' && request[:path] == '/validate'

      body = JSON.parse(request[:body].to_s)
      [key(body.dig('filesToValidate', 0)), body['cliContext'] || body['validationContext'] || {}]
    rescue JSON::ParserError, TypeError, NoMethodError # not shaped like an Inferno validate call
      nil
    end

    def self.key(file)
      resource = JSON.parse(file['fileContent'])
      [file['fileName'].delete_suffix('.json'), "#{resource['resourceType']}/#{resource['id']}"]
    end

    # Only the listed keys count, each compared exactly.
    def self.mismatches(expected_context, context, request)
      expected_context.filter_map do |key, expected|
        actual = context[key]
        { request:, key:, expected:, actual: } unless actual == expected
      end
    end

    private_class_method :call, :key, :mismatches
  end
end
