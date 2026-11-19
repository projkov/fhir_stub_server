# frozen_string_literal: true

module FHIRStubServer
  # Loads Demo Data from an ordered list of Sources into one `Type/id` index; later Sources win.
  module Sources
    def self.load(sources)
      sources.flat_map { |source| resources(source) }
             .to_h { |resource| ["#{resource['resourceType']}/#{resource['id']}", resource] }
    end

    def self.resources(source)
      path = source['bundle'] or raise Error, "Unknown Source: #{source.inspect}"
      read_json(path).fetch('entry', []).map { |entry| entry['resource'] }
    end

    def self.read_json(path)
      JSON.parse(File.read(path))
    rescue Errno::ENOENT
      raise Error, "Source file not found: #{path}"
    end

    private_class_method :resources, :read_json
  end
end
