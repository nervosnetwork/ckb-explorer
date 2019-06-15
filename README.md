# CKB Explorer
CKB Explorer is a [Nervos CKB](https://github.com/nervosnetwork/ckb) blockchain explorer built with React and Ruby on Rails.

It supports searching block, transaction, address and includes two parts: [frontend](https://github.com/nervosnetwork/ckb-explorer-frontend) and [backend server](https://github.com/nervosnetwork/ckb-explorer).

# CKB Explorer Server
[![TravisCI](https://travis-ci.com/nervosnetwork/ckb-explorer.svg?branch=develop)](https://travis-ci.com/nervosnetwork/ckb-explorer)

A blockchain explorer cache server of [Nervos CKB](https://github.com/nervosnetwork/ckb).

## Prerequisites

- [postgresql](https://www.postgresql.org/) 9.4 and above
- install secp256k1 (see [secp256k1](https://github.com/bitcoin-core/secp256k1.git) for more info)

```shell
  $ git clone https://github.com/bitcoin-core/secp256k1.git && cd secp256k1 && ./autogen.sh && ./configure --enable-module-recovery --enable-experimental --enable-module-ecdh && make && sudo make install && cd ..
```

## Initial Project

```shell
$ cd ckb-explorer/
$ touch .env.local (overwrite `.env` config if you need in `.env.local`, such as DB_USERNAME, DB_PASSWORD...)
$ touch config/settings.local.yml (overwrite `config/settings.yml` to config available hosts)
$ bin/setup
```

## Running Test

```shell
$ bundle exec rails test
```

## Run Project

```shell
$ bundle exec rails s

# start sync process
$ ruby lib/ckb_inauthentic_sync.rb

# start validator process
$ ruby lib/ckb_authentic_sync.rb

# strat ckb transaction info and fee process
$ ruby lib/ckb_transaction_info_and_fee_updater.rb
```

## Deploy

You can deploy this via [mina](https://github.com/mina-deploy/mina)

```shell
$ mina setup
$ mina staging deploy
```

## License

CKB Explorer is released under the terms of the MIT license. See [COPYING](COPYING) for more information or see [https://opensource.org/licenses/MIT](https://opensource.org/licenses/MIT).


