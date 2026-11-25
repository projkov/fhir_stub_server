# frozen_string_literal: true

RSpec.describe FHIRStubServer::Replay do
  it 'logs only the load-time entries of a Stub that has already answered requests' do
    stub = FHIRStubServer.load(fixture('scenario.yml'))
    request = { role: :fhir, method: 'GET', base_url: 'http://stub.test/fhir', path: '/Patient/p2', query: '', body: nil }
    stub.respond(FHIRStubServer::Request.build(request))
    log = StringIO.new

    described_class.new(stub, log)

    expect(log.string).to eq("Empty fhir.pairs[2]: entry.resource.ofType(Encounter)\n")
  end
end
