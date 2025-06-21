# syntax=docker/dockerfile:1
ARG CACHE_BREAKER=1
ARG RUBY_VERSION=3.2.2

# 1) Base image
FROM ruby:${RUBY_VERSION}-slim AS base
WORKDIR /rails
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl \
      libjemalloc2 \
      libvips \
      sqlite3 \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development

# 2) Build stage
FROM base AS build
ARG CACHE_BREAKER
RUN echo "cache: $CACHE_BREAKER"
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      pkg-config \
      libpq-dev \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock ./
RUN bundle install
RUN bundle exec bootsnap precompile --gemfile

COPY . .
RUN bundle exec bootsnap precompile app/ lib/
RUN SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile

# 3) Final runtime image
FROM base
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd --uid 1000 --gid rails --create-home --shell /bin/bash rails && \
    chown -R rails:rails /rails/db /rails/log /rails/storage /rails/tmp

USER rails
ENTRYPOINT ["/rails/bin/docker-entrypoint"]
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
