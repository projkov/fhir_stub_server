# frozen_string_literal: true

# Scenario replay with Rack tooling: STUB_SERVER_CONFIG=<config.yml> bundle exec rackup
require_relative 'lib/fhir_stub_server'

run FHIRStubServer::Replay.new(FHIRStubServer.load(ENV.fetch('STUB_SERVER_CONFIG')))
