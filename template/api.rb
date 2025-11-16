ARGS = ARGV.join(" ").scan(/--?([^=\s]+)\s*(?:=?([^\s-]+))?/).to_h

def source_paths
  [*super, __dir__]
end

require_relative "../lib/base"

# Ensure Ruby version is 3.4+ (this template is optimized for Ruby 3.4)
# Use current Ruby version if 3.4+, otherwise default to 3.4.0
ruby_version = Gem::Version.new(RUBY_VERSION)
required_version = Gem::Version.new("3.4.0")

if ruby_version < required_version
  say "Warning: This template is optimized for Ruby 3.4+", :yellow
  say "   Current Ruby version: #{RUBY_VERSION}", :yellow
  say "   Please consider upgrading to Ruby 3.4 or later", :yellow
end

# Use mise.toml for version management instead of .ruby-version
remove_file ".ruby-version"
template from_files("mise.toml"), "mise.toml"

# Replace default .gitignore with enhanced version
remove_file ".gitignore"
copy_file from_files(".gitignore_template"), ".gitignore"

# Add .gitattributes for Git configuration
copy_file from_files(".gitattributes"), ".gitattributes"

# Replace Rails 8 default .rubocop.yml with custom configuration
remove_file ".rubocop.yml"
copy_file from_files(".rubocop.yml"), ".rubocop.yml"

# Add .dockerignore for Docker deployments
# Rails 8.1+ creates .dockerignore by default, so we need to remove it first
remove_file ".dockerignore"
copy_file from_files(".dockerignore_template"), ".dockerignore"

# Add Docker compose templates
# compose.yaml: Development environment (default)
# compose.prod.yaml: Production environment
# compose.test.yaml: Test environment
copy_file from_files("compose.yaml"), "compose.yaml"
copy_file from_files("compose.prod.yaml"), "compose.prod.yaml"
copy_file from_files("compose.test.yaml"), "compose.test.yaml"

# Add Dockerfile template
# Rails 8.1+ creates Dockerfile by default, so we need to remove it first
remove_file "Dockerfile"
copy_file from_files("Dockerfile"), "Dockerfile"

# Add Docker entrypoint script (Rails 8.1+ convention: bin/docker-entrypoint)
# Rails 8.1+ creates bin/docker-entrypoint by default, so we need to remove it first
remove_file "bin/docker-entrypoint"
copy_file from_files("docker-entrypoint.sh"), "bin/docker-entrypoint"
chmod "bin/docker-entrypoint", 0o755

# Add custom bin scripts
copy_file from_files("bin/jobs"), "bin/jobs"
copy_file from_files("bin/deploy"), "bin/deploy"
chmod "bin/jobs", 0o755
chmod "bin/deploy", 0o755

# Add .env.example for environment configuration
copy_file from_files(".env.example"), ".env.example"

# Create .secrets directory for Docker secrets with proper permissions
directory from_files(".secrets"), ".secrets"

# Set secure permissions for .secrets directory
# 700: Only owner can read/write/execute (prevents other users from listing)
# This is required for Docker Compose to properly mount secrets
after_bundle do
  # Ensure bundler setup is complete before any generators run
  # This prevents LoadError when initializers are loaded during generator execution
  Bundler.setup

  run "chmod 700 .secrets" if File.directory?(".secrets")

  # Set 640 permissions for secret files (owner: rw, group: r, others: none)
  # This allows Docker daemon (usually in docker group) to read secrets
  # while preventing unauthorized access
  Dir.glob(".secrets/*").each do |file|
    next if File.basename(file).end_with?(".example", ".gitkeep")

    run "chmod 640 #{file}" if File.file?(file)
  end
end

# Configure Active Job queue adapters
# Development and production use Sidekiq (configured in recipe/sidekiq.rb)
# Test environment uses :test adapter for immediate execution
environment "config.active_job.queue_adapter = :sidekiq", env: "development"
environment "config.active_job.queue_adapter = :sidekiq", env: "production"
environment "config.active_job.queue_adapter = :test", env: "test"

# Core recipes (gems with installation and configuration)
recipe "aasm"
recipe "alba"
recipe "bcrypt"
recipe "benchmark"
recipe "config"
recipe "jwt"
recipe "pagy"
recipe "pundit"
recipe "rack_attack"
recipe "redis"
recipe "sidekiq"
recipe "rspec"
recipe "pg_query"
recipe "rubocop"
recipe "sentry"

# Configuration recipes (environment-specific settings)
recipe "config/action_mailer"
recipe "config/cors"
recipe "config/log"
recipe "config/puma"
recipe "config/time_zone"

# Application-wide configuration (all environments)
environment <<~RUBY
  # Silence healthcheck logs
  config.silence_healthcheck_path = "/up"

  # Allow additional hosts from environment variable
  # Configure via ALLOWED_HOSTS env var (comma-separated)
  # Example: ALLOWED_HOSTS="example.com,test.example.com,dev.example.com"
  # Useful for Cloudflare Tunnel, ngrok, or custom domains
  allowed_hosts = ENV.fetch("ALLOWED_HOSTS", "").split(",").map(&:strip).reject(&:empty?)
  allowed_hosts.each { |host| config.hosts << host } unless allowed_hosts.empty?
RUBY

recipe "database_yml"

# Use SQL schema format to preserve PostgreSQL-specific features
# (sequences, views, functions, etc.)
environment "config.active_record.schema_format = :sql"

# Create empty structure.sql file for primary database
after_bundle do
  create_file "db/structure.sql", "-- PostgreSQL database schema\n"
end

recipe "uuidv7"
recipe "action_storage"

# Set up basic route structure
# Health check endpoint at root level (outside API scope)
route 'get "up" => "rails/health#show", as: :health_check'

# Create API scope for all API endpoints
inject_into_file "config/routes.rb", after: "Rails.application.routes.draw do\n" do
  <<~RUBY
    scope path: "/api", as: "api" do
      # API routes go here
    end

  RUBY
end

recipe "action_cable"
recipe "openapi_doc"
# recipe "google-cloud-storage"

# Replace default README.md with comprehensive setup guide
remove_file "README.md"
copy_file from_files("README.md"), "README.md"

# Execute all after_generators callbacks registered by recipes
# This runs after all generators complete to ensure gems are loaded
after_bundle do
  run_after_generators
end

# Auto-fix code style issues with RuboCop after bundle install
# This ensures the generated project follows RuboCop style guidelines
after_bundle do
  say "Running RuboCop auto-corrections..."
  run "bundle exec rubocop -A"
end
