# frozen_string_literal: true

require_relative 'lib/fhir_stub_server/version'

Gem::Specification.new do |spec|
  spec.name = 'fhir_stub_server'
  spec.version = FHIRStubServer::VERSION
  spec.authors = ['Pavel Rozhkov']
  spec.email = ['pavel.r@beda.software', 'prozskov@gmail.com']

  spec.summary = 'A strict stub for the FHIR server and validator used by FHIR test kits.'
  spec.description = 'Answers only the requests a Scenario declares, serves Demo Data from FHIR ' \
                     "packages and Bundles, selects responses with FHIRPath, stubs Inferno's validator " \
                     'and reports every unmatched request. Runs in process through WebMock or over HTTP.'
  spec.homepage = 'https://github.com/projkov/fhir_stub_server'
  spec.license = 'Apache-2.0'
  spec.required_ruby_version = '>= 3.3.6'
  spec.metadata = { 'homepage_uri' => spec.homepage, 'source_code_uri' => spec.homepage,
                    'documentation_uri' => 'https://rubydoc.info/gems/fhir_stub_server',
                    'rubygems_mfa_required' => 'true' }

  ignored = %W[#{File.basename(__FILE__)} bin/ spec/ docs/ sig/external/ .github/ gemfiles/ Gemfile .gitignore
               .rspec .kata.toml AGENTS.md]
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject { |f| f.start_with?(*ignored) }
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'fhirpath-rb', '~> 0.1'
end
