## About CKB
CKB is the layer 1 of Nervos Network, a public/permissionless blockchain. CKB uses [Proof of Work](https://en.wikipedia.org/wiki/Proof-of-work_system) and [improved Nakamoto concensus](https://medium.com/nervosnetwork/breaking-the-throughput-limit-of-nakamoto-consensus-ccdf65fe0832) to achieve maximized performance on average hardware and internet condition, without sacrificing decentralization and security which are the core value of blockchain.

# CKB Explorer
CKB Explorer is a [Nervos CKB](https://github.com/nervosnetwork/ckb) blockchain explorer built with React and Ruby on Rails.

It supports searching block, transaction, address and includes two parts: [frontend](https://github.com/nervosnetwork/ckb-explorer-frontend)
and [backend server](https://github.com/nervosnetwork/ckb-explorer) (this project).

# CKB Explorer Server
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/nervosnetwork/ckb-explorer/blob/develop/COPYING)
[![TravisCI](https://travis-ci.com/nervosnetwork/ckb-explorer.svg?branch=develop)](https://travis-ci.com/nervosnetwork/ckb-explorer)
[![Codecov](https://codecov.io/gh/nervosnetwork/ckb-explorer/branch/master/graph/badge.svg)](https://codecov.io/gh/nervosnetwork/ckb-explorer/branch/master)
[![Discord](https://img.shields.io/discord/956765352514183188?label=Discord&logo=discord&style=default&color=grey&labelColor=5865F2&logoColor=white)](https://discord.gg/RsyKyejxAW)

A blockchain explorer service of [Nervos CKB](https://github.com/nervosnetwork/ckb).

## Prerequisites

- [PostgreSQL](https://www.postgresql.org/) 14.3
- [Redis](https://redis.io/) 6+
- [libsodium](https://libsodium.gitbook.io/doc/installation)
- [secp256k1](https://github.com/bitcoin-core/secp256k1.git)

## Initial Project

```shell
$ cd ckb-explorer/
$ cp .env.example .env # (in this config file, please modify the items according to your local environment)
$ touch .env.local # (overwrite `.env` config if you need in `.env.local`, such as DB_USERNAME, DB_PASSWORD...)
$ touch config/settings.local.yml # (overwrite `config/settings.yml` to config available hosts)
$ bin/setup
```

## Create & Setup database

```shell
bundle exec rake db:create                 # (create db for development and test)
bundle exec rake db:migrate                # (run migration for development db)
bundle exec rake db:migrate RAILS_ENV=test # (run migration for test db)
```

## Running Test

```shell
$ bundle exec rails test
```

## Run Project

```shell
$ bundle exec rails s

# start sync process
$ ruby lib/ckb_block_node_processor.rb
```

## Deploy

We suggest using [Docker Compose](https://docs.docker.com/compose/gettingstarted/) to deploy the CKB Explorer Service.

### Build Docker Image

```shell
$ docker compose build .
```

### Start Services

The service is composed of 4 processes:

- web: for serving the API
- worker: for processing background job
- blocksyncer: for synchronizing the data from CKB chain
- scheduler: for scheduling some timer tasks

You can see these processes in the `Procfile` file.
The `web` & `worker` process can be scaled horizontally. And the blocksyncer and scheduler process are both singleton,
so you can only start one instance for each process.

```shell
$ docker compose up -d
```

## How to Contribute
CKB Explorer Server is an open source project and your contribution is very much appreciated. Please check out
[CONTRIBUTING.md](CONTRIBUTING.md) for guidelines about how to proceed.

## API Documentation
Please see this [Documentation](https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html).

## License

CKB Explorer is released under the terms of the MIT license. See [COPYING](COPYING) for more information or see
[https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT).

