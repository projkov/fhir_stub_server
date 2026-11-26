# frozen_string_literal: true

module FHIRStubServer
  # A `select` Pair's `page_size: n` splits its matches into pages of n. The first page answers
  # the Pair's request, the next ones are GETs of continuation URLs below the FHIR base,
  # /_page/<the Pair's index in the list>/<page>, which each page's `next` link names.
  # @api private
  module Paging
    # Page 1 is the Pair's own request, so a continuation URL names page 2 or later.
    PATH = %r{\A/_page/(\d+)/([2-9]|[1-9]\d+)\z}

    # [index, page] of the first Pair whose request the key matches (page 1) or of the Pair and
    # page a continuation URL names; nil for neither.
    def self.locate(pairs, key)
      index = pairs.index { |pair| Request.match?(pair[:key], key) }
      index ? page(index, 1) : continued(key)
    end

    def self.continued(key)
      found = PATH.match(key[:path]) if key[:method] == 'GET' && key[:query].empty?
      index, number = found&.captures.to_a.map(&:to_i)
      page(index, number) if index && number
    end

    def self.page(index, number) = [index, { number:, path: "/_page/#{index}" }]

    def self.body(config, results, where)
      matches = results.fetch('select', [])
      pages = split(matches, results.fetch('include', []), size(config, matches, where))
      ->(request, page) { Responses.searchset(request, pages, page) }
    end

    # The response's `page_size`; without one, all matches on one page (one more, as each_slice rejects 0).
    def self.size(config, matches, where)
      size = config['page_size']
      return matches.size + 1 unless size
      return size if size.is_a?(Integer) && size.positive?

      raise Error, "#{where}: page_size must be a positive integer"
    end

    # Each page's [matches, includes], `size` matches each and the includes on the first page,
    # each fullUrl once; and the total of all matches, which every page carries.
    def self.split(matches, includes, size)
      first, *rest = matches.each_slice(size).to_a
      { total: matches.size, entries: [[first.to_a, includes.uniq - matches], *rest.map { |slice| [slice, []] }] }
    end

    private_class_method :continued, :page, :size, :split
  end
end
