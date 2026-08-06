# frozen_string_literal: true

require_relative "lib/airview/version"

Gem::Specification.new do |spec|
  spec.name = "airview"
  spec.version = Airview::VERSION
  spec.authors = ["jacksonriso"]
  spec.email = ["risojackson@gmail.com"]

  spec.summary = "A Rails engine for Airtable-like database views inside Rails apps."
  spec.description = "Airview mounts an internal admin UI for browsing and editing " \
                     "explicitly registered ActiveRecord models."
  spec.homepage = "https://github.com/jacksonriso/airview"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir[
    "app/**/*",
    "config/**/*",
    "db/**/*",
    "lib/**/*",
    "sig/**/*",
    "CHANGELOG.md",
    "CODE_OF_CONDUCT.md",
    "LICENSE.txt",
    "README.md"
  ]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1", "< 9.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
