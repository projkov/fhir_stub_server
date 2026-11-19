# frozen_string_literal: true

def fixture(name)
  File.expand_path("../fixtures/#{name}", __dir__)
end
