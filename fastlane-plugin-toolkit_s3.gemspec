lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/toolkit_s3/version'

Gem::Specification.new do |spec|
	spec.name = 'fastlane-plugin-toolkit_s3'
	spec.version = Fastlane::ToolkitS3::VERSION
	spec.author = 'UpBra'
	spec.email = 'UpBra@users.noreply.github.com'

	spec.summary = 'a short summary'
	# spec.homepage = "https://github.com/<GITHUB_USERNAME>/fastlane-plugin-toolkit_s3"
	spec.license = "MIT"

	spec.files = Dir["lib/**/*"] + %w(README.md LICENSE)
	spec.require_paths = ['lib']
	spec.metadata['rubygems_mfa_required'] = 'true'
	spec.required_ruby_version = '>= 2.6'

	spec.add_dependency('aws-sdk-s3', '~> 1')
end
