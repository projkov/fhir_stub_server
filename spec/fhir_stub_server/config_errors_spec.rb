# frozen_string_literal: true

RSpec.describe FHIRStubServer::Stub, '.new' do
  pair = lambda do |response, request = { 'path' => '/metadata' }|
    { 'fhir' => { 'pairs' => [{ 'request' => request, 'response' => response }] } }
  end

  {
    'a missing Source file' => [
      { 'fhir' => { 'sources' => [{ 'bundle' => '/missing/demo.json' }] } }, %r{/missing/demo\.json}
    ],
    'a Pair response without a body kind' => [
      pair.call({ 'status' => 200 }), /fhir\.pairs\[0\]: the response needs exactly one of/
    ],
    'a Pair response with two body kinds' => [
      pair.call({ 'body_file' => 'x.json', 'select' => 'Bundle.entry' }),
      /fhir\.pairs\[0\]: the response needs exactly one of/
    ],
    'a Pair request without a path' => [
      pair.call({ 'body_file' => 'x.json' }, {}), %r{fhir\.pairs\[0\]: the request needs a path starting with /}
    ],
    'a missing body_file' => [
      pair.call({ 'body_file' => '/missing/body.json' }), %r{/missing/body\.json}
    ]
  }.each do |name, (config, message)|
    it "raises on #{name}" do
      expect { described_class.new(config) }.to raise_error(FHIRStubServer::Error, message)
    end
  end
end
