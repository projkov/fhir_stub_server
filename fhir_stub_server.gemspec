# frozen_string_literal: true

require_relative "lib/fhir_stub_server/version"

Gem::Specification.new do |spec|
  spec.name = "fhir_stub_server"
  spec.version = FHIRStubServer::VERSION
  spec.authors = ["Pavel Rozhkov"]
  spec.email = ["pavel.r@beda.software", "prozskov@gmail.com"]

  spec.summary = "A strict stub for the FHIR server and validator used by FHIR test kits."
  spec.description = "Answers only the requests a Scenario declares, serves Demo Data from FHIR " \
                     "packages and Bundles, selects responses with FHIRPath, stubs Inferno's validator " \
                     "and reports every unmatched request. Runs in process through WebMock or over HTTP."
  spec.homepage = "https://github.com/beda-software/fhir_stub_server"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.3.6"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ spec/ docs/ Gemfile .gitignore .rspec .kata.toml AGENTS.md])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "fhirpath-rb", "~> 0.1"
end
