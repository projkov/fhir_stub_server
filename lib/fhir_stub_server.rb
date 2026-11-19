# frozen_string_literal: true

require 'json'
require 'uri'
require_relative 'fhir_stub_server/version'

# A strict stub for the FHIR server and validator used by FHIR test kits.
module FHIRStubServer
  # Base class for every error the gem raises, including config errors at build time.
  class Error < StandardError; end

  # For the adapters' optional dependencies, which the consuming kit's Gemfile supplies.
  def self.require_gem(name, needed_by)
    require name
  rescue LoadError => error
    raise Error, "#{needed_by} needs the #{name} gem: add it to your Gemfile (#{error.message})"
  end

  # Reads a file named in the config, so a missing one fails when the Stub is built.
  def self.read_file(path)
    File.read(path)
  rescue Errno::ENOENT
    raise Error, "File not found: #{path}"
  end

  # Loaded on first use, so the core requires neither webmock nor puma.
  autoload :WebMockAdapter, 'fhir_stub_server/webmock_adapter'
  autoload :HTTPServer, 'fhir_stub_server/http_server'
end

require_relative 'fhir_stub_server/pairs'
require_relative 'fhir_stub_server/rack_app'
require_relative 'fhir_stub_server/responses'
require_relative 'fhir_stub_server/sources'
require_relative 'fhir_stub_server/stub'
