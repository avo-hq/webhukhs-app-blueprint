class Avo::WebhukhsReceivedWebhooksController < Avo::ResourcesController
  prepend_before_action :require_read_only_request

  private

  def require_read_only_request
    head :forbidden unless request.get? && action_name.in?(["index", "show"])
  end
end
