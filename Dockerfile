ARG RUBY_VERSION=3.1.2
FROM ruby:$RUBY_VERSION as builder
LABEL MAINTAINER Nervos Network
RUN apt-get update && apt-get install -y  build-essential \
  git libpq-dev libcurl4 libjemalloc2 \
  libsecp256k1-dev  libsodium-dev
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
RUN gem update --system 3.3.22
WORKDIR /usr/src/
ARG RAILS_ENV=production
ARG BUNDLER_VERSION=2.3.25
ENV RAILS_ENV=$RAILS_ENV

RUN echo ${BUNDLER_VERSION}
RUN gem i -N bundler:${BUNDLER_VERSION} foreman
RUN bundle config --local frozen 1 && \
  bundle config --local without 'development:test' && \
  bundle config set --local path 'vendor/bundle' && \
  # bundle config mirror.https://rubygems.org https://gems.ruby-china.com && \
  bundle config --local deployment true
COPY Gemfile* ./
RUN bundle install -j4 --retry 3 && rm -rf vendor/cache
ADD . /usr/src/


FROM ruby:${RUBY_VERSION}-slim
RUN apt-get update && apt-get install -y \
  libpq5 libsodium23 curl \
  libcurl4 libjemalloc2 \
  && rm -rf /var/lib/apt/lists/*
RUN gem update --system 3.3.22
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
ARG BUNDLER_VERSION=2.2.32
RUN gem i -N bundler:$BUNDLER_VERSION foreman
EXPOSE 3000
WORKDIR /usr/src
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /usr/src /usr/src
ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true
