describe 'spectre/rabbitmq' do
  it 'does consume rabbitmq queues', tags: [:sample, :rabbitmq] do
    log 'connect to rabbitmq'

    rabbitmq 'sample' do
      # host 'localhost'
      username 'developer'
      password 'dev'
      # use_ssl!
      virtual_host '/'

      log 'start consuming messages'

      consume do
        exchange 'hello', type: 'topic', durable: true
        queue 'hello_queue'
        routing_keys 'sample_key', 'sample_key_2'
        timeout 3
      end

      log 'publish one message'

      publish do
        topic 'hello', durable: true
        payload 'some data'
        routing_key 'sample_key'
      end

      await!

      expect 'a specific message' do
        result.body.should_be 'some data'
      end
    end
  end
end
