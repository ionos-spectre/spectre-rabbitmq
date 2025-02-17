require 'logger'
require 'ostruct'
require 'bunny'

module Spectre
  module RabbitMQ
    class ActionParamsBase
      include Spectre::Delegate if defined? Spectre::Delegate

      attr_reader :config

      def initialize config, logger
        @logger = logger
        @config = Marshal.load(Marshal.dump(config))
        @config['routing_keys'] = []
        @config['log_payload'] = true
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
        exchange(name, type: 'topic', durable:, auto_delete:)
      end

      def routing_keys *names
        @config['routing_keys'] = names
      end

      def routing_key name
        @config['routing_keys'] << name
      end

      def no_log!
        @config['log_payload'] = false
      end
    end

    class ConsumeActionParams < ActionParamsBase
      def initialize config, logger
        super

        @config['queue'] = {
          'name' => nil,
          'durable' => false,
          'auto_delete' => false,
        }

        @config['messages'] = 1
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

      def messages count
        @config['messages'] = count
      end
    end

    class PublishActionParams < ActionParamsBase
      def payload data
        @config['payload'] = data
      end

      def correlation_id id
        @config['correlation_id'] = id
      end

      def reply_to receiver
        @config['reply_to'] = receiver
      end

      alias body payload
    end

    class RabbitMQAction
      include Spectre::Delegate if defined? Spectre::Delegate

      attr_reader :conn, :threads, :messages

      def initialize config, logger
        @logger = logger
        @config = config
        @conn = nil

        @threads = []
        @messages = []

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

      def consume(&)
        params = ConsumeActionParams.new(@config, @logger)
        params.instance_eval(&)

        connect

        channel = @conn.create_channel

        exchange = declare_exchange(channel, params)

        queue = channel.queue(
          params.config['queue']['name'],
          durable: params.config['queue']['durable'],
          auto_delete: params.config['queue']['auto_delete']
        )

        @logger.info(
          "declare queue name=#{queue.name} \
          durable=#{params.config['queue']['durable']} \
          auto_delete=#{params.config['queue']['auto_delete']}"
        )

        params.config['routing_keys'].each do |routing_key|
          queue.bind(exchange, routing_key:)
          @logger.info("bind exchange=#{exchange.name} queue=#{queue.name} routing_key=#{routing_key}")
        end

        consumer_thread = Thread.new do
          message_queue = Queue.new

          queue.subscribe(block: true) do |_delivery_info, properties, payload|
            message = OpenStruct.new
            message.payload = payload
            message.correlation_id = properties[:correlation_id]
            message.reply_to = properties[:reply_to]
            message.freeze

            message_queue << message
          end

          while @messages.count < params.config['messages']
            message = message_queue.pop

            log_msg = "get queue=#{queue.name}\n\
                      correlation_id: #{message.correlation_id}\n\
                      reply_to: #{message.reply_to}"

            log_msg = "\n#{message.payload}" if params.config['log_payload']

            @logger.info(log_msg)

            @messages << message
          end
        end

        @threads << consumer_thread

        Thread.new do
          sleep(params.config['timeout'] || 10)
          consumer_thread.exit
        end
      end

      def publish(&)
        params = PublishActionParams.new(@config, @logger)
        params.instance_eval(&)

        connect

        channel = @conn.create_channel

        exchange = declare_exchange(channel, params)

        routing_key = params.config['routing_keys']&.first

        exchange.publish(
          params.config['payload'],
          routing_key:,
          correlation_id: params.config['correlation_id'],
          reply_to: params.config['reply_to']
        )

        log_msg = "publish exchange=#{params.config['exchange']['name']} \
                   routing_key=#{routing_key}"

        log_msg += "\n#{params.config['payload']}" if params.config['log_payload']

        @logger.info(log_msg)
      end

      def await!
        @threads.each(&:join)
      end

      private

      def connect
        return unless @conn.nil?

        @logger.info(
          "connect #{@config['username']}:*****@#{@config['host']}\
          #{@config['virtual_host']} ssl=#{@config['ssl']}"
        )

        @conn = Bunny.new(
          host: @config['host'],
          ssl: @config['ssl'],
          username: @config['username'],
          password: @config['password'],
          virtual_host: @config['virtual_host']
        )

        @conn.start
      end

      def declare_exchange(channel, params)
        exchange = Bunny::Exchange.new(
          channel,
          params.config['exchange']['type'].to_s,
          params.config['exchange']['name'],
          durable: params.config['exchange']['durable'],
          auto_delete: params.config['exchange']['auto_delete']
        )

        @logger.info(
          "declare exchange name=#{exchange.name} type=#{exchange.type} \
          durable=#{params.config['exchange']['durable']} \
          auto_delete=#{params.config['exchange']['auto_delete']}"
        )

        exchange
      end
    end

    class Client
      include Spectre::Delegate if defined? Spectre::Delegate

      def initialize config, logger
        @config = config['rabbitmq'] || {}
        @logger = logger
      end

      def rabbitmq(name, &)
        config = @config[name] || {'host' => name }

        action = RabbitMQAction.new(config, @logger)
        action.instance_eval(&) if block_given?

        # Wait for all consumer threads to be finished
        action.threads.each(&:join)

        action.conn.close
      end
    end
  end

  Engine.register(RabbitMQ::Client, :rabbitmq) if defined? Engine
end
