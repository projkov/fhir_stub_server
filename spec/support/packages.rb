# frozen_string_literal: true

require 'fileutils'
require 'rubygems/package'
require 'tmpdir'
require 'zlib'

PACKAGE_DIR = Dir.mktmpdir('fhir_stub_server_packages')
at_exit { FileUtils.remove_entry(PACKAGE_DIR) }

# Writes a FHIR NPM package archive from { path in the archive => Hash (as JSON) or String }.
def build_package(name, files)
  path = File.join(PACKAGE_DIR, "#{name}.tgz")
  Zlib::GzipWriter.open(path) do |gzip|
    Gem::Package::TarWriter.new(gzip) do |tar|
      files.each do |file, content|
        body = content.is_a?(String) ? content : JSON.generate(content)
        tar.add_file_simple(file, 0o644, body.bytesize) { |io| io.write(body) }
      end
    end
  end
  path
end

# The edge cases an IG package has: housekeeping JSON without resourceType, an OpenAPI file
# with a byte order mark, an xml/ folder, an empty file, conformance resources, two
# CapabilityStatements, a Bundle and an example without an id.
IG_PACKAGE_FILES = {
  'package/package.json' => { 'name' => 'example.ig', 'version' => '1.0.0' },
  'package/.index.json' => { 'index-version' => 2, 'files' => [] },
  'package/openapi/Patient.json' => "\xEF\xBB\xBF{\"openapi\": \"3.0.0\"}",
  'package/other/empty.json' => '',
  'package/xml/Patient-pkg.xml' => '<Patient xmlns="http://hl7.org/fhir"><id value="pkg"/></Patient>',
  'package/StructureDefinition-example-patient.json' => { 'resourceType' => 'StructureDefinition',
                                                          'id' => 'example-patient' },
  'package/CapabilityStatement-requester.json' => { 'resourceType' => 'CapabilityStatement', 'id' => 'requester',
                                                    'rest' => [{ 'mode' => 'client' }] },
  'package/CapabilityStatement-responder.json' => { 'resourceType' => 'CapabilityStatement', 'id' => 'responder',
                                                    'rest' => [{ 'mode' => 'server' }] },
  'package/example/Patient-p2.json' => { 'resourceType' => 'Patient', 'id' => 'p2', 'gender' => 'female' },
  'package/example/Patient-no-id.json' => { 'resourceType' => 'Patient' },
  'package/example/Bundle-b1.json' => {
    'resourceType' => 'Bundle', 'id' => 'b1', 'type' => 'collection',
    'entry' => [{ 'resource' => { 'resourceType' => 'Patient', 'id' => 'inside' } }]
  }
}.freeze

def ig_package
  @ig_package ||= build_package('ig', IG_PACKAGE_FILES)
end
