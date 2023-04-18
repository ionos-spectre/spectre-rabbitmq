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
    exchange 'hello', type: 'topic', durable: true
    queue 'hello_queue'
    routing_keys 'sample_key', 'sample_key_2'
  end

  publish do
    topic 'hello', durable: true
    body 'some data'
  end
end
```