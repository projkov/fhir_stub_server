# frozen_string_literal: true

module FHIRStubServer
  # Loads Demo Data from an ordered list of Sources into one `Type/id` index; later Sources win.
  module Sources
    def self.load(sources)
      sources.flat_map { |source| resources(source) }
             .to_h { |resource| ["#{resource['resourceType']}/#{resource['id']}", resource] }
    end

    # What the built-in reads answer: `/<Type>/<id>` for every resource, and `/metadata` for the
    # one CapabilityStatement with a `server` rest mode (an IG's responder), when there is one.
    def self.reads(demo_data)
      reads = demo_data.transform_keys { |key| "/#{key}" }
      metadata = server_capability_statement(demo_data.values)
      metadata ? reads.merge('/metadata' => metadata) : reads
    end

    def self.server_capability_statement(resources)
      servers = resources.select { |resource| server?(resource) }
      return servers.first unless servers.size > 1

      raise Error, "Demo Data has several server CapabilityStatements (#{servers.map { |cs| cs['id'] }.join(', ')}); " \
                   '/metadata needs at most one'
    end

    def self.server?(resource)
      resource['resourceType'] == 'CapabilityStatement' &&
        resource['rest'].to_a.any? { |rest| rest['mode'] == 'server' }
    end

    def self.resources(source)
      path = source['bundle'] or raise Error, "Unknown Source: #{source.inspect}"
      read_json(path).fetch('entry', []).map { |entry| entry['resource'] }
    end

    def self.read_json(path)
      JSON.parse(FHIRStubServer.read_file(path))
    end

    private_class_method :server_capability_statement, :server?, :resources, :read_json
  end
end
