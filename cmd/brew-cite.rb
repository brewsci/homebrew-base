#:  * `cite` [`--bib`] [`--doi`] [`--ruby`] [`--text`] [`--url`] <formula_or_doi>...
#:    Display citations of formulae and DOI.

require "cli_parser"

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

  def cite_formula(name)
    formula = Formula[name]
    matches = formula.path.read.scan /# cite .*"(.*)"/
    if matches.empty?
      opoo "#{formula.full_name}: No citation"
    else
      matches.each { |match| cite_url match[0] }
    end
  end

  def cite(argument)
    case argument
    when %r{^https?://(dx\.)?doi\.org/}
      cite_url argument
    when /^10\./
      cite_doi argument
    else
      cite_formula argument
    end
  end

  def cite_many
    Homebrew::CLI::Parser.parse do
      switch "--bib"
      switch "--doi"
      switch "--ruby"
      switch "--text"
      switch "--url"
    end

    raise FormulaUnspecifiedError if ARGV.named.empty?
    ARGV.named.each { |s| cite s }
  end
end

Homebrew.cite_many
