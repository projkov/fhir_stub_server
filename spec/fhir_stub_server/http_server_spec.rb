# frozen_string_literal: true

RSpec.describe FHIRStubServer::HTTPServer do
  let(:servers) { [] }

  after { servers.each(&:stop) }

  def serve(stub)
    server = described_class.new(stub)
    servers << server
    "#{server.start}/fhir"
  end

  it_behaves_like 'a Stub transport'
end
