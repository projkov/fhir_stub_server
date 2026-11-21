# frozen_string_literal: true

module FHIRStubServer
  # One line per #unmatched entry, for Replay's log and Stub#unmatched_report.
  module Unmatched
    # The request, its nearest Pair and the differing parameters, then the suggested request as
    # JSON, which is valid YAML: it pastes into the config after `- request:` (`- ` for a
    # validator Pair, adding `issues`).
    def self.describe(miss)
      request = miss[:request]
      nearest = miss[:nearest_pair]
      near = "; nearest #{nearest}: #{differences(miss[:differences])}" if nearest
      line = ["#{request[:role]} #{request[:method]} #{request[:path]}", URI.encode_www_form(request[:query])]
      "Unmatched #{line.reject(&:empty?).join('?')}#{near}#{suggestion(miss)}"
    end

    def self.differences(differences)
      differences.map { |name, values| "#{name} expected #{values[:expected].inspect}, got #{values[:actual].inspect}" }
                 .join('; ')
    end

    # A validator suggestion is a whole Pair but `issues`, so it is labelled `pair`.
    def self.suggestion(miss)
      suggested = miss[:suggested_request]
      return '' unless suggested

      "; #{miss[:request][:role] == :validator ? 'pair' : 'request'}: #{JSON.generate(suggested)}"
    end

    private_class_method :differences, :suggestion
  end
end
