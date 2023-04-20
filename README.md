# Spectre RabbitMQ

[![Build](https://github.com/ionos-spectre/spectre-rabbitmq/actions/workflows/build.yml/badge.svg)](https://github.com/ionos-spectre/spectre-rabbitmq/actions/workflows/build.yml)
[![Gem Version](https://badge.fury.io/rb/spectre-rabbitmq.svg)](https://badge.fury.io/rb/spectre-rabbitmq)

This is a [spectre](https://github.com/ionos-spectre/spectre-core) module which provides RabbitMQ functionality to the spectre framework.

## Install

```bash
$ sudo gem install spectre-rabbitmq
```

## Configure

Add the module to your `spectre.yml`

```yml
include:
 - spectre/rabbitmq
```

Configure some predefined SSH connection options in your environment file

```yml
rabbitmq:
  some_rabbitmq_conn:
    # action: publish
    host: 127.0.0.1
    port: 5672
    ssl: true
    username: guest
    password: guest
    virtual_host: /
    exchange:
      name: test
      durable: true
    queue:
      name: demo
      durable: true
    routing_key: some_routing_key
    body: somedata
```

## Usage

```ruby
rabbitmq 'sample' do
  # You can override values from the config here
  host 'localhost'
  username 'developer'
  password 'dev'
  use_ssl!
  virtual_host '/'

  # subscribes to the given queue and continues
  # This call blocks at the end of the `rabbitmq` block
  # This way, you can publish messages afterwards to this queue and wait for it
  consume do
    exchange 'hello', type: 'topic', durable: true, auto_delete: false
    # topic 'hello', durable: true

    queue 'hello_queue', durable: true, auto_delete: true
    routing_keys 'sample_key', 'sample_key_2'
    messages 5 # wait for 5 messages before canceling consumption
    timeout 3  # time to wait in seconds before canceling the consumption
  end

  5.times do
    publish do
      topic 'hello', durable: true
      payload 'some data'
      routing_key 'sample_key'
      correlation_id 'some_correlation_id_1234'
      reply_to 'reply_to_this'
    end
  end

  await!

  expect '5 messages' do
    messages.count.should_be 5
  end

  expect 'a specific message' do
    messages.first.payload.should_be 'some data'
    messages.first.correlation_id.should_not_be_empty
    messages.first.reply_to.should_be 'reply_to_this'
  end
end
```