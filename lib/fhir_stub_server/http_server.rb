# frozen_string_literal: true

FHIRStubServer.require_gem('puma', 'FHIRStubServer::HTTPServer')

module FHIRStubServer
  # Serves a Stub over HTTP with Puma on a random free port of 127.0.0.1, in a background
  # thread: for `inferno execute` runs and Scenario replay.
  class HTTPServer
    def initialize(stub, **rack_app_options)
      @server = Puma::Server.new(RackApp.new(stub, **rack_app_options))
    end

    # Returns the server's base URL; the FHIR and validator roles sit under their base paths.
    def start
      @server.add_tcp_listener('127.0.0.1', 0)
      @server.run
      "http://127.0.0.1:#{@server.connected_ports.first}"
    end

    def stop
      @server.stop(true)
    end
  end
end
