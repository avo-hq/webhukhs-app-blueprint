ENV["RAILS_ENV"] ||= "test"

require "bundler/setup"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "active_job/railtie"
require "propshaft"
require "avo"
require "webhukhs"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
APP_ROOT = File.join(ROOT, "tmp/app")
FileUtils.mkdir_p(File.join(APP_ROOT, "config"))
FileUtils.mkdir_p(File.join(APP_ROOT, "log"))

# Assemble the same files hash that HQ injects into template.rb.
files = Dir[File.join(ROOT, "template/**/*")].select { |path| File.file?(path) }.to_h do |path|
  [path.delete_prefix("#{ROOT}/template/"), File.read(path)]
end
template = File.read(File.join(ROOT, "template.rb")).sub("# Insert templates here\n", "files = #{files.inspect}\n")
template_path = File.join(ROOT, "tmp/blueprint.rb")
File.write(template_path, template)

require "rails/generators"
require "rails/generators/rails/app/app_generator"
Rails::Generators::AppGenerator.new([APP_ROOT], {skip_bundle: true, force: true}, destination_root: APP_ROOT).apply(template_path, verbose: false)

class BlueprintApp < Rails::Application
  config.root = APP_ROOT
  config.eager_load = false
  config.secret_key_base = "blueprint-test-secret-not-for-production"
  config.hosts.clear
  config.action_controller.allow_forgery_protection = false
  config.active_job.queue_adapter = :test
  config.logger = Logger.new(File::NULL)
  config.assets.paths << Avo::Engine.root.join("app/assets/builds")
end

File.write(File.join(APP_ROOT, "config/routes.rb"), <<~RUBY)
  Rails.application.routes.draw do
    mount_avo at: "/admin"
  end
RUBY

ENV["DATABASE_URL"] = "sqlite3:#{APP_ROOT}/webhooks.sqlite3"
Avo.configure do |config|
  config.root_path = "/admin"
  config.app_name = "Webhukhs"
end
BlueprintApp.initialize!

unless ActiveRecord::Base.connection.table_exists?(:received_webhooks)
  ActiveRecord::Schema.define do
    create_table :received_webhooks do |t|
      t.string :handler_event_id, null: false
      t.string :handler_module_name, null: false
      t.string :status, default: "received", null: false
      t.binary :body, null: false
      t.json :request_headers
      t.timestamps
    end
    add_index :received_webhooks, [:handler_module_name, :handler_event_id], unique: true
    add_index :received_webhooks, :status
  end
end
