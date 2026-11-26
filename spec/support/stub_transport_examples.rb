# frozen_string_literal: true

# The main seam: every adapter must give the same responses and reports for the same config
# and requests. Including groups define `serve(stub)`, which starts the adapter and returns
# the base URLs as { fhir:, validator: }. Config paths are relative to spec/fixtures.
RSpec.shared_examples 'a Stub transport' do
  let(:sources) { [{ 'bundle' => fixture('demo.json') }] }
  let(:pairs) { [] }
  let(:validator) { nil }
  let(:stub) do
    FHIRStubServer::Stub.new({ 'fhir' => { 'sources' => sources, 'pairs' => pairs }, 'validator' => validator }.compact,
                             dir: fixture('.'))
  end
  let(:base_urls) { serve(stub) }
  let(:base_url) { base_urls[:fhir] }

  def get(path)
    Net::HTTP.get_response(URI("#{base_url}#{path}"))
  end

  def post_form(path, form)
    Net::HTTP.post(URI("#{base_url}#{path}"), form, 'Content-Type' => 'application/x-www-form-urlencoded')
  end

  def send_request(method, path, body = nil)
    uri = URI("#{base_url}#{path}")
    Net::HTTP.start(uri.host, uri.port) do |http|
      http.send_request(method, uri.request_uri, body, 'Content-Type' => 'application/fhir+json')
    end
  end

  # What Inferno's validator client sends: the file is named after the profile's last segment.
  def validate(profile, resource, context)
    file = { 'fileName' => "#{profile}.json", 'fileContent' => JSON.generate(resource), 'fileType' => 'json' }
    body = { **context, 'sessionId' => 'abc', 'filesToValidate' => [file] }
    Net::HTTP.post(URI("#{base_urls[:validator]}/validate"), JSON.generate(body), 'Content-Type' => 'application/json')
  end

  it 'answers a read from Demo Data' do
    response = get('/Patient/p1')

    expect([response.code, response['Content-Type']]).to eq(['200', 'application/fhir+json'])
    expect(JSON.parse(response.body)).to include('resourceType' => 'Patient', 'id' => 'p1')
    expect(stub.served).to match([{ kind: :request, answered_by: :demo_data,
                                    request: include(method: 'GET', path: '/Patient/p1') }])
    expect(stub.unmatched).to be_empty
  end

  it 'does not answer a read that carries a query parameter' do
    expect(get('/Patient/p1?x=1').code).to eq('404')
    expect(stub.unmatched).to match([include(request: include(path: '/Patient/p1', query: { 'x' => ['1'] }))])
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
    expect(stub.unmatched).to match([include(request: include(path: '/Observation', query:),
                                             nearest_pair: nil, differences: {})])
    expect(stub.served).to match([include(answered_by: :miss)])
  end

  context 'with Pairs on the path of a request that matches none of them' do
    let(:pairs) do
      [{ 'patient' => 'p1' }, { 'patient' => 'p1', 'code' => '8867-4' }].map do |query|
        { 'request' => { 'path' => '/Observation', 'query' => query },
          'response' => { 'body_file' => fixture('smith_searchset.json') } }
      end
    end

    it 'reports the Pair with the fewest differences and those differences, also as one line' do
      get('/Observation?code=8867-4&patient=p2&_count=10')

      differences = { '_count' => { expected: nil, actual: ['10'] },
                      'patient' => { expected: ['p1'], actual: ['p2'] } }
      expect(stub.unmatched).to match([include(request: include(path: '/Observation'), nearest_pair: 'fhir.pairs[1]',
                                               differences:)])
      expect(stub.unmatched_report).to eq(
        'Unmatched fhir GET /Observation?_count=10&code=8867-4&patient=p2; nearest fhir.pairs[1]: ' \
        '_count expected nil, got ["10"]; patient expected ["p1"], got ["p2"]; ' \
        'request: {"path":"/Observation","query":{"_count":"10","code":"8867-4","patient":"p2"}}'
      )
    end
  end

  context 'with Pairs from a shared file that includes another' do
    let(:pairs) { [{ 'from' => 'shared/pairs.yml' }] }

    it 'answers from them, their body_files relative to their file, and reports where they are written' do
      expect(get('/Patient/p1').body).to eq(File.read(fixture('patient_gone.json')))
      get('/Observation?patient=p2')

      expect(stub.served.map { |entry| entry[:answered_by] }).to eq(['fhir.pairs[0] (shared/pairs.yml[0])', :miss])
      expect(stub.unmatched).to match(
        [include(nearest_pair: 'fhir.pairs[0] (shared/pairs.yml[1] > shared/nested/observations.yml[0])')]
      )
    end
  end

  context 'with FHIR and validator Pairs from shared files' do
    let(:pairs) { [{ 'from' => 'shared/pairs.yml' }] }
    let(:validator) { { 'pairs' => [{ 'from' => 'shared/validator.yml' }] } }

    it 'reports the Pairs no request used, in config order, also as one line each' do
      get('/Patient/p1')

      observations = 'fhir.pairs[0] (shared/pairs.yml[1] > shared/nested/observations.yml[0])'
      expect(stub.unused_pairs).to eq(
        [{ role: :fhir, pair: observations, request: { 'path' => '/Observation', 'query' => { 'patient' => 'p1' } } },
         { role: :validator, pair: 'validator.pairs[0] (shared/validator.yml[0])',
           request: { 'profile' => 'example-patient', 'resource' => 'Patient/p1' } }]
      )
      expect(stub.unused_pairs_report).to eq(
        "Unused #{observations}: {\"path\":\"/Observation\",\"query\":{\"patient\":\"p1\"}}\n" \
        'Unused validator.pairs[0] (shared/validator.yml[0]): {"profile":"example-patient","resource":"Patient/p1"}'
      )
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
      expect(stub.served).to match([include(answered_by: 'fhir.pairs[0]')])
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

    it 'does not match a different form body, raw UTF-8 included, and suggests the Pair request' do
      expect(post_form('/Patient/_search', 'family=Müller&given=John&given=Jo').code).to eq('404')
      suggested_request = { 'method' => 'POST', 'path' => '/Patient/_search',
                            'body' => { 'family' => 'Müller', 'given' => %w[Jo John] } }
      expect(stub.unmatched).to match([{ request: include(body: 'family=Müller&given=John&given=Jo'),
                                         nearest_pair: 'fhir.pairs[0]',
                                         differences: { 'family' => { expected: ['Smith'], actual: ['Müller'] } },
                                         suggested_request: }])
    end
  end

  context 'with write Pairs' do
    let(:patient) { { 'resourceType' => 'Patient', 'id' => 'p1', 'active' => true } }
    let(:patch) do
      [{ 'op' => 'replace', 'path' => '/active', 'value' => false }, { 'op' => 'remove', 'path' => '/name' }]
    end
    let(:p1) { { 'resource' => "entry.resource.ofType(Patient).where(id = 'p1')" } }
    let(:pairs) do
      [{ 'request' => { 'method' => 'put', 'path' => '/Patient/p1', 'body' => patient }, 'response' => p1 },
       { 'request' => { 'method' => 'PATCH', 'path' => '/Patient/p1', 'body' => patch }, 'response' => p1 },
       { 'request' => { 'method' => 'POST', 'path' => '/Patient' }, 'response' => { 'status' => 201, **p1 } },
       { 'request' => { 'method' => 'DELETE', 'path' => '/Patient/p1' }, 'response' => { 'status' => 204 } }]
    end

    it 'matches a JSON body whatever its key order and whitespace' do
      body = "{ \"active\": true,\n  \"id\": \"p1\", \"resourceType\": \"Patient\" }"

      codes = [send_request('PUT', '/Patient/p1', body), send_request('PATCH', '/Patient/p1', JSON.generate(patch))]
              .map(&:code)

      expect(codes).to eq(%w[200 200])
      expect(stub.served.map { |entry| entry[:answered_by] }).to eq(['fhir.pairs[0]', 'fhir.pairs[1]'])
    end

    it 'matches any body when the Pair declares none' do
      expect(send_request('POST', '/Patient', 'not json').code).to eq('201')
    end

    it 'answers a 204 with an empty body' do
      response = send_request('DELETE', '/Patient/p1')

      expect([response.code, response.body.to_s]).to eq(['204', ''])
    end

    it 'misses on a different or unparseable body, reporting the body difference and suggesting the request' do
      codes = [send_request('PATCH', '/Patient/p1', JSON.generate(patch.reverse)),
               send_request('PUT', '/Patient/p1', '{"resourceType":')].map(&:code)

      expect(codes).to eq(%w[404 404])
      expect(stub.unmatched).to match(
        [include(nearest_pair: 'fhir.pairs[1]', differences: { 'body' => { expected: patch, actual: patch.reverse } },
                 suggested_request: { 'method' => 'PATCH', 'path' => '/Patient/p1', 'body' => patch.reverse }),
         include(nearest_pair: 'fhir.pairs[0]',
                 differences: { 'body' => { expected: patient, actual: '{"resourceType":' } },
                 suggested_request: { 'method' => 'PUT', 'path' => '/Patient/p1' })]
      )
      expect(stub.unused_pairs.first).to eq(role: :fhir, pair: 'fhir.pairs[0]',
                                            request: { 'method' => 'PUT', 'path' => '/Patient/p1', 'body' => patient })
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

  context 'with a select Pair with a page_size' do
    let(:pairs) do
      [{ 'request' => { 'path' => '/MedicationRequest' },
         'response' => { 'select' => 'entry.resource.ofType(MedicationRequest)',
                         'include' => 'entry.resource.ofType(Medication)', 'page_size' => 1 } }]
    end

    it 'answers page by page, a consumer following next to the end, and reports a page past it' do
      pages = [JSON.parse(get('/MedicationRequest').body)]
      while (url = pages.last['link'].find { |link| link['relation'] == 'next' }&.fetch('url'))
        pages << JSON.parse(Net::HTTP.get(URI(url)))
      end

      expect(pages.map { |page| page['entry'].map { |entry| entry['fullUrl'].delete_prefix(base_url) } })
        .to eq([%w[/MedicationRequest/mr1 /Medication/m1], %w[/MedicationRequest/mr2]])
      expect(pages.map { |page| page['total'] }).to eq([2, 2])
      expect(get('/_page/0/3').code).to eq('404')
      expect(stub.served.map { |entry| entry[:answered_by] }).to eq(['fhir.pairs[0]', 'fhir.pairs[0]', :miss])
      expect(stub.unmatched).to match([include(request: include(path: '/_page/0/3'))])
    end
  end

  context 'with a select on a choice element, over a package for R4 and R4B' do
    let(:sources) do
      [{ 'package' => build_package('r4_observation',
                                    'package/package.json' => { 'fhirVersions' => %w[4.0.1 4.3.0] },
                                    'package/Observation-o1.json' => {
                                      'resourceType' => 'Observation', 'id' => 'o1',
                                      'effectiveDateTime' => '2020-01-01'
                                    }) }]
    end
    let(:pairs) do
      [{ 'request' => { 'path' => '/Observation' },
         'response' => { 'select' => 'entry.resource.ofType(Observation).where(effective.exists())' } }]
    end

    it 'resolves the choice element with the FHIR model' do
      expect(JSON.parse(get('/Observation').body)).to include('total' => 1)
    end
  end

  context 'with select Pairs that match nothing' do
    let(:pairs) do
      [{ 'select' => 'entry.resource.ofType(Patient)', 'include' => 'entry.resource.ofType(Medicaton)' },
       { 'select' => "entry.resource.ofType(Patient).where(name.family = 'Smtih')" },
       { 'select' => "entry.resource.ofType(Patient).where(name.family = 'Nobody')", 'expect_empty' => true }]
        .map { |response| { 'request' => { 'path' => '/Patient' }, 'response' => response } }
    end

    it 'records each empty select and include, but not those of a Pair that expects them' do
      expect(stub.empty_selects).to eq(
        [{ role: :fhir, pair: 'fhir.pairs[0]', expression: 'entry.resource.ofType(Medicaton)' },
         { role: :fhir, pair: 'fhir.pairs[1]',
           expression: "entry.resource.ofType(Patient).where(name.family = 'Smtih')" }]
      )
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

  context 'with a validator block' do
    let(:issue) { { 'level' => 'ERROR', 'message' => 'Patient.name: minimum required = 1' } }
    let(:validator) do
      { 'pairs' => [{ 'profile' => 'example-patient', 'resource' => 'Patient/p1', 'issues' => [issue] }],
        'expected_context' => { 'sv' => '4.0.1', 'txServer' => 'n/a' } }
    end
    let(:patient) { { 'resourceType' => 'Patient', 'id' => 'p1' } }

    it 'answers a validate call with the canned issues and reports context mismatches' do
      response = validate('example-patient', patient,
                          'validationContext' => { 'sv' => '4.0.1', 'txServer' => 'http://tx.fhir.org', 'igs' => [] })

      expect(JSON.parse(response.body)).to eq('sessionId' => 'stub', 'outcomes' => [{ 'issues' => [issue] }])
      expect(stub.context_mismatches).to match([{ request: include(role: :validator), key: 'txServer',
                                                  expected: 'n/a', actual: 'http://tx.fhir.org' }])
      expect(stub.served).to match([include(answered_by: 'validator.pairs[0]', request: include(role: :validator))])
    end

    it 'reports a validate call no Pair matches' do
      response = validate('other-profile', patient, 'cliContext' => { 'sv' => '4.0.1', 'txServer' => 'n/a' })

      expect(response.code).to eq('404')
      expect(stub.unmatched).to match([include(request: include(role: :validator, path: '/validate'),
                                               suggested_request: { 'profile' => 'other-profile',
                                                                    'resource' => 'Patient/p1' })])
      expect(stub.context_mismatches).to be_empty
    end

    context 'with its Pairs from a shared file' do
      let(:validator) { { 'pairs' => [{ 'from' => 'shared/validator.yml' }] } }

      it 'answers from them and reports where the Pair is written' do
        validate('example-patient', patient, 'cliContext' => {})

        expect(stub.served).to match([include(answered_by: 'validator.pairs[0] (shared/validator.yml[0])')])
      end
    end
  end
end
