# frozen_string_literal: true

RSpec.describe FHIRStubServer::WebMockAdapter do
  def serve(stub)
    urls = { fhir: 'http://fhir.stub.test/fhir', validator: 'http://validator.stub.test/api' }
    described_class.install(stub, fhir_base_url: urls[:fhir], validator_base_url: urls[:validator])
    urls
  end

  it_behaves_like 'a Stub transport'

  it 'leaves hash_including query stubs matching after uninstall' do
    serve(FHIRStubServer::Stub.new({ 'fhir' => { 'sources' => [], 'pairs' => [] } }, dir: fixture('.')))
    described_class.uninstall
    WebMock.stub_request(:get, 'http://other.test/x').with(query: hash_including('a' => '1'))

    expect(Net::HTTP.get_response(URI('http://other.test/x?a=1&b=2')).code).to eq('200')
  end
end
