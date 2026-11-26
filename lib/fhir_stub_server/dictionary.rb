# frozen_string_literal: true

module FHIRStubServer
  # The `dictionary:` file, names to strings, replacing each `${name}` in a Pair's strings as plain
  # text when the Stub is built. Every `${...}` must name an entry; one Dictionary serves the
  # config's Pairs and those of every file they include.
  # @api private
  class Dictionary
    NAME = /\A[A-Za-z_][A-Za-z0-9_]*\z/
    VARIABLE = /\$\{([^}]*)\}/
    EXPRESSIONS = %w[select include resource].freeze

    # Without a path the Dictionary is empty, so any `${name}` is undefined.
    def self.load(path, dir)
      new(path ? values(File.expand_path(path, dir)) : {})
    end

    def self.values(file)
      values = FHIRStubServer.parse_file(file, :yaml)
      raise Error, "#{file}: the dictionary must be a mapping of names to strings" unless values.is_a?(Hash)

      values.each { |name, value| check(file, name, value) }
    end

    def self.check(file, name, value)
      raise Error, "#{file}: #{name} is no valid variable name" unless NAME.match?(name.to_s)
      raise Error, "#{file}: #{name} must be a string" unless value.is_a?(String)
    end

    private_class_method :values, :check

    # A `fhir.pairs` Pair, substituted in its request's `path`, `query` values and form `body`
    # values, and in its expressions; not in query names, a JSON `body` or a `body_file`.
    def self.fhir_pair(pair, resolve)
      request = resolved(pair['request'].to_h, %w[path query], resolve)
      form = Request.search?(method: request['method'].to_s.upcase, path: request['path'].to_s)
      pair.merge('request' => resolved(request, form ? %w[body] : [], resolve),
                 'response' => resolved(pair['response'].to_h, EXPRESSIONS, resolve))
    end

    def self.resolved(config, keys, resolve) = config.merge(resolve.call(config.slice(*keys)))

    def initialize(values)
      @values = values
    end

    def fhir_pair(pair, where) = Dictionary.fhir_pair(pair, resolver(where))

    def validator_key(pair, where) = resolver(where).call(pair.values_at('profile', 'resource'))

    private

    # Hash keys (query names) are left as written; `where` names the Pair in an undefined-variable error.
    def resolver(where)
      resolve = lambda do |value|
        case value
        when String then substitute(value, where)
        when Array then value.map(&resolve)
        when Hash then value.transform_values(&resolve)
        else value
        end
      end
    end

    def substitute(string, where)
      string.gsub(VARIABLE) do
        name = ::Regexp.last_match(1).to_s
        @values.fetch(name) { raise Error, "#{where}: undefined variable #{name}" }
      end
    end
  end
end
