Gem::Specification.new do |spec|
  spec.name          = 'spectre-rabbitmq'
  spec.version       = '1.0.1'
  spec.authors       = ['Christian Neubauer']
  spec.email         = ['christian.neubauer@ionos.com']

  spec.summary       = 'RabbitMQ module for spectre'
  spec.description   = 'Adds RabbitMQ functionality to the spectre framework'
  spec.homepage      = 'https://github.com/ionos-spectre/spectre-rabbitmq'
  spec.license       = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.0.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ionos-spectre/spectre-rabbitmq'
  spec.metadata['changelog_uri'] = 'https://github.com/ionos-spectre/spectre-rabbitmq/blob/master/CHANGELOG.md'

  spec.files        += Dir.glob('lib/**/*')

  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'spectre-core', '>= 1.14.0'
  spec.add_runtime_dependency 'bunny', '~> 2.20.3'
end
