# frozen_string_literal: true

FHIRStubServer.require_gem('puma', 'FHIRStubServer::HTTPServer')

module FHIRStubServer
  # Serves a Stub (through a RackApp) or any Rack app, such as a Replay, over HTTP with Puma on a
  # random free port of 127.0.0.1, in a background thread: for `inferno execute` runs and
  # Scenario replay.
  class HTTPServer
    def initialize(stub_or_app, **rack_app_options)
      app = case stub_or_app
            when Stub then RackApp.new(stub_or_app, **rack_app_options)
            else stub_or_app
            end
      @server = Puma::Server.new(app)
      @thread = nil # set by #start
    end

    # Returns the server's base URL; a RackApp puts the FHIR and validator roles under their base paths.
    def start
      @server.add_tcp_listener('127.0.0.1', 0)
      @thread = @server.run
      "http://127.0.0.1:#{@server.connected_ports.first}"
    end

    # Blocks until #stop, which may be called from a signal trap.
    def wait
      @thread&.join
    end

    def stop
      @server.stop(true)
    end
  end
end
