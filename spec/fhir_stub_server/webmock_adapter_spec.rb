# frozen_string_literal: true

RSpec.describe FHIRStubServer::WebMockAdapter do
  def serve(stub)
    described_class.install(stub, fhir_base_url: 'http://fhir.stub.test/fhir')
    'http://fhir.stub.test/fhir'
  end

  it_behaves_like 'a Stub transport'
end
