FROM ruby:2.5.3
RUN apt-get update -qq && apt-get install -y build-essential libsodium-dev libpq-dev nodejs git \
    && apt-get clean autoclean \
    && apt-get autoremove -y \
    && rm -rf \
        /var/lib/apt \
        /var/lib/dpkg \
        /var/lib/cache \
        /var/lib/log


RUN mkdir /secp256k1
WORKDIR /secp256k1
RUN git clone https://github.com/bitcoin-core/secp256k1.git . && ./autogen.sh && ./configure --enable-module-recovery && make && make install

# Set an environment variable where the Rails app is installed to inside of Docker image
ENV RAILS_ROOT /ckb-explorer/app
RUN mkdir -p $RAILS_ROOT
# Set working directory
WORKDIR $RAILS_ROOT
RUN gem install bundler

# Setting env up
ENV RAILS_ENV='production'
ENV RACK_ENV='production'
# Adding gems
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN bundle install --jobs 20 --retry 5 --without development test
# Adding project files
COPY . .

EXPOSE 3000