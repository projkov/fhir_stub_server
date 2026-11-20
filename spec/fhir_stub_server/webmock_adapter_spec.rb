# frozen_string_literal: true

RSpec.describe FHIRStubServer::WebMockAdapter do
  def serve(stub)
    urls = { fhir: 'http://fhir.stub.test/fhir', validator: 'http://validator.stub.test/api' }
    described_class.install(stub, fhir_base_url: urls[:fhir], validator_base_url: urls[:validator])
    urls
  end

  it_behaves_like 'a Stub transport'
end
