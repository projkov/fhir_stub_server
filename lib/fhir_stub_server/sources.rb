# frozen_string_literal: true

module FHIRStubServer
  # Loads Demo Data from an ordered list of Sources into one `Type/id` index; later Sources win.
  # A Source is `package: <FHIR NPM package .tgz>` or `bundle: <Bundle .json>`.
  # @api private
  module Sources
    MODELS = { '1.0' => 'dstu2', '3.0' => 'stu3', '4.0' => 'r4', '5.0' => 'r5' }.freeze

    # Returns the index, the load-time #served entries for resources skipped for having no id,
    # and the fhirpath-rb model of the packages' FHIR version. Source paths are relative to `dir`.
    def self.load(sources, dir)
      loaded = sources.map { |source| located_resources(source, dir) }
      kept, skipped = loaded.flat_map(&:first).partition { |_, resource| resource['id'] }
      [index(kept), skipped_entries(skipped), model(loaded.filter_map(&:last))]
    end

    # The model every package stating FHIR versions supports, in the first one's order; R4 when
    # none states any, as a Bundle carries none.
    def self.model(stated)
      stated = stated.reject { |_, versions| versions.empty? }
      common = stated.map { |path, versions| models(path, versions) }.reduce(:&) || ['r4']
      common.first || raise(no_common_version(stated))
    end

    def self.no_common_version(stated)
      packages = stated.map { |path, versions| "#{path} (#{versions.join(', ')})" }
      Error.new("Demo Data packages share no FHIR version: #{packages.join(', ')}")
    end

    # The models for a package's FHIR versions, skipping versions without one.
    def self.models(path, versions)
      models = versions.filter_map { |version| MODELS[version.to_s[/\A\d+\.\d+/].to_s] }
      return models unless models.empty?

      raise Error, "#{path}: FHIR #{versions.join(', ')} has no FHIRPath model"
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

    # A Source's resources as [location, resource] pairs, the location naming the file, and for
    # a package [path, the FHIR versions it states].
    def self.located_resources(source, dir)
      package, bundle = source.values_at('package', 'bundle').map { |path| File.expand_path(path, dir) if path }
      return package_resources(package) if package
      return [bundle_resources(bundle), nil] if bundle

      raise Error, "Unknown Source: #{source.inspect}"
    end

    # Every JSON file with a resourceType: examples and conformance resources alike. Anything
    # else (.index.json, openapi/, xml/, empty files) is not a resource and is left out; of
    # package.json only `fhirVersions` counts. Bundles stay whole.
    def self.package_resources(path)
      files = json_files(path)
      resources = files.filter_map do |name, json|
        ["#{path} (#{name})", json] if json.key?('resourceType')
      end #: Array[located]
      [no_duplicates(resources), [path, Array(files.to_h['package/package.json'].to_h['fhirVersions'])]]
    end

    def self.json_files(path)
      Zlib::GzipReader.wrap(StringIO.new(FHIRStubServer.read_file(path).b)) { |archive| tar_json_files(archive) }
    rescue Zlib::Error, Gem::Package::TarInvalidError => error
      raise Error, "#{path}: not a FHIR package .tgz (#{error.message})"
    end

    def self.tar_json_files(archive)
      Gem::Package::TarReader.new(archive).filter_map do |entry|
        name = entry.full_name
        json = json(entry) if name.end_with?('.json')
        [name, json] if json.is_a?(Hash)
      end
    end

    def self.json(entry)
      JSON.parse(entry.read.to_s)
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

    private_class_method :model, :no_common_version, :models, :index, :skipped_entries, :server_capability_statement,
                         :server?, :key, :located_resources, :package_resources, :json_files, :tar_json_files, :json,
                         :bundle_resources, :no_duplicates, :duplicate
  end
end
