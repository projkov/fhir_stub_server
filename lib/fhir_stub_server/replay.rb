# frozen_string_literal: true

module FHIRStubServer
  # Scenario replay: one Scenario's Stub served on its own, to point Inferno's UI at. A RackApp
  # that logs the load-time skips at start and each unmatched request as it arrives; drift fails
  # nothing. Used by `fhir-stub-server` and `config.ru`.
  class Replay
    def initialize(stub, log = $stderr)
      @rack_app = RackApp.new(stub)
      @unmatched = stub.unmatched
      @log = log
      @lock = Mutex.new # Puma serves requests on several threads; each miss is logged once
      stub.served.each { |entry| log.puts "Skipped #{entry[:skipped]}: #{entry[:reason]}" }
    end

    def call(env)
      @lock.synchronize { logging_misses { @rack_app.call(env) } }
    end

    private

    def logging_misses
      logged = @unmatched.size
      response = yield
      @unmatched.drop(logged).each { |miss| @log.puts Unmatched.describe(miss) }
      response
    end
  end
end
