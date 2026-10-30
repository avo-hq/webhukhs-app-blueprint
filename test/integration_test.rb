require_relative "application"
require "minitest/autorun"
require "base64"

class WebhukhsBlueprintTest < ActionDispatch::IntegrationTest
  def setup
    Webhukhs::ReceivedWebhook.delete_all
    @error = webhook("evt_error", "error", "RetiredHandler", '{"order_id":42}')
    @processed = webhook("evt_processed", "processed", "OrdersHandler", "not JSON: <script>alert(1)</script>")
    @path = "/admin/resources/webhukhs_received_webhooks"
  end

  def test_index_is_read_only_and_sorts_by_id
    get @path
    assert_response :success
    assert_select "a[href='#{@path}/new']", count: 0
    assert_select "a[href$='/edit']", count: 0
    assert_select "[data-turbo-method='delete']", count: 0
    assert_operator response.body.index("evt_processed"), :<, response.body.index("evt_error")
  end

  def test_status_and_historical_handler_filters
    get @path, params: {encoded_filters: Base64.strict_encode64({"Avo::Filters::WebhukhsStatus" => "error", "Avo::Filters::WebhukhsHandler" => "RetiredHandler"}.to_json)}
    assert_response :success
    assert_includes response.body, "evt_error"
    refute_includes response.body, "evt_processed"
    assert_includes Avo::Filters::WebhukhsHandler.new.options, "RetiredHandler"
    assert_equal %w[error failed_validation processed processing received skipped], Avo::Filters::WebhukhsStatus.new.options.keys.sort
  end

  def test_show_payload_and_headers_without_write_controls
    get "#{@path}/#{@error.id}"
    assert_response :success
    assert_includes response.body, "order_id"
    assert_includes response.body, "HTTP_X_EVENT_ID"
    assert_select "a[href$='/edit']", count: 0
    assert_select "[data-turbo-method='delete']", count: 0
  end

  def test_plain_text_and_html_are_not_executed
    get "#{@path}/#{@processed.id}"
    assert_response :success
    assert_includes response.body, "not JSON:"
    assert_select "script", text: "alert(1)", count: 0
  end

  def test_binary_and_missing_headers_render_without_mutating_storage
    @error.update_columns(body: "bad\xFFbytes".b, request_headers: nil)
    get "#{@path}/#{@error.id}"
    assert_response :success
    assert_includes response.body, "bad�bytes"
    assert_equal "bad\xFFbytes".b, @error.reload.body
  end

  def test_payload_limit_preserves_stored_bytes
    body = "x" * (256 * 1024) + "DO_NOT_RENDER_THIS_SUFFIX"
    @error.update_columns(body: body)
    get "#{@path}/#{@error.id}"
    assert_response :success
    assert_includes response.body, "Payload truncated for display"
    refute_includes response.body, "DO_NOT_RENDER_THIS_SUFFIX"
    assert_equal body, @error.reload.body
  end

  def test_write_routes_and_forms_are_rejected_without_mutation
    original = Webhukhs::ReceivedWebhook.order(:id).map(&:attributes)
    [[:get, "#{@path}/new"], [:get, "#{@path}/#{@error.id}/edit"], [:post, @path], [:patch, "#{@path}/#{@error.id}"], [:put, "#{@path}/#{@error.id}"], [:delete, "#{@path}/#{@error.id}"]].each do |verb, path|
      public_send(verb, path, params: {webhukhs_received_webhook: {status: "processed", body: "tampered"}})
      assert_response :forbidden
    end
    assert_equal original, Webhukhs::ReceivedWebhook.order(:id).map(&:attributes)
  end

  private

  def webhook(event_id, status, handler, body)
    Webhukhs::ReceivedWebhook.create!(handler_event_id: event_id, handler_module_name: handler, status: status, body: body,
      request_headers: {"HTTP_X_EVENT_ID" => event_id})
  end
end
