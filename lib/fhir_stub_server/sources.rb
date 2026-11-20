# frozen_string_literal: true

module FHIRStubServer
  # Loads Demo Data from an ordered list of Sources into one `Type/id` index; later Sources win.
  # A Source is `package: <FHIR NPM package .tgz>` or `bundle: <Bundle .json>`.
  module Sources
    # Returns the index and the load-time #served entries for resources skipped for having no id.
    # Source paths are relative to `dir`.
    def self.load(sources, dir)
      located = sources.flat_map { |source| located_resources(source, dir) }
      kept, skipped = located.partition { |_, resource| resource['id'] }
      [index(kept), skipped_entries(skipped)]
    end

    def self.index(located)
      located.to_h { |_, resource| [key(resource), resource] }
    end

    def self.skipped_entries(skipped)
      skipped.map { |location, _| { kind: :load, skipped: location, reason: 'resource without id' } }
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

    def self.key(resource)
      "#{resource['resourceType']}/#{resource['id']}"
    end

    # A Source's resources as [location, resource] pairs, the location naming the file.
    def self.located_resources(source, dir)
      package, bundle = source.values_at('package', 'bundle').map { |path| File.expand_path(path, dir) if path }
      return no_duplicates(package_resources(package)) if package
      return bundle_resources(bundle) if bundle

      raise Error, "Unknown Source: #{source.inspect}"
    end

    # Every JSON file with a resourceType: examples and conformance resources alike. Anything
    # else (package.json, .index.json, openapi/, xml/, empty files) is not a resource and is
    # left out. Bundles stay whole.
    def self.package_resources(path)
      Zlib::GzipReader.wrap(StringIO.new(FHIRStubServer.read_file(path).b)) { |archive| tar_resources(path, archive) }
    rescue Zlib::Error, Gem::Package::TarInvalidError => error
      raise Error, "#{path}: not a FHIR package .tgz (#{error.message})"
    end

    def self.tar_resources(path, archive)
      Gem::Package::TarReader.new(archive).filter_map { |entry| package_resource(path, entry) }
    end

    def self.package_resource(path, entry)
      resource = json(entry)
      ["#{path} (#{entry.full_name})", resource] if resource.is_a?(Hash) && resource.key?('resourceType')
    end

    def self.json(entry)
      JSON.parse(entry.read.to_s) if entry.full_name.end_with?('.json')
    rescue JSON::ParserError
      nil
    end

    def self.bundle_resources(path)
      entries = FHIRStubServer.parse_file(path, :json)['entry'].to_a
      # An entry without a resource (a delete in a transaction) adds nothing.
      entries.each_with_index.filter_map do |entry, index|
        resource = entry['resource']
        ["#{path} (entry[#{index}])", resource] if resource
      end
    end

    # Tar order is not meaningful, so two files with one `Type/id` in a package are an error.
    def self.no_duplicates(located)
      key, copies = duplicate(located)
      raise Error, "#{key} is in both #{copies.map(&:first).join(' and ')}" if copies

      located
    end

    def self.duplicate(located)
      located.select { |_, resource| resource['id'] }.group_by { |_, resource| key(resource) }
             .find { |_, copies| copies.size > 1 }
    end

    private_class_method :index, :skipped_entries, :server_capability_statement, :server?, :key, :located_resources,
                         :package_resources, :tar_resources, :package_resource, :json, :bundle_resources,
                         :no_duplicates, :duplicate
  end
end
