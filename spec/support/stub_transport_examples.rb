# frozen_string_literal: true

# The main seam: every adapter must give the same responses and reports for the same config
# and requests. Including groups define `serve(stub)`, which starts the adapter and returns
# the FHIR base URL.
RSpec.shared_examples 'a Stub transport' do
  let(:sources) { [{ 'bundle' => fixture('demo.json') }] }
  let(:stub) { FHIRStubServer::Stub.new('fhir' => { 'sources' => sources }) }
  let(:base_url) { serve(stub) }

  def get(path)
    Net::HTTP.get_response(URI("#{base_url}#{path}"))
  end

  it 'answers a read from Demo Data' do
    response = get('/Patient/p1')

    expect([response.code, response['Content-Type']]).to eq(['200', 'application/fhir+json'])
    expect(JSON.parse(response.body)).to include('resourceType' => 'Patient', 'id' => 'p1')
    expect(stub.served).to match([{ kind: :request, answered_by: :demo_data,
                                    request: include(method: 'GET', path: '/Patient/p1') }])
    expect(stub.unmatched).to be_empty
  end

  context 'with an overrides Bundle after the first Source' do
    let(:sources) { [{ 'bundle' => fixture('demo.json') }, { 'bundle' => fixture('overrides.json') }] }

    it 'serves the resource from the later Source' do
      expect(JSON.parse(get('/Patient/p2').body)).to include('gender' => 'male')
    end
  end

  it 'answers an undeclared request with an OperationOutcome 404 and reports it' do
    response = get('/Patient?family=Smith')

    expect(response.code).to eq('404')
    expect(JSON.parse(response.body)).to include('resourceType' => 'OperationOutcome')
    expect(stub.unmatched).to match([{ request: include(path: '/Patient', query: [%w[family Smith]]) }])
    expect(stub.served).to match([include(answered_by: :miss)])
  end
end
