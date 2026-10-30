# Insert templates here

unless defined?(Avo) && defined?(Webhukhs::ReceivedWebhook)
  abort "Install Avo and Webhukhs, then run webhukhs:install and db:migrate before applying this blueprint."
end

files.each do |path, contents|
  file path, contents
end

say "Webhukhs is ready at your Avo mount path under /resources/webhukhs_received_webhooks."
say "Keep Avo behind admin authentication. Webhook bodies and headers may contain secrets."
