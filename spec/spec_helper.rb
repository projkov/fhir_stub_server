# frozen_string_literal: true

require 'net/http'
# Puma adapts to the loaded Rack (e.g. env['HTTP_VERSION'] below Rack 3.1), so load the bundled one as a host app would.
require 'rack'
require 'webmock/rspec'
require 'fhir_stub_server'

# HTTPServer specs talk to Puma on 127.0.0.1.
WebMock.disable_net_connect!(allow_localhost: true)

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
