# frozen_string_literal: true

RSpec.describe FHIRStubServer do
  it 'has a version number' do
    expect(FHIRStubServer::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe '.load' do
    it "builds a Stub from a scenario.yml's server: block, paths relative to the file" do
      stub = described_class.load(fixture('scenario.yml'))
      FHIRStubServer::WebMockAdapter.install(stub, fhir_base_url: 'http://fhir.stub.test/fhir')

      responses = %w[p1 p2].map { |id| Net::HTTP.get_response(URI("http://fhir.stub.test/fhir/Patient/#{id}")) }

      expect(responses.map(&:code)).to eq(%w[404 200])
      expect(stub.served.map { |entry| entry[:answered_by] }).to eq(['fhir.pairs[0]', :demo_data])
    end
  end
end
