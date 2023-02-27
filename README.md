# Spectre SSH

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
    host: some.server.com
    username: dummy
    password: '*****'
    virtual_host: /
```

## Usage
