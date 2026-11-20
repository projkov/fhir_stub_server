# frozen_string_literal: true

# The main seam: every adapter must give the same responses and reports for the same config
# and requests. Including groups define `serve(stub)`, which starts the adapter and returns
# the FHIR base URL.
RSpec.shared_examples 'a Stub transport' do
  let(:sources) { [{ 'bundle' => fixture('demo.json') }] }
  let(:pairs) { [] }
  let(:stub) { FHIRStubServer::Stub.new('fhir' => { 'sources' => sources, 'pairs' => pairs }) }
  let(:base_url) { serve(stub) }

  def get(path)
    Net::HTTP.get_response(URI("#{base_url}#{path}"))
  end

  def post_form(path, form)
    Net::HTTP.post(URI("#{base_url}#{path}"), form, 'Content-Type' => 'application/x-www-form-urlencoded')
  end

  it 'answers a read from Demo Data' do
    response = get('/Patient/p1')

    expect([response.code, response['Content-Type']]).to eq(['200', 'application/fhir+json'])
    expect(JSON.parse(response.body)).to include('resourceType' => 'Patient', 'id' => 'p1')
    expect(stub.served).to match([{ kind: :request, answered_by: :demo_data,
                                    request: include(method: 'GET', path: '/Patient/p1') }])
    expect(stub.unmatched).to be_empty
  end

  it 'answers /metadata with the server CapabilityStatement' do
    expect(JSON.parse(get('/metadata').body)).to include('resourceType' => 'CapabilityStatement', 'id' => 'responder')
  end

  context 'with an IG package and an overrides Bundle after it' do
    let(:sources) { [{ 'package' => ig_package }, { 'bundle' => fixture('overrides.json') }] }

    it 'serves package resources as they are, the later Source winning' do
      expect(JSON.parse(get('/Patient/p2').body)).to include('gender' => 'male')
      expect(get('/StructureDefinition/example-patient').code).to eq('200')
      expect(JSON.parse(get('/metadata').body)).to include('id' => 'responder')
      expect([get('/Bundle/b1').code, get('/Patient/inside').code]).to eq(%w[200 404])
    end

    it 'reports a resource without an id as skipped at load time' do
      expect(stub.served.first).to match(kind: :load, reason: 'resource without id',
                                         skipped: end_with('(package/example/Patient-no-id.json)'))
    end
  end

  context 'with an overrides Bundle after the first Source' do
    let(:sources) { [{ 'bundle' => fixture('demo.json') }, { 'bundle' => fixture('overrides.json') }] }

    it 'serves the resource from the later Source' do
      expect(JSON.parse(get('/Patient/p2').body)).to include('gender' => 'male')
    end
  end

  it 'answers an undeclared request with an OperationOutcome 404 and reports it' do
    response = get('/Observation?date=le2021&code=8867-4&date=ge2020')

    expect(response.code).to eq('404')
    expect(JSON.parse(response.body)).to include('resourceType' => 'OperationOutcome')
    query = { 'code' => ['8867-4'], 'date' => %w[ge2020 le2021] }
    expect(stub.unmatched).to match([{ request: include(path: '/Observation', query:),
                                       nearest_pair: nil, differences: {} }])
    expect(stub.served).to match([include(answered_by: :miss)])
  end

  context 'with Pairs on the path of a request that matches none of them' do
    let(:pairs) do
      [{ 'patient' => 'p1' }, { 'patient' => 'p1', 'code' => '8867-4' }].map do |query|
        { 'request' => { 'path' => '/Observation', 'query' => query },
          'response' => { 'body_file' => fixture('smith_searchset.json') } }
      end
    end

    it 'reports the Pair with the fewest differences and those differences' do
      get('/Observation?code=8867-4&patient=p2&_count=10')

      differences = { '_count' => { expected: nil, actual: ['10'] },
                      'patient' => { expected: ['p1'], actual: ['p2'] } }
      expect(stub.unmatched).to match([{ request: include(path: '/Observation'), nearest_pair: 1, differences: }])
    end
  end

  context 'with a Pair for a request Demo Data could answer' do
    let(:pairs) do
      [{ 'request' => { 'path' => '/Patient/p1' },
         'response' => { 'status' => 404, 'body_file' => fixture('patient_gone.json') } }]
    end

    it 'answers with the Pair' do
      response = get('/Patient/p1')

      expect(response.code).to eq('404')
      expect(response.body).to eq(File.read(fixture('patient_gone.json')))
      expect(stub.served).to match([include(answered_by: 0)])
    end
  end

  context 'with a Pair for a POST search' do
    let(:pairs) do
      [{ 'request' => { 'method' => 'POST', 'path' => '/Patient/_search',
                        'body' => { 'family' => 'Smith', 'given' => %w[John Jo] } },
         'response' => { 'body_file' => fixture('smith_searchset.json') } }]
    end

    it 'matches the form body in any order' do
      response = post_form('/Patient/_search', 'given=Jo&family=Smith&given=John')

      expect(response.code).to eq('200')
      expect(JSON.parse(response.body)).to include('type' => 'searchset', 'total' => 1)
      expect(stub.unmatched).to be_empty
    end

    it 'does not match a different form body, raw UTF-8 included' do
      expect(post_form('/Patient/_search', 'family=Müller&given=John&given=Jo').code).to eq('404')
      expect(stub.unmatched).to match([{ request: include(body: 'family=Müller&given=John&given=Jo'), nearest_pair: 0,
                                         differences: { 'family' => { expected: ['Smith'], actual: ['Müller'] } } }])
    end
  end

  context 'with a select Pair' do
    let(:pairs) do
      [{ 'request' => { 'path' => '/MedicationRequest',
                        'query' => { 'patient' => 'Patient/p1', '_include' => 'MedicationRequest:medication' } },
         'response' => {
           'select' => "Bundle.entry.resource.ofType(MedicationRequest).where(subject.reference = 'Patient/p1')",
           'include' => 'Bundle.entry.resource.ofType(Medication)'
         } }]
    end

    it 'answers a searchset of matches and includes under the base URL' do
      bundle = JSON.parse(get('/MedicationRequest?patient=Patient/p1&_include=MedicationRequest:medication').body)

      expect(bundle).to include('type' => 'searchset', 'total' => 1)
      expect(bundle['link']).to match([{ 'relation' => 'self', 'url' => start_with("#{base_url}/MedicationRequest?") }])
      expect(bundle['entry'].map { |entry| [entry['fullUrl'], entry.dig('search', 'mode')] })
        .to eq([["#{base_url}/MedicationRequest/mr1", 'match'], ["#{base_url}/Medication/m1", 'include']])
    end
  end

  context 'with a resource Pair for /metadata' do
    let(:pairs) do
      [{ 'request' => { 'path' => '/metadata' },
         'response' => { 'resource' => "entry.resource.ofType(CapabilityStatement).where(id = 'requester')" } }]
    end

    it 'answers with the one resource the expression yields, over the built-in /metadata' do
      expect(JSON.parse(get('/metadata').body)).to include('resourceType' => 'CapabilityStatement', 'id' => 'requester')
    end
  end
end
