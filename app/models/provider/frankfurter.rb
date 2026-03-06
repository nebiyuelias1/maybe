class Provider::Frankfurter < Provider
  include ExchangeRateConcept

  # Subclass so errors caught in this provider are raised as Provider::Frankfurter::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)

  # No API key required - Frankfurter is free and open source
  def initialize
  end

  def healthy?
    with_provider_response do
      response = client.get("#{base_url}/v1/currencies")
      JSON.parse(response.body).keys.any?
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      response = client.get("#{base_url}/v1/#{date}") do |req|
        req.params["base"] = from
        req.params["symbols"] = to
      end

      parsed = JSON.parse(response.body)
      rate_value = parsed.dig("rates", to)

      if rate_value.nil?
        raise InvalidExchangeRateError, "No rate returned for #{from}->#{to} on #{date}"
      end

      Rate.new(date: date.to_date, from: from, to: to, rate: rate_value)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      response = client.get("#{base_url}/v1/#{start_date}..#{end_date}") do |req|
        req.params["base"] = from
        req.params["symbols"] = to
      end

      parsed = JSON.parse(response.body)
      rates_hash = parsed.dig("rates") || {}

      rates_hash.filter_map do |date_str, currencies|
        rate_value = currencies[to]

        if date_str.nil? || rate_value.nil?
          Rails.logger.warn("#{self.class.name} returned invalid rate data for pair from: #{from} to: #{to} on: #{date_str}. Rate data: #{rate_value.inspect}")
          Sentry.capture_exception(InvalidExchangeRateError.new("#{self.class.name} returned invalid rate data"), level: :warning) do |scope|
            scope.set_context("rate", { from: from, to: to, date: date_str })
          end

          next
        end

        Rate.new(date: date_str.to_date, from: from, to: to, rate: rate_value)
      end
    end
  end

  private
    def base_url
      ENV["FRANKFURTER_URL"] || "https://api.frankfurter.dev"
    end

    def client
      @client ||= Faraday.new(url: base_url) do |faraday|
        faraday.request(:retry, {
          max: 2,
          interval: 0.05,
          interval_randomness: 0.5,
          backoff_factor: 2
        })

        faraday.response :raise_error
      end
    end
end
