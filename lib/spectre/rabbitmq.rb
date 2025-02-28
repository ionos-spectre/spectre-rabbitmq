require 'logger'
require 'ostruct'
require 'bunny'

module Spectre
  module RabbitMQ
    PROGNAME = 'spectre/rabbitmq'

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

      def queue name = '', exclusive: false, durable: false, auto_delete: false
        @config['queue'] = {
          'name' => name,
          'durable' => durable,
          'auto_delete' => auto_delete,
          'exclusive' => exclusive,
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
        @config['port'] = @config['port'] || 5672
      end

      def action name
        raise "invalid action '#{name}'" unless ['publish', 'subscribe'].include? name

        @config['action'] = name
      end

      def host hostname
        @config['host'] = hostname
      end

      def port portnum
        @config['port'] = portnum
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
          auto_delete: params.config['queue']['auto_delete'],
          exclusive: params.config['queue']['exclusive']
        )

        @logger.log(Logger::Severity::INFO,
                    "declare queue name=#{queue.name} " \
                    "durable=#{params.config['queue']['durable']} " \
                    "exclusive=#{params.config['queue']['exclusive']} " \
                    "auto_delete=#{params.config['queue']['auto_delete']}",
                    PROGNAME)

        params.config['routing_keys'].each do |routing_key|
          queue.bind(exchange, routing_key:)

          @logger.log(
            Logger::Severity::INFO,
            "bind exchange=#{exchange.name} queue=#{queue.name} routing_key=#{routing_key}",
            PROGNAME
          )
        end

        consumer_thread = Thread.new do
          queue.subscribe(block: true) do |delivery_info, properties, payload|
            message = OpenStruct.new
            message.payload = payload
            message.correlation_id = properties[:correlation_id]
            message.reply_to = properties[:reply_to]
            message.freeze

            log_msg = "get queue=#{queue.name}" \
                      "\ncorrelation_id: #{message.correlation_id}" \
                      "\nreply_to: #{message.reply_to}"

            log_msg = "\n#{message.payload}" if params.config['log_payload']

            @logger.log(Logger::Severity::INFO, log_msg, PROGNAME)

            @messages << message

            delivery_info.consumer.cancel if @messages.count >= (params.config['messages'] || 1)
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

        log_msg = "publish exchange=#{params.config['exchange']['name']} " \
                  "routing_key=#{routing_key}"

        log_msg += "\n#{params.config['payload']}" if params.config['log_payload']

        @logger.log(Logger::Severity::INFO, log_msg, PROGNAME)
      end

      def await!
        @threads.each(&:join)
      end

      private

      def connect
        return unless @conn.nil?

        @logger.log(Logger::Severity::INFO,
                    "connect #{@config['username']}:*****@#{@config['host']}/#{@config['virtual_host']} " \
                    "ssl=#{@config['ssl']}",
                    PROGNAME)

        @conn = Bunny.new(
          host: @config['host'],
          port: @config['port'],
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

        @logger.log(Logger::Severity::INFO,
                    "declare exchange name=#{exchange.name} type=#{exchange.type} " \
                    "durable=#{params.config['exchange']['durable']} " \
                    "auto_delete=#{params.config['exchange']['auto_delete']}",
                    PROGNAME)

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
