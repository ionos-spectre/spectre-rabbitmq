require 'bunny'

require_relative '../lib/spectre/rabbitmq'

RSpec.describe 'spectre/http' do
  before do
    conn = double('Connection')
    channel = double('Channel')
    exchange = double('Exchange')
    queue = double('Queue')

    @correlation_id = 'some_correlation_id'
    @reply_to = 'reply_to_this'

    allow(conn).to receive(:start)
    allow(conn).to receive(:close)

    allow(Bunny::Exchange).to receive(:new)
      .with(channel, 'topic', 'hello', durable: true, auto_delete: false)
      .and_return(exchange)

    allow(exchange).to receive(:publish)
      .with('some data', correlation_id: @correlation_id, reply_to: 'reply_to_this', routing_key: 'sample_key')

    allow(queue).to receive(:bind)
      .with(exchange, routing_key: 'sample_key')

    allow(queue).to receive(:bind)
      .with(exchange, routing_key: 'sample_key_2')

    allow(queue).to receive(:subscribe) { |&block| block.call(nil, { correlation_id: @correlation_id, reply_to: @reply_to }, 'some data') }
      .with(block: true)

    allow(channel).to receive(:queue)
      .with('hello_queue', durable: false, auto_delete: false)
      .and_return(queue)

    allow(conn).to receive(:create_channel).and_return(channel)

    allow(Bunny).to receive(:new)
      .with(host: 'localhost', ssl: false, username: 'developer', password: 'dev', virtual_host: '/')
      .and_return(conn)

    Spectre.configure({
      'rabbitmq' => {
        'sample' => {
          'host' => 'localhost',
          'username' => 'developer',
          'password' => 'dev',
          'virtual_host' => '/',
        },
      },
    })
  end

  it 'publish and consume a rabbitmq message' do
    corr_id = @correlation_id
    reply = @reply_to

    Spectre::RabbitMQ.rabbitmq 'sample' do
      # host 'localhost'
      username 'developer'
      password 'dev'
      # use_ssl!
      virtual_host '/'

      consume do
        exchange 'hello', type: 'topic', durable: true
        queue 'hello_queue'
        routing_keys 'sample_key', 'sample_key_2'
        timeout 3
      end

      publish do
        topic 'hello', durable: true
        routing_key 'sample_key'
        body 'some data'
        correlation_id corr_id
        reply_to reply
      end

      await!

      expect(result.body).to eq('some data')
      expect(result.correlation_id).to eq(corr_id)
      expect(result.reply_to).to eq(reply)
    end
  end
end
