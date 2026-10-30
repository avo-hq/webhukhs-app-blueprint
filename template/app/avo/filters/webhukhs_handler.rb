class Avo::Filters::WebhukhsHandler < Avo::Filters::SelectFilter
  self.name = "Handler"

  def apply(request, query, value)
    query.where(handler_module_name: value)
  end

  def options
    Webhukhs::ReceivedWebhook.distinct.order(:handler_module_name).pluck(:handler_module_name).index_with(&:itself)
  end
end
