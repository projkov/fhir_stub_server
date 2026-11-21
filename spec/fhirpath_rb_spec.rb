# frozen_string_literal: true

# Pins the fhirpath-rb in/contains defect that a README "Working with LLM agents" pitfall
# works around. When this fails after an upgrade, drop that pitfall and this spec.
RSpec.describe 'fhirpath-rb' do
  it 'finds nothing with in or contains on an element read from the resource, unless toString() comes first' do
    observation = { 'resourceType' => 'Observation', 'status' => 'final' }
    found = ->(expression) { Fhirpath.evaluate(observation, "where(#{expression})") }

    expect([found["status in ('final' | 'amended')"], found["('final' | 'amended') contains status"]]).to eq([[], []])
    expect(found["status.toString() in ('final' | 'amended')"]).to eq([observation])
  end
end
