# Redis cleanup for test environment
RSpec.configure do |config|
  config.after do
    # Clean up Redis data after each test to ensure test isolation
    REDIS_SESSION.with(&:flushdb) if defined?(REDIS_SESSION)
    REDIS_CACHE.with(&:flushdb) if defined?(REDIS_CACHE)
  end
end
