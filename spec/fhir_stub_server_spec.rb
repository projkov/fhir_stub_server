# frozen_string_literal: true

RSpec.describe FHIRStubServer do
  it 'has a version number' do
    expect(FHIRStubServer::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
