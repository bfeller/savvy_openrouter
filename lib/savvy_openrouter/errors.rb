# frozen_string_literal: true

module SavvyOpenrouter
  class Error < StandardError
    attr_reader :status_code, :response_body

    def initialize(message = nil, status_code: nil, response_body: nil)
      super(message || self.class.name)
      @status_code = status_code
      @response_body = response_body
    end
  end

  class ConfigurationError < Error; end

  class ApiError < Error; end

  class BadRequestError < ApiError; end

  class AuthenticationError < ApiError; end

  class PaymentRequiredError < ApiError; end

  class ForbiddenError < ApiError; end

  class NotFoundError < ApiError; end

  class RateLimitError < ApiError; end

  class InternalServerError < ApiError; end

  class BadGatewayError < ApiError; end

  class TimeoutPollError < Error; end
end
