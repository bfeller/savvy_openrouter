# frozen_string_literal: true

require_relative "connection_instrumentation"

require "faraday"
require "json"
require "net/http"
require "uri"

module SavvyOpenrouter
  class Connection
    include Instrumentation

    DEFAULT_SUCCESS = [200, 201, 202, 204].freeze

    attr_reader :config

    def initialize(config)
      @config = config
      @api_call_logger = ApiCallLogger.new(config.api_call_log)
      base = normalize_base(config.base_url)
      headers = build_headers
      @conn = Faraday.new(url: base, headers: headers) do |faraday|
        faraday.request :json
        faraday.response :json, content_type: /\bjson/, parser_options: { symbolize_names: true }
        faraday.adapter Faraday.default_adapter
      end
      @raw = Faraday.new(url: base, headers: headers) do |faraday|
        faraday.adapter Faraday.default_adapter
      end
    end

    def get(path, params: nil, success: DEFAULT_SUCCESS)
      timed_json(:get, path, params: params, success: success)
    end

    def delete(path, params: nil, success: DEFAULT_SUCCESS)
      timed_json(:delete, path, params: params, success: success)
    end

    def post(path, body:, success: DEFAULT_SUCCESS)
      timed_json(:post, path, body: body, success: success)
    end

    def patch(path, body:, success: DEFAULT_SUCCESS)
      timed_json(:patch, path, body: body, success: success)
    end

    def put(path, body:, success: DEFAULT_SUCCESS)
      timed_json(:put, path, body: body, success: success)
    end

    def get_raw(path, params: nil, success: [200])
      rel = rel_path(path)
      started = monotonic_ms
      response = @raw.get(rel) do |req|
        req.params.update(params) if params
      end
      duration_ms = elapsed_ms(started)
      record_faraday_raw(
        method: "GET",
        rel_path: rel,
        params: params,
        request_body: nil,
        response: response,
        duration_ms: duration_ms
      )
      status = response.status
      return response.body.b.freeze if success.include?(status)

      raise_api_error(status, response.body)
    rescue SavvyOpenrouter::ApiError
      raise
    rescue StandardError => e
      record_transport_error(
        method: "GET",
        rel_path: rel,
        params: params,
        request_body: nil,
        duration_ms: elapsed_ms(started),
        error: e
      )
      raise
    end

    def post_raw(path, body:, success: [200])
      rel = rel_path(path)
      started = monotonic_ms
      response = @raw.post(rel) do |req|
        req.headers["Content-Type"] = "application/json"
        req.body = JSON.generate(stringify_body(body))
      end
      duration_ms = elapsed_ms(started)
      record_faraday_raw(
        method: "POST",
        rel_path: rel,
        params: nil,
        request_body: body,
        response: response,
        duration_ms: duration_ms
      )
      status = response.status
      return response.body.b.freeze if success.include?(status)

      raise_api_error(status, response.body)
    rescue SavvyOpenrouter::ApiError
      raise
    rescue StandardError => e
      record_transport_error(
        method: "POST",
        rel_path: rel,
        params: nil,
        request_body: body,
        duration_ms: elapsed_ms(started),
        error: e
      )
      raise
    end

    def stream_get(path, params: nil, &block)
      ensure_api_key!
      uri = join_uri(path)
      uri.query = URI.encode_www_form(params) if params && !params.empty?

      req = Net::HTTP::Get.new(uri)
      build_headers.each { |k, v| req[k] = v }

      started = monotonic_ms
      status, err_buf = stream_via_net_http(uri, req, &block)
      duration_ms = elapsed_ms(started)
      record_stream(
        method: "GET",
        rel_path: rel_path(path),
        params: params,
        request_body: nil,
        status: status,
        response_body: err_buf,
        duration_ms: duration_ms
      )
      return if status == 200

      raise_api_error(status, err_buf) if status
    rescue SavvyOpenrouter::ApiError
      raise
    rescue StandardError => e
      record_transport_error(
        method: "GET",
        rel_path: rel_path(path),
        params: params,
        request_body: nil,
        duration_ms: elapsed_ms(started),
        error: e
      )
      raise
    end

    def stream_post(path, body, &)
      ensure_api_key!
      uri = join_uri(path)
      req = Net::HTTP::Post.new(uri)
      build_headers.each { |k, v| req[k] = v }
      req["Content-Type"] = "application/json"
      req["Accept"] = "text/event-stream"
      req.body = JSON.generate(stringify_body(body))

      started = monotonic_ms
      status, err_buf = stream_via_net_http(uri, req, &)
      duration_ms = elapsed_ms(started)
      record_stream(
        method: "POST",
        rel_path: rel_path(path),
        params: nil,
        request_body: body,
        status: status,
        response_body: err_buf,
        duration_ms: duration_ms
      )
      return if status == 200

      raise_api_error(status, err_buf) if status
    rescue SavvyOpenrouter::ApiError
      raise
    rescue StandardError => e
      record_transport_error(
        method: "POST",
        rel_path: rel_path(path),
        params: nil,
        request_body: body,
        duration_ms: elapsed_ms(started),
        error: e
      )
      raise
    end

    private

    def stream_via_net_http(uri, req, &block)
      status = nil
      err_buf = nil
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req) do |res|
          status = res.code.to_i
          unless status == 200
            buf = +""
            res.read_body { |c| buf << c }
            err_buf = buf
            next
          end

          res.read_body(&block)
        end
      end
      [status, err_buf]
    end

    def stringify_body(body)
      case body
      when Hash
        body.transform_keys(&:to_s)
      else
        body
      end
    end

    def parse_json_response(response, success:)
      status = response.status
      return response.body if success.include?(status)
      return nil if status == 204

      raise_api_error(status, response.body)
    end

    def raise_api_error(status, body)
      payload = parse_error_payload(body)
      message = extract_message(payload)
      exception_class = error_class_for(status)
      raise exception_class.new(
        message,
        status_code: status,
        response_body: payload
      )
    end

    def parse_error_payload(body)
      case body
      when Hash
        body
      when String
        return {} if body.strip.empty?

        JSON.parse(body, symbolize_names: true)
      else
        {}
      end
    rescue JSON::ParserError
      { raw: body.to_s }
    end

    def extract_message(payload)
      err = payload[:error] || payload["error"]
      case err
      when Hash
        err[:message] || err["message"] || err.inspect
      when String
        err
      else
        "HTTP error (#{payload.inspect})"
      end
    end

    def error_class_for(status)
      case status
      when 400 then BadRequestError
      when 401 then AuthenticationError
      when 402 then PaymentRequiredError
      when 403 then ForbiddenError
      when 404 then NotFoundError
      when 429 then RateLimitError
      when 500, 501 then InternalServerError
      when 502 then BadGatewayError
      else ApiError
      end
    end

    def ensure_api_key!
      return if config.api_key && !config.api_key.to_s.empty?

      raise ConfigurationError, "OpenRouter api_key is missing; set OPENROUTER_API_KEY or pass api_key: to SavvyOpenrouter::Client"
    end

    def build_headers
      ensure_api_key!
      h = {
        "Authorization" => "Bearer #{config.api_key}",
        "Accept" => "application/json"
      }
      h["HTTP-Referer"] = config.http_referer if config.http_referer && !config.http_referer.to_s.empty?
      h["X-Title"] = config.app_title if config.app_title && !config.app_title.to_s.empty?
      h
    end

    def normalize_base(url)
      url.to_s.chomp("/")
    end

    def rel_path(path)
      path.to_s.delete_prefix("/")
    end

    def join_uri(path)
      base = normalize_base(config.base_url)
      rel = rel_path(path)
      URI.parse("#{base}/#{rel}")
    end
  end
end
