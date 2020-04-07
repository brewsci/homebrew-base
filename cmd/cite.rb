# frozen_string_literal: true

require "cli/parser"

module Homebrew
  module_function

  def doi_url_to_other(url, format)
    return nil unless url.include? "doi.org/"
    Utils.popen_read("curl", "-LH", "Accept: #{format}", url).strip.gsub(/\n */, " ")
  end

  def doi_url_to_bib(url)
    doi_url_to_other(url, "text/bibliography; style=bibtex")
  end

  def doi_url_to_text(url)
    doi_url_to_other(url, "text/plain")
  end

  def cite_url(url)
    if args.ruby?
      bib = doi_url_to_bib url
      if bib
        key = bib[/{([^,]+),/, 1]
        puts %Q{# cite #{key}: "#{url}"}
      else
        opoo "No DOI for #{url}"
      end
      return
    end

    default = !args.bib? && !args.doi? && !args.text? && !args.url?
    doi = url[%r{^https://doi\.org/(.*)}, 1]
    opoo "No DOI for #{url}" if !doi && (args.bib? || args.doi? || args.text? || default)

    puts doi if args.doi? && doi
    puts url if args.url?
    if args.text?
      text = doi_url_to_text url
      puts text if text
    end
    if args.bib? || default
      bib = doi_url_to_bib url
      puts bib if bib
    end
  end

  def cite_doi(doi)
    cite_url "https://doi.org/#{doi}"
  end

  def cite_formula(name, follow = true)
    formula = Formula[name]
    matches = formula.path.read.scan /# cite .*"(.*)"/
    missing = []

    if matches.empty?
      missing << formula.full_name
    else
      matches.each { |match| cite_url match[0] }
    end

    if args.recursive? and follow
      formula.deps.each do |dep|
        missing += cite_formula(dep.name, false)
      end
    end

    if not missing.empty? and (follow or not args.recursive?)
      opoo "Missing citations for the following formulae:"
      missing.each do |name|
        puts "  #{name}"
      end
    end

    missing
  end

  def cite_one(argument)
    case argument
    when %r{^https?://(dx\.)?doi\.org/}
      cite_url argument
    when /^10\./
      cite_doi argument
    else
      cite_formula argument
    end
  end

  def cite_args
    Homebrew::CLI::Parser.new do
      usage_banner <<~EOS
        `cite` [`--bib`] [`--doi`] [`--ruby`] [`--text`] [`--url`] [`--recursive`] <formula_or_doi>...

        Display citations of formulae and DOI.
      EOS

      switch "--bib"
      switch "--doi"
      switch "--recursive"
      switch "--ruby"
      switch "--text"
      switch "--url"
      min_named :formula
    end
  end

  def cite
    cite_args.parse
    args.named.each { |s| cite_one s }
  end
end
