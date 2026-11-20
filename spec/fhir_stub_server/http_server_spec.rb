# frozen_string_literal: true

RSpec.describe FHIRStubServer::HTTPServer do
  let(:servers) { [] }

  after { servers.each(&:stop) }

  def serve(stub)
    server = described_class.new(stub)
    servers << server
    base_url = server.start
    { fhir: "#{base_url}/fhir", validator: "#{base_url}/validator" }
  end

  it_behaves_like 'a Stub transport'
end
