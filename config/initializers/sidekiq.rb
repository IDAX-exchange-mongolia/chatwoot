require Rails.root.join('lib/redis/config')

schedule_file = 'config/schedule.yml'

Sidekiq.configure_client do |config|
  config.redis = Redis::Config.app
end

# Logs whenever a job is pulled off Redis for execution.
class ChatwootDequeuedLogger
  def call(_worker, job, queue)
    payload = job['args'].first
    Sidekiq.logger.info("Dequeued #{job['wrapped']} #{payload['job_id']} from #{queue}")
    yield
  end
end

Sidekiq.configure_server do |config|
  config.redis = Redis::Config.app

  config.server_middleware do |chain|
    chain.add ChatwootDequeuedLogger
  end

  # skip the default start stop logging
  if Rails.env.production?
    config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
    config[:skip_default_job_logging] = true
    config.logger.level = Logger.const_get(ENV.fetch('LOG_LEVEL', 'info').upcase.to_s)
  end
end

# https://github.com/ondrejbartas/sidekiq-cron
Rails.application.reloader.to_prepare do
  Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file) if File.exist?(schedule_file) && Sidekiq.server?
end
