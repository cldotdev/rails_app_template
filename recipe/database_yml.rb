# Replace sqlite3 with pg gem for PostgreSQL
gsub_file "Gemfile", /gem ['"]sqlite3['"].*$/, 'gem "pg"'

# Enhanced database.yml using AppConfig for unified configuration
database_yml_content = <<~YAML
  default: &default
    adapter: postgresql
    encoding: unicode
    # Connection pool size per worker process
    # Each Puma worker maintains its own pool
    # Total connections = WEB_CONCURRENCY × RAILS_MAX_THREADS
    # Ensure PostgreSQL max_connections ≥ total connections + buffer
    pool: <%= AppConfig.instance.rails_max_threads %>
    host: <%= AppConfig.instance.postgres_host %>
    port: <%= AppConfig.instance.postgres_port %>
    database: <%= AppConfig.instance.postgres_db %>
    username: <%= AppConfig.instance.postgres_user %>
    password: <%= AppConfig.instance.postgres_password %>

  development:
    primary:
      <<: *default

  test:
    primary:
      <<: *default

  production:
    primary:
      <<: *default
YAML

remove_file "config/database.yml"
create_file "config/database.yml", database_yml_content
