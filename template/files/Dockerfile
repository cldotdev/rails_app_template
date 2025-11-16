# syntax=docker/dockerfile:1
# check=error=true

# Use Debian slim for better jemalloc compatibility and memory optimization
# Note: Alpine + jemalloc can cause segfaults due to musl libc incompatibility
FROM docker.io/library/ruby:3.4.7-slim-trixie AS base

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips libpq5 postgresql-client procps && \
    ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ARG RAILS_ENV="production"
ARG BUNDLE_DEPLOYMENT="true"
ARG BUNDLE_WITHOUT="development:test"
ARG APP_VERSION
ARG APP_REVISION

# Enable jemalloc for reduced memory usage and latency
# YJIT enabled for 15-20% performance improvement
# frozen-string-literal for memory optimization
ENV RAILS_ENV=${RAILS_ENV} \
    BUNDLE_DEPLOYMENT=${BUNDLE_DEPLOYMENT} \
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    BUNDLE_PATH="/usr/local/bundle" \
    RUBY_YJIT_ENABLE="1" \
    RUBYOPT="--enable-frozen-string-literal" \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    APP_VERSION=${APP_VERSION} \
    APP_REVISION=${APP_REVISION} \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
    MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# ARG GITLAB_HOST="gitlab.com"

# Configure git credentials for private repositories (optional)
# This allows bundler to fetch gems from private GitHub/GitLab repositories
# RUN --mount=type=secret,id=github_pat \
#     --mount=type=secret,id=gitlab_pat \
#   git config --global credential.helper store && \
#   # GitHub configuration
#   if [ -f "/run/secrets/github_pat" ]; then \
#     git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" && \
#     git config --global --add url."https://github.com/".insteadOf "git@github.com:" && \
#     git config --global --add url."https://github.com/".insteadOf "git+ssh://git@github.com/" && \
#     GIT_TOKEN=$(cat /run/secrets/github_pat) && \
#     echo "https://token:${GIT_TOKEN}@github.com" >> ~/.git-credentials; \
#   fi && \
#   # GitLab configuration (supports custom host)
#   if [ -f "/run/secrets/gitlab_pat" ]; then \
#     git config --global url."https://${GITLAB_HOST}/".insteadOf "ssh://git@${GITLAB_HOST}/" && \
#     git config --global --add url."https://${GITLAB_HOST}/".insteadOf "git@${GITLAB_HOST}:" && \
#     git config --global --add url."https://${GITLAB_HOST}/".insteadOf "git+ssh://git@${GITLAB_HOST}/" && \
#     GIT_TOKEN=$(cat /run/secrets/gitlab_pat) && \
#     echo "https://oauth2:${GIT_TOKEN}@${GITLAB_HOST}" >> ~/.git-credentials; \
#   fi && \
#   # Set secure permissions if credentials file exists
#   if [ -f ~/.git-credentials ]; then chmod 600 ~/.git-credentials; fi

COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    rm -f ~/.git-credentials && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Final stage for app image
FROM base

ARG APP_VERSION
ARG APP_REVISION

LABEL version=$APP_VERSION
LABEL revision=$APP_REVISION

ARG APP_UID=1000
ARG APP_GID=1000
RUN groupadd --system --gid ${APP_GID} rails && \
    useradd rails --uid ${APP_UID} --gid ${APP_GID} --create-home --shell /bin/bash
USER ${APP_UID}:${APP_GID}

# Copy built artifacts: gems, application
COPY --chown=rails:rails --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=rails:rails --from=build /rails /rails

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Puma by default (or use Thruster for HTTP/2 support)
# Thruster: Expose port 80, CMD ["./bin/thrust", "./bin/rails", "server"]
# Puma: Expose port 3000, CMD ["./bin/rails", "server"]
EXPOSE 3000
CMD ["./bin/rails", "server"]
