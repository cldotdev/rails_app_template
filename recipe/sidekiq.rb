# Install Sidekiq for background job processing
# Version 7.0+ recommended for modern Rails applications
gem "sidekiq", ">= 7.0"

# Create Sidekiq configuration file
after_bundle do
  create_file "config/sidekiq.yml", <<~YAML
    # Sidekiq Configuration
    # See: https://github.com/sidekiq/sidekiq/wiki/Advanced-Options

    # Global configuration
    :max_retries: 5
    :timeout: 30

    # Queues with priorities (higher number = higher priority)
    :queues:
      - [critical, 10]
      - [default, 5]
      - [low, 1]

    # Production settings (override in production environment)
    production:
      :concurrency: <%= ENV.fetch("APP_SIDEKIQ_CONCURRENCY", 10) %>

    # Development settings
    development:
      :concurrency: <%= ENV.fetch("APP_SIDEKIQ_CONCURRENCY", 2) %>

    # Test settings (test environment uses :test adapter)
    test:
      :concurrency: 1
  YAML
end

# Create Sidekiq initializer
initializer "sidekiq.rb", <<~RUBY
  # Sidekiq Initializer
  # Configure Sidekiq to use dedicated Valkey queue instance

  # Skip Sidekiq initialization in test environment
  # Test environment uses :test adapter (configured in config/environments/test.rb)
  return if Rails.env.test?

  # Wait for AppConfig to be available
  Rails.application.config.after_initialize do
    # Use dedicated Valkey queue instance for Sidekiq
    # - noeviction policy: prevents job loss due to memory pressure
    # - AOF persistence: ensures jobs survive Valkey restarts
    redis_config = {
      url:             "redis://\#{AppConfig.instance.redis_queue_host}:\#{AppConfig.instance.redis_queue_port}/0",
      password:        AppConfig.instance.redis_queue_password,
      # Network timeout in seconds
      network_timeout: 5,
      # Connection pool configuration
      # Sidekiq server needs larger pool for concurrent job processing
      # Sidekiq client needs smaller pool for enqueueing jobs
      pool_timeout:    5
    }

    Sidekiq.configure_server do |config|
      # Server (worker) configuration
      config.redis = redis_config.merge(
        # Pool size should be >= concurrency + 2 for internal threads
        size: (ENV.fetch("APP_SIDEKIQ_CONCURRENCY", 10).to_i + 5)
      )

      # Enable periodic job metrics logging
      config.average_scheduled_poll_interval = 15

      # Error handling
      config.error_handlers << lambda { |exception, context|
        # Log to Rails logger
        Rails.logger.error("Sidekiq error: \#{exception.class} - \#{exception.message}")
        Rails.logger.error(exception.backtrace.join("\\n"))

        # Report to Sentry if configured (Sentry.init in config/initializers/sentry.rb)
        # Context includes: job class, args, queue, retry_count, failed_at, etc.
        Sentry.capture_exception(exception, extra: context) if defined?(Sentry)
      }
    end

    Sidekiq.configure_client do |config|
      # Client (app) configuration for enqueueing jobs
      config.redis = redis_config.merge(
        # Client pool should match Rails thread pool size
        size: AppConfig.instance.rails_max_threads + 5
      )
    end
  end
RUBY
