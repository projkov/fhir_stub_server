# frozen_string_literal: true

module FHIRStubServer
  # Answers FHIR requests from `fhir.pairs` and Demo Data, the way Stub expects of a role:
  # [answered_by, response, { report name => entries }].
  class FHIRRole
    def initialize(config, demo_data)
      @pairs = Pairs.load(config['pairs'].to_a, demo_data)
      @reads = Sources.reads(demo_data)
    end

    # A Pair first, so it can override a read; then a built-in read; then a miss, reported with
    # the Pair it most likely meant.
    def answer(request)
      found = Pairs.answer(@pairs, request) || read_answer(request)
      return [found[0], found[1], {}] if found

      [:miss, Responses.not_found(request), { unmatched: [{ request:, **Pairs.near_miss(@pairs, request) }] }]
    end

    # The path of a GET without query parameters, which a built-in read may answer; nil for
    # anything else, so a read that gains a parameter is a miss unless a Pair declares it.
    def self.read_path(request)
      request[:path] if request[:method] == 'GET' && request[:query].empty?
    end

    private

    def read_answer(request)
      resource = @reads[FHIRRole.read_path(request)]
      [:demo_data, Responses.fhir(200, resource)] if resource
    end
  end
end
