# frozen_string_literal: true

module FHIRStubServer
  # A Rack app serving a Stub: the FHIR role under `fhir_base_path`, the validator role under
  # `validator_base_path`. Requests outside both get a plain 404 and are not recorded.
  # Needs no rack gem: it only reads the Rack env.
  class RackApp
    def initialize(stub, fhir_base_path: '/fhir', validator_base_path: '/validator')
      @stub = stub
      @base_paths = { fhir: fhir_base_path.chomp('/'), validator: validator_base_path.chomp('/') }
    end

    def call(env)
      role, base_path = base_path_for(env['PATH_INFO'])
      return [404, { 'content-type' => 'text/plain' }, ['Not Found']] unless role && base_path

      status, headers, body = @stub.respond(RackApp.stub_request(env, role, base_path))
      [status, headers, [body]]
    end

    def base_path_for(path)
      @base_paths.find { |_, base_path| path.match?(%r{\A#{Regexp.escape(base_path)}(?=/|\z)}) }
    end

    def self.stub_request(env, role, base_path)
      host = env['HTTP_HOST'] || "#{env['SERVER_NAME']}:#{env['SERVER_PORT']}"
      Stub.request(
        role:, method: env['REQUEST_METHOD'],
        base_url: "#{env['rack.url_scheme']}://#{host}#{env['SCRIPT_NAME']}#{base_path}",
        path: env['PATH_INFO'].delete_prefix(base_path),
        query: env['QUERY_STRING'].to_s,
        body: env['rack.input']&.read
      )
    end
  end
end
