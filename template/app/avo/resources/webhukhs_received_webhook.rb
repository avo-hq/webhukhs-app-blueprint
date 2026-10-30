class Avo::Resources::WebhukhsReceivedWebhook < Avo::BaseResource
  self.model_class = "Webhukhs::ReceivedWebhook"
  self.title = :handler_event_id
  self.record_selector = false
  self.default_sort_column = :id
  self.default_sort_direction = :desc

  def fields
    field :id, as: :id, sortable: true, copyable: true
    field :handler_module_name, as: :text, name: "Handler"
    field :handler_event_id, as: :text, name: "Event ID", copyable: true
    field :status, as: :badge, options: {
      success: ["processed"],
      warning: ["received", "processing"],
      danger: ["error", "failed_validation"],
      neutral: ["skipped"]
    }
    field :created_at, as: :date_time, name: "Received at"
    field :updated_at, as: :date_time
    field :body, as: :code, name: "Payload", language: "javascript",
      always_show: true, height: "300px", copyable: true,
      help: "Display limited to 256 KiB. Invalid UTF-8 is replaced for display only. The stored payload is unchanged." do
      body = record.body
      text = body.byteslice(0, 256 * 1024).dup.force_encoding(Encoding::UTF_8).scrub

      if body.bytesize > 256 * 1024
        "#{text}\n[Payload truncated for display]"
      else
        begin
          JSON.pretty_generate(JSON.parse(text))
        rescue JSON::ParserError
          text
        end
      end
    end
    field :request_headers, as: :code, language: "javascript", always_show: true, height: "200px" do
      JSON.pretty_generate(record.request_headers || {})
    end
  end

  def filters
    filter Avo::Filters::WebhukhsStatus
    filter Avo::Filters::WebhukhsHandler
  end

  # Use the core controls so the blueprint also works without paid add-ons.
  def render_index_controls(item:)
    []
  end

  def render_show_controls
    [Avo::Resources::Controls::BackButton.new]
  end

  def render_row_controls(item:)
    [Avo::Resources::Controls::ShowButton.new(item: item)]
  end
end
