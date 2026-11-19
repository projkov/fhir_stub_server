# frozen_string_literal: true

RSpec.describe FHIRStubServer::Stub, '.new' do
  it 'raises on a missing Source file' do
    config = { 'fhir' => { 'sources' => [{ 'bundle' => '/missing/demo.json' }] } }

    expect { described_class.new(config) }.to raise_error(FHIRStubServer::Error, %r{/missing/demo\.json})
  end
end
