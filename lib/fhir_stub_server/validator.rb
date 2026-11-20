# frozen_string_literal: true

module FHIRStubServer
  # Answers Inferno's validator calls from the `validator:` block, the way Stub expects of a role:
  #
  #   pairs: [{ profile: au-core-patient, resource: Patient/p1, issues: [...] }]
  #   expected_context: { sv: 4.0.1 }
  #
  # A call is matched on the profile (`filesToValidate[0].fileName` without `.json`) and the
  # `Type/id` of the file's content; `sessionId` is ignored.
  # @api private
  class Validator
    def initialize(config)
      @pairs = config['pairs'].to_a.map { |pair| [pair.values_at('profile', 'resource'), pair['issues'].to_a] }
      @expected_context = config['expected_context'].to_h
    end

    # A context mismatch is reported, but a matching Pair still answers.
    def answer(request)
      key, context = Validator.call(request)
      reports = { context_mismatches: mismatches(context, request) }
      index = pair_index(key)
      return [index, Responses.validation(@pairs.fetch(index).last), reports] if index

      [:miss, Responses.not_found(request), { **reports, unmatched: [Validator.miss(request, key)] }]
    end

    # No near miss: validator Pairs have no parameters to compare. The suggestion is the Pair
    # without its `issues`; nil when the request is no validate call.
    def self.miss(request, key)
      { request:, nearest_pair: nil, differences: {}, suggested_request: key && %w[profile resource].zip(key).to_h }
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

    private_class_method :key

    private

    def pair_index(key) = @pairs.index { |pair| pair.first == key }

    # Only the listed keys count, each compared exactly; a request that is no validate call has none.
    def mismatches(context, request)
      return [] unless context

      @expected_context.filter_map do |key, expected|
        actual = context[key]
        { request:, key:, expected:, actual: } unless actual == expected
      end
    end
  end
end
