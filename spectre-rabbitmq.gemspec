Gem::Specification.new do |spec|
  spec.name          = 'spectre-rabbitmq'
  spec.version       = '2.0.0'
  spec.authors       = ['Christian Neubauer']
  spec.email         = ['christian.neubauer@ionos.com']

  spec.summary       = 'RabbitMQ module for spectre'
  spec.description   = 'Adds RabbitMQ functionality to the spectre framework'
  spec.homepage      = 'https://github.com/ionos-spectre/spectre-rabbitmq'
  spec.license       = 'GPL-3.0-or-later'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org/'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/ionos-spectre/spectre-rabbitmq'
  spec.metadata['changelog_uri'] = 'https://github.com/ionos-spectre/spectre-rabbitmq/blob/master/CHANGELOG.md'

  spec.files        += Dir.glob('lib/**/*')

  spec.require_paths = ['lib']

  spec.add_dependency 'bunny'
  spec.add_dependency 'logger'
  spec.add_dependency 'ostruct'
end
