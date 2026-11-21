# frozen_string_literal: true

module FHIRStubServer
  # Splices the `{ from: <path> }` entries of a Pair list (`fhir.pairs`, `validator.pairs`): the
  # file holds a YAML list of Pairs, which may itself have `from:` entries. Paths in a file,
  # `from:` and `body_file` alike, are relative to that file.
  # @api private
  class Includes
    # Each Pair as [pair, dir, where]: the directory of the file it is written in, and where it is
    # written, e.g. `fhir.pairs[3]` or `fhir.pairs[3] (shared/patient.yml[7])`, paths relative to `dir`.
    def self.splice(entries, name, dir)
      new(name, dir).pairs(entries)
    end

    def initialize(name, dir)
      @name = name
      @root = File.expand_path(dir)
    end

    # `trail` lists [file, index] of each entry leading here; the config's own list has no file.
    def pairs(entries, file = nil, trail = [])
      dir = file ? File.dirname(file) : @root
      entries.each_with_index.flat_map do |entry, index|
        at = [*trail, [file, index]] #: trail
        entry_pairs(entry, dir, at)
      end
    end

    private

    def entry_pairs(entry, dir, at)
      return included(from_path(entry, dir, at), at) if entry.is_a?(Hash) && entry.key?('from')

      [[entry, dir, where(at)]] #: Array[spliced]
    end

    def from_path(include, dir, at)
      from = include['from']
      raise Error, "#{where(at)}: an include is { from: <path> } only" unless include.size == 1 && from.is_a?(String)

      File.expand_path(from, dir)
    end

    def included(file, at)
      entries = read(file, at)
      return pairs(entries, file, at) if entries.is_a?(Array)

      raise Error, "#{where(at)}: #{relative(file)} must hold a list of Pairs"
    end

    def read(file, at)
      raise Error, "including #{relative(file)} again is a cycle" if at.any? { |(seen)| seen == file }

      FHIRStubServer.parse_file(file, :yaml)
    rescue Error => error
      raise Error, "#{where(at)}: #{error.message}"
    end

    def where(at)
      (_, index), *included = at
      files = included.map { |file, position| "#{relative(file.to_s)}[#{position}]" }
      ["#{@name}[#{index}]", ("(#{files.join(' > ')})" unless files.empty?)].compact.join(' ')
    end

    def relative(file)
      Pathname(file).relative_path_from(@root).to_s
    end
  end
end
