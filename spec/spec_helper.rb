# frozen_string_literal: true

require 'net/http'
require 'webmock/rspec'
require 'fhir_stub_server'

Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with(:rspec) { |c| c.syntax = :expect }
end
