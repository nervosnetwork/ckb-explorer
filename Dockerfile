ARG RUBY_VERSION=3.1.2
FROM ruby:$RUBY_VERSION
LABEL MAINTAINER Nervos Network
RUN apt-get update && apt-get install -y  build-essential \
  git libpq-dev libcurl4 libjemalloc2 \
  libsecp256k1-dev  libsodium-dev
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
# --registry=https://registry.npm.taobao.org
# RUN gem sources --add https://gems.ruby-china.com/ --remove https://rubygems.org/ && \
WORKDIR /usr/src/
ARG RAILS_ENV=production
ARG BUNDLER_VERSION=2.3.25
ENV RAILS_ENV=$RAILS_ENV
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true

RUN echo ${BUNDLER_VERSION}
RUN gem i -N bundler:${BUNDLER_VERSION} foreman
RUN bundle config --global frozen 1 && \
  bundle config without 'development:test' && \
  bundle config set --local path 'vendor/bundle' && \
  # bundle config mirror.https://rubygems.org https://gems.ruby-china.com && \
  bundle config deployment true
COPY Gemfile* ./
RUN bundle install -j4 --retry 3 && rm -rf vendor/cache
ADD . /usr/src/
