# frozen_string_literal: true

require 'json'
require 'uri'
require_relative 'fhir_stub_server/version'

# A strict stub for the FHIR server and validator used by FHIR test kits.
module FHIRStubServer
  # Base class for every error the gem raises, including config errors at build time.
  class Error < StandardError; end

  # Loaded on first use, so the core does not require webmock.
  autoload :WebMockAdapter, 'fhir_stub_server/webmock_adapter'
end

require_relative 'fhir_stub_server/responses'
require_relative 'fhir_stub_server/sources'
require_relative 'fhir_stub_server/stub'
