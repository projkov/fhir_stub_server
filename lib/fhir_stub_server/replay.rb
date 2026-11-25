# frozen_string_literal: true

module FHIRStubServer
  # Scenario replay: one Scenario's Stub served on its own, to point Inferno's UI at. A RackApp
  # that logs the load-time skips and empty selects at start and each unmatched request as it
  # arrives; drift fails nothing. Used by `fhir-stub-server`, which also calls #log_unused_pairs on
  # shutdown, and `config.ru`.
  class Replay
    def initialize(stub, log = $stderr)
      @stub = stub
      @rack_app = RackApp.new(stub)
      @log = log
      @lock = Mutex.new # Puma serves requests on several threads; each miss is logged once
      stub.served.select { |entry| entry[:kind] == :load }
          .each { |entry| log.puts "Skipped #{entry[:skipped]}: #{entry[:reason]}" }
      stub.empty_selects.each { |entry| log.puts format('Empty %<pair>s: %<expression>s', entry) }
    end

    def call(env)
      @lock.synchronize { logging_misses { @rack_app.call(env) } }
    end

    # Once no request can arrive.
    def log_unused_pairs
      report = @stub.unused_pairs_report
      @log.puts report unless report.empty?
    end

    private

    def logging_misses
      unmatched = @stub.unmatched
      logged = unmatched.size
      yield.tap { unmatched.drop(logged).each { |miss| @log.puts Unmatched.describe(miss) } }
    end
  end
end
