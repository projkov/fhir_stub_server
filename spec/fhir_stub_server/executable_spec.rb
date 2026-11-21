# frozen_string_literal: true

require 'open3'
require 'timeout'

RSpec.describe 'fhir-stub-server' do
  it 'serves a config over HTTP on the base URL it prints, logging misses with their nearest Pair' do
    exe = File.expand_path('../../exe/fhir-stub-server', __dir__)
    Open3.popen2e(RbConfig.ruby, exe, fixture('scenario.yml')) do |_stdin, output, process|
      base_url = Timeout.timeout(10) { output.each_line.lazy.filter_map { |line| line[%r{http://\S+/fhir}] }.first }

      expect(Net::HTTP.get_response(URI("#{base_url}/Patient/p2")).code).to eq('200')
      Net::HTTP.get_response(URI("#{base_url}/Observation?code=8867-4"))
      Process.kill('INT', process.pid)

      expect(output.read).to include('Unmatched fhir GET /Observation?code=8867-4; ' \
                                     'nearest fhir.pairs[1] (shared/nested/observations.yml[0])')
      expect(process.value).to be_success
    ensure
      Process.kill('KILL', process.pid) if process&.alive? # never leave a hung child behind
    end
  end
end
