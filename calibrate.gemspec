Gem::Specification.new do |spec|
  spec.name		= "calibrate"
  spec.version		= "0.0.2"
  author_list = {
    "Judson Lester" => 'nyarly@gmail.com'
  }
  spec.authors		= author_list.keys
  spec.email		= spec.authors.map {|name| author_list[name]}
  spec.summary		= "Configuration fields for Ruby objects"
  spec.description	= <<-EndDescription
  Add configurable settings to ruby object that can have defaults, be required, depend on one another.
  EndDescription

  spec.rubyforge_project= spec.name.downcase
  spec.homepage        = "http://nyarly.github.com/#{spec.name.downcase}"
  spec.required_rubygems_version = Gem::Requirement.new(">= 0") if spec.respond_to? :required_rubygems_version=

  # Do this: y$@"
  # !!find lib bin doc spec spec_help -not -regex '.*\.sw.' -type f 2>/dev/null
  spec.files		= %w[
    lib/calibrate.rb
    lib/calibrate/configurable/field-processor.rb
    lib/calibrate/configurable/proxy-value.rb
    lib/calibrate/configurable/instance-methods.rb
    lib/calibrate/configurable/class-methods.rb
    lib/calibrate/configurable/directory-structure.rb
    lib/calibrate/configurable/field-metadata.rb
    lib/calibrate/yard-extensions.rb
    lib/calibrate/configurable.rb
    spec/configurable.rb
    spec_help/spec_helper.rb
    spec_help/gem_test_suite.rb
  ]

  spec.test_file        = "spec_help/gem_test_suite.rb"
  spec.licenses = ["MIT"]
  spec.require_paths = %w[lib/]
  spec.rubygems_version = "1.3.5"

  spec.has_rdoc		= true
  spec.extra_rdoc_files = Dir.glob("doc/**/*")
  spec.rdoc_options	= %w{--inline-source }
  spec.rdoc_options	+= %w{--main doc/README }
  spec.rdoc_options	+= ["--title", "#{spec.name}-#{spec.version} Documentation"]

  spec.add_dependency("rake", ">= 12.3", "< 14.0")

  #spec.post_install_message = "Thanks for installing my gem!"
end
