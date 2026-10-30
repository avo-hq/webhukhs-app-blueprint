class Avo::Filters::WebhukhsStatus < Avo::Filters::SelectFilter
  self.name = "Status"

  def apply(request, query, value)
    query.where(status: value)
  end

  def options
    Webhukhs::ReceivedWebhook.statuses.keys.index_with(&:humanize)
  end
end
