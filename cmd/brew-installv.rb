#:  * `installv` [<options>] <formulae>
#:
#:    Install specified versions of formulae.
#:
#:    The syntax to specify a formula and version is
#:      name=version_revision.rebuild
#:    Version, revision, and rebuild are optional.
#:    Version defaults to the current version unless specified.
#:    Revision and rebuild default to 0 unless specified.
#:    For example:
#:      coreutils, coreutils=8.30, coreutils=8.30_2, coreutils=8.30_2.1

module Homebrew
  module_function

  def bintray_filename(name, version, revision, rebuild)
    revision = revision.blank? ? 0 : revision.to_i
    revision = revision.positive? ? "_#{revision}" : ""
    rebuild = rebuild.blank? ? 0 : rebuild.to_i
    rebuild = rebuild.positive? ? ".#{rebuild}" : ""
    "#{name}-#{version}#{revision}.#{Utils::Bottles.tag}.bottle#{rebuild}.tar.gz"
  end

  def to_name_url(name_version)
    name, full_version = name_version.split("=", 2)
    return name unless full_version

    version, revision_rebuild = full_version.split("_", 2)
    revision, rebuild = revision_rebuild&.split(".", 2)
    root_url = Formula[name].bottle_specification.root_url
    [name, "#{root_url}/#{bintray_filename(name, version, revision, rebuild)}"]
  end

  def install_formulae
    raise FormulaUnspecifiedError if ARGV.named.empty?
    dry_run = ARGV.dry_run?
    options = ARGV.options_only - ["-n", "--dry-run"]
    ENV["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
    ARGV.named.each do |name_version|
      name, url = to_name_url name_version
      if dry_run
        puts [HOMEBREW_BREW_FILE, "install", *options, url].join(" ")
      else
        safe_system HOMEBREW_BREW_FILE, "unlink", name if Formula[name].linked?
        safe_system HOMEBREW_BREW_FILE, "install", *options, url
      end
    end
  end
end

Homebrew.install_formulae
