# frozen_string_literal: true

require_relative "fhir_stub_server/version"

# A strict stub for the FHIR server and validator used by FHIR test kits.
module FHIRStubServer
  class Error < StandardError; end
end
