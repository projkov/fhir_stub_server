# frozen_string_literal: true

RSpec.describe FHIRStubServer::Stub, '.new' do
  pair = lambda do |response, request = { 'path' => '/metadata' }|
    { 'fhir' => { 'sources' => [{ 'bundle' => fixture('demo.json') }],
                  'pairs' => [{ 'request' => request, 'response' => response }] } }
  end

  duplicates = build_package('duplicates',
                             'package/Patient-a.json' => { 'resourceType' => 'Patient', 'id' => 'dup' },
                             'package/example/Patient-b.json' => { 'resourceType' => 'Patient', 'id' => 'dup' })

  # fhirpath-rb 0.1.7 reads birthDate as the Hash of _birthDate and raises a TypeError.
  absent_birth_date = build_package('absent_birth_date', 'package/Patient-p1.json' => {
                                      'resourceType' => 'Patient', 'id' => 'p1',
                                      '_birthDate' => { 'extension' => [{ 'url' => 'http://example.org/absent' }] }
                                    })

  fhir_package = lambda do |version|
    build_package("fhir#{version}", 'package/package.json' => { 'fhirVersions' => [version] })
  end

  {
    'packages for different FHIR versions' => [
      { 'fhir' => { 'sources' => [{ 'package' => fhir_package['4.0.1'] }, { 'package' => fhir_package['5.0.0'] }] } },
      %r{Demo Data packages share no FHIR version: .*/fhir4\.0\.1\.tgz \(4\.0\.1\), .*/fhir5\.0\.0\.tgz \(5\.0\.0\)}
    ],
    'a FHIR version without a FHIRPath model' => [
      { 'fhir' => { 'sources' => [{ 'package' => fhir_package['4.3.0'] }] } },
      %r{/fhir4\.3\.0\.tgz: FHIR 4\.3\.0 has no FHIRPath model}
    ],
    'a missing Source file' => [
      { 'fhir' => { 'sources' => [{ 'bundle' => '/missing/demo.json' }] } }, %r{/missing/demo\.json}
    ],
    'a Type/id twice in one package' => [
      { 'fhir' => { 'sources' => [{ 'package' => duplicates }] } },
      %r{Patient/dup is in both .*\(package/Patient-a\.json\) and .*\(package/example/Patient-b\.json\)}
    ],
    'several server CapabilityStatements' => [
      { 'fhir' => { 'sources' => [{ 'bundle' => fixture('two_servers.json') }] } },
      /several server CapabilityStatements \(a, b\)/
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
    ],
    'a resource expression yielding nothing' => [
      pair.call({ 'resource' => "entry.resource.where(id = 'none')" }), /fhir\.pairs\[0\]: .*exactly one.*got 0/
    ],
    'a resource expression yielding several' => [
      pair.call({ 'resource' => 'entry.resource.ofType(CapabilityStatement)' }), /exactly one.*got 2/
    ],
    'an include without select' => [
      pair.call({ 'resource' => 'entry.resource.ofType(Patient).first()', 'include' => 'entry.resource' }),
      /fhir\.pairs\[0\]: include needs select/
    ],
    'an invalid FHIRPath expression' => [
      pair.call({ 'select' => 'entry.resource.((' }), /fhir\.pairs\[0\]: entry\.resource\.\(\(/
    ],
    'a select expression yielding no resource' => [
      pair.call({ 'select' => 'entry.resource.id' }),
      /\Afhir\.pairs\[0\]: entry\.resource\.id must yield resources only\z/
    ],
    'a missing included file' => [
      { 'fhir' => { 'pairs' => [{ 'from' => '/missing/pairs.yml' }] } },
      %r{\Afhir\.pairs\[0\]: Cannot read /missing/pairs\.yml}
    ],
    'an include that is more than a from: path' => [
      { 'fhir' => { 'pairs' => [{ 'from' => 5 }] } }, /\Afhir\.pairs\[0\]: an include is \{ from: <path> \} only\z/
    ],
    'an included file that is no list' => [
      { 'validator' => { 'pairs' => [{ 'from' => fixture('demo.json') }] } },
      %r{\Avalidator\.pairs\[0\]: .*spec/fixtures/demo\.json must hold a list of Pairs\z}
    ],
    'an include cycle' => [
      { 'fhir' => { 'pairs' => [{ 'from' => fixture('shared/cycle.yml') }] } },
      %r{\Afhir\.pairs\[0\] \(.*shared/cycle\.yml\[0\]\): including .*shared/cycle\.yml again is a cycle\z}
    ],
    'an expression fhirpath-rb fails on' => [
      { 'fhir' => { 'sources' => [{ 'package' => absent_birth_date }],
                    'pairs' => [{ 'request' => { 'path' => '/Patient' },
                                  'response' => {
                                    'select' => 'entry.resource.where(birthDate.convertsToDate())'
                                  } }] } },
      /fhir\.pairs\[0\]: entry\.resource\.where\(birthDate\.convertsToDate\(\)\): TypeError: no implicit conversion/
    ]
  }.each do |name, (config, message)|
    it "raises on #{name}" do
      expect { described_class.new(config) }.to raise_error(FHIRStubServer::Error, message)
    end
  end
end
