# frozen_string_literal: true

require "cli/parser"

module Homebrew
  module_function

  def doi_url_to_other(url, format)
    return unless url.include? "doi.org/"

    Utils.popen_read("curl", "-LH", "Accept: #{format}", url).strip.gsub(/\n */, " ")
  end

  def doi_url_to_bib(url)
    doi_url_to_other(url, "text/bibliography; style=bibtex")
  end

  def doi_url_to_text(url)
    doi_url_to_other(url, "text/plain")
  end

  def cite_url(args, url)
    if args.ruby?
      bib = doi_url_to_bib url
      if bib
        key = bib[/{([^,]+),/, 1]
        puts %Q(# cite #{key}: "#{url}")
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

    return if !args.bib? && !default

    bib = doi_url_to_bib url
    puts bib if bib
  end

  def cite_doi(args, doi)
    cite_url args, "https://doi.org/#{doi}"
  end

  def cite_formula(args, name, follow: true)
    formula = Formula[name]
    matches = formula.path.read.scan(/# cite .*"(.*)"/)
    missing = []

    if matches.empty?
      missing << formula.full_name
    else
      matches.each { |match| cite_url args, match[0] }
    end

    if args.recursive? && follow
      formula.deps.each do |dep|
        missing += cite_formula(args, dep.name, follow: false)
      end
    end

    if !missing.empty? && (follow || !args.recursive?)
      opoo "Missing citations for the following formulae:"
      missing.each do |missing_name|
        puts "  #{missing_name}"
      end
    end

    missing
  end

  def cite_one(args, argument)
    case argument
    when %r{^https?://(dx\.)?doi\.org/}
      cite_url args, argument
    when /^10\./
      cite_doi args, argument
    else
      cite_formula args, argument
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
      named_args :formula, min: 1
    end
  end

  def cite
    args = cite_args.parse
    args.named.each { |s| cite_one args, s }
  end
end
