require 'net/ssh'
require 'logger'
require 'spectre'


module Spectre
  module RabbitMQ
    class RabbitMQAction
      attr_reader :action

      def initialize config
        @config = config
      end

      def action name
        raise "invalid action '#{name}'" unless ['publish', 'subscribe'].include? name
        @config['action'] = name
      end

      def host hostname
        @config['host'] = hostname
      end

      def username user
        @config['username'] = user
      end

      def password pass
        @config['password'] = pass
      end

      def virtual_host vhost
        @config['virtual_host'] = vhost
      end

      def body data
        @config['body'] = data
      end

      def exchange name, type: 'topic', durable: false
        @config['exchange'] = {
          'name' => name,
          'durable' => durable,
          'type' => type,
        }
      end

      def queue name, durable: false
        @config['queue'] = {
          'name' => name,
          'durable' => durable,
        }
      end

      def routing_key name
        @config['routing_key'] = name
      end
    end

    class << self
      @@config = {}

      def rabbitmq name, options = {}, &block
        if @@config.key? name
          config = @@config[name]
        else
          config
        end

        action = RabbitMQAction.new(config)
      end

      def configure config
        @@logger = Spectre::Logging::ModuleLogger.new('spectre/rabbitmq')

        if config.key? 'rabbitmq'
          config['rabbitmq'].each do |name, cfg|
            @@config[name] = cfg
          end
        end
      end

      private

      def publish config

      end

      def subscribe config

      end
    end

    Spectre.delegate :rabbitmq, to: self
  end
end
