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
        queue 'hello_queue', auto_delete: true
        routing_keys 'sample_key', 'sample_key_2'
        messages 3
        timeout 3
      end

      3.times do
        log 'publish message'

        publish do
          topic 'hello', durable: true
          payload 'some data'
          routing_key 'sample_key'
          correlation_id uuid
          reply_to 'reply_to_this'
        end
      end

      await!

      expect '3 messages' do
        messages.count.should_be 3
      end

      expect 'a specific message' do
        messages.first.payload.should_be 'some data'
        messages.first.correlation_id.should_not_be_empty
        messages.first.reply_to.should_be 'reply_to_this'
      end
    end
  end
end
