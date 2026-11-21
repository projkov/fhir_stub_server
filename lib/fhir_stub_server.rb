# frozen_string_literal: true

require 'fhirpath'
require 'json'
require 'pathname'
require 'rubygems/package'
require 'stringio'
require 'uri'
require 'yaml'
require 'zlib'
require_relative 'fhir_stub_server/version'

# A strict stub for the FHIR server and validator used by FHIR test kits.
module FHIRStubServer
  # Base class for every error the gem raises, including config errors at build time.
  class Error < StandardError; end

  # Builds a Stub from a YAML config file, or from the `server:` block of a kit's scenario.yml.
  # Source paths and `body_file`s are relative to the file.
  def self.load(path)
    document = parse_file(path, :yaml)
    config = document.is_a?(Hash) ? document.fetch('server', document) : document
    raise Error, "#{path}: the config must be a mapping" unless config.is_a?(Hash)

    Stub.new(config, dir: File.dirname(path))
  end

  # For the adapters' optional dependencies, which the consuming kit's Gemfile supplies.
  def self.require_gem(name, needed_by)
    require name
  rescue LoadError => error
    raise Error, "#{needed_by} needs the #{name} gem: add it to your Gemfile (#{error.message})"
  end

  # Reads a file named in the config, so a missing one fails when the Stub is built.
  def self.read_file(path)
    File.read(path)
  rescue SystemCallError => error # missing, a directory, unreadable
    raise Error, "Cannot read #{path}: #{error.message}"
  end

  # Reads a JSON or YAML file named in the config: invalid content fails when the Stub is built.
  def self.parse_file(path, format)
    text = read_file(path)
    format == :yaml ? YAML.safe_load(text, aliases: true) : JSON.parse(text)
  rescue JSON::ParserError, Psych::Exception => error
    raise Error, "#{path}: not valid #{format.upcase} (#{error.message})"
  end

  # Loaded on first use, so the core requires neither webmock nor puma.
  autoload :WebMockAdapter, 'fhir_stub_server/webmock_adapter'
  autoload :HTTPServer, 'fhir_stub_server/http_server'
end

require_relative 'fhir_stub_server/fhir_role'
require_relative 'fhir_stub_server/includes'
require_relative 'fhir_stub_server/pairs'
require_relative 'fhir_stub_server/rack_app'
require_relative 'fhir_stub_server/replay'
require_relative 'fhir_stub_server/request'
require_relative 'fhir_stub_server/responses'
require_relative 'fhir_stub_server/sources'
require_relative 'fhir_stub_server/stub'
require_relative 'fhir_stub_server/unmatched'
require_relative 'fhir_stub_server/validator'
