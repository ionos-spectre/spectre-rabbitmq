require 'net/ssh'
require 'logger'
require 'spectre'
require 'spectre/logger'
require 'ostruct'
require 'bunny'


module Spectre
  module RabbitMQ
    class ActionParamsBase
      attr_reader :config

      def initialize config, logger
        @logger = logger
        @config = config.deep_clone
        @config['routing_keys'] = []
      end

      def exchange name, type: 'topic', durable: false, auto_delete: false
        @config['exchange'] = {
          'name' => name,
          'durable' => durable,
          'type' => type,
          'auto_delete' => auto_delete,
        }
      end

      def topic name, durable: false, auto_delete: false
        exchange(name, type: 'topic', durable: durable, auto_delete: auto_delete)
      end

      def routing_keys *names
        @config['routing_keys'] = names
      end

      def routing_key name
        @config['routing_keys'] << name
      end
    end

    class ConsumeActionParams < ActionParamsBase
      def initialize config, logger
        super config, logger

        @config['queue'] = {
          'name' => nil,
          'durable' => false,
          'auto_delete' => false,
        }
      end

      def queue name, durable: false, auto_delete: false
        @config['queue'] = {
          'name' => name,
          'durable' => durable,
          'auto_delete' => auto_delete,
        }
      end

      def timeout seconds
        @config['timeout'] = seconds
      end
    end

    class PublishActionParams < ActionParamsBase
      def body data
        @config['body'] = data
      end

      def correlation_id id
        @config['correlation_id'] = id
      end

      def reply_to receiver
        @config['reply_to'] = receiver
      end
    end

    class RabbitMQAction < Spectre::DslClass
      attr_reader :conn, :action, :threads, :result

      def initialize config, logger
        @logger = logger
        @config = config
        @conn = nil

        @threads = []
        @result = nil

        @config['ssl'] = false
      end

      def action name
        raise "invalid action '#{name}'" unless ['publish', 'subscribe'].include? name

        @config['action'] = name
      end

      def host hostname
        @config['host'] = hostname
      end

      def use_ssl!
        @config['ssl'] = true
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

      def consume &block
        params = ConsumeActionParams.new(@config, @logger)
        params.instance_eval(&block)

        connect

        channel = @conn.create_channel

        queue = channel.queue(
          params.config['queue']['name'],
          durable: params.config['queue']['durable'],
          auto_delete: params.config['queue']['auto_delete'],
        )

        queue = channel.queue(params.config['queue']['name'], durable: params.config['queue']['durable'])

        params.config['routing_keys'].each do |routing_key|
          queue.bind(exchange, routing_key: routing_key)
        end

        result = OpenStruct.new

        consume_thread = Thread.new do
          queue.subscribe(block: true) do |_delivery_info, properties, body|
            result.body = body
            result.correlation_id = properties[:correlation_id]
            result.reply_to = properties[:reply_to]
          end
        end

        @threads << consume_thread

        Thread.new do
          sleep(params.config['timeout'] || 10)
          Thread.kill(consume_thread)
        end

        @result = result
      end

      def publish &block
        params = PublishActionParams.new(@config, @logger)
        params.instance_eval(&block)

        connect

        channel = @conn.create_channel

        exchange = Bunny::Exchange.new(
          channel,
          params.config['exchange']['type'].to_s,
          params.config['exchange']['name'],
          durable: params.config['exchange']['durable']
        )

        exchange.publish(
          params.config['body'],
          routing_key: params.config['routing_keys'].nil? ? nil : params.config['routing_keys'].first,
          correlation_id: params.config['correlation_id'],
          reply_to: params.config['reply_to']
        )
      end

      def await!
        @threads.each { |x| x.join }
      end

      private

      def connect
        return unless @conn.nil?

        @conn = Bunny.new(
          host: @config['host'],
          ssl: @config['ssl'],
          username: @config['username'],
          password: @config['password'],
          virtual_host: @config['virtual_host']
        )

        @conn.start
      end
    end

    class << self
      @@config = {}

      def rabbitmq name, &block
        if @@config.key? name
          config = @@config[name]
        else
          config = {
            'host' => name,
          }
        end

        action = RabbitMQAction.new(config, @@logger)
        action._evaluate(&block) if block_given?

        # Wait for all consumer threads to be finished
        action.threads.each { |x| x.join }

        action.conn.close
      end
    end

    Spectre.register do |config|
      @@logger = Spectre::Logging::ModuleLogger.new(config, 'spectre/rabbitmq')

      if config.key? 'rabbitmq'
        config['rabbitmq'].each do |name, cfg|
          @@config[name] = cfg
        end
      end
    end

    Spectre.delegate :rabbitmq, to: self
  end
end
