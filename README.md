## About CKB
CKB is the layer 1 of Nervos Network, a public/permissionless blockchain. CKB uses [Proof of Work](https://en.wikipedia.org/wiki/Proof-of-work_system) and [improved Nakamoto concensus](https://medium.com/nervosnetwork/breaking-the-throughput-limit-of-nakamoto-consensus-ccdf65fe0832) to achieve maximized performance on average hardware and internet condition, without sacrificing decentralization and security which are the core value of blockchain.

# CKB Explorer
CKB Explorer is a [Nervos CKB](https://github.com/nervosnetwork/ckb) blockchain explorer built with React and Ruby on Rails.

It supports searching block, transaction, address and includes two parts: [frontend](https://github.com/nervosnetwork/ckb-explorer-frontend) and [backend server](https://github.com/nervosnetwork/ckb-explorer).

# CKB Explorer Server
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/nervosnetwork/ckb-explorer/blob/develop/COPYING)
[![TravisCI](https://travis-ci.com/nervosnetwork/ckb-explorer.svg?branch=develop)](https://travis-ci.com/nervosnetwork/ckb-explorer)
[![Codecov](https://codecov.io/gh/nervosnetwork/ckb-explorer/branch/master/graph/badge.svg)](https://codecov.io/gh/nervosnetwork/ckb-explorer/branch/master)
[![Discord](https://img.shields.io/discord/956765352514183188?label=Discord&logo=discord&style=default&color=grey&labelColor=5865F2&logoColor=white)](https://discord.gg/RsyKyejxAW)

A blockchain explorer cache server of [Nervos CKB](https://github.com/nervosnetwork/ckb).

## Prerequisites

- [PostgreSQL](https://www.postgresql.org/) 14.3
- [Redis](https://redis.io/) 6+
- [libsodium](https://libsodium.gitbook.io/doc/installation)
- [secp256k1](https://github.com/bitcoin-core/secp256k1.git)

```shell
$ git clone https://github.com/bitcoin-core/secp256k1.git && cd secp256k1 && ./autogen.sh && ./configure --enable-module-recovery --enable-experimental --enable-module-ecdh && make && sudo make install && cd ..
```

## Optional prerequisites
If you want to contribute to the API documentation you need to install [raml2html](https://github.com/raml2html/raml2html#raml2html) to generate HTML documentation.

## Initial Project

```shell
$ cd ckb-explorer/
$ cp .env.example .env (in this config file, please modify the items according to your local environment)
$ touch .env.local (overwrite `.env` config if you need in `.env.local`, such as DB_USERNAME, DB_PASSWORD...)
$ touch config/settings.local.yml (overwrite `config/settings.yml` to config available hosts)
$ bin/setup
```

## Create & Setup database

```shell

bundle exec rake db:create                 (create db for development and test )
bundle exec rake db:migrate                (run migration for development db)
bundle exec rake db:migrate RAILS_ENV=test (run migration for test db)
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

You can deploy this via [mina](https://github.com/mina-deploy/mina)

```shell
$ mina setup
$ mina staging deploy
```

## How to Contribute
CKB Explorer Server is an open source project and your contribution is very much appreciated. Please check out [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines about how to proceed.

## Build API Documentation
```shell
$ cd ckb-explorer
$ raml2html doc/api.raml > public/api_doc.html
```

## API Documentation
Please see this [Documentation](https://nervosnetwork.github.io/ckb-explorer/public/api_doc.html).

## License

CKB Explorer is released under the terms of the MIT license. See [COPYING](COPYING) for more information or see [https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT).



