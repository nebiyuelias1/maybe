class Provider::ExchangeApi < Provider
  include ExchangeRateConcept

  # Subclass so errors caught in this provider are raised as Provider::ExchangeApi::Error
  Error = Class.new(Provider::Error)
  InvalidExchangeRateError = Class.new(Error)

  # Uses fawazahmed0/exchange-api — free, no API key required, 340+ currencies
  # https://github.com/fawazahmed0/exchange-api
  #
  # URL patterns (Cloudflare Pages CDN):
  #   Latest:     https://latest.currency-api.pages.dev/v1/currencies/{currency}.json
  #   Historical: https://{yyyy-mm-dd}.currency-api.pages.dev/v1/currencies/{currency}.json
  #   Currencies: https://latest.currency-api.pages.dev/v1/currencies.json

  # No API key required
  def initialize
  end

  def healthy?
    with_provider_response do
      response = client.get("#{url_for_date("latest")}/v1/currencies.json")
      JSON.parse(response.body).keys.any?
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      from_key = from.downcase
      to_key = to.downcase

      response = fetch_with_fallback(from_key, date)
      parsed = JSON.parse(response.body)
      rate_value = parsed.dig(from_key, to_key)

      if rate_value.nil?
        raise InvalidExchangeRateError, "No rate returned for #{from}->#{to} on #{date}"
      end

      Rate.new(date: date.to_date, from: from, to: to, rate: rate_value)
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      from_key = from.downcase
      to_key = to.downcase
      rates = []

      start_date.to_date.upto(end_date.to_date).each do |date|
        response = fetch_with_fallback(from_key, date)
        parsed = JSON.parse(response.body)
        rate_value = parsed.dig(from_key, to_key)

        if rate_value.nil?
          Rails.logger.warn("#{self.class.name} returned no rate for #{from}->#{to} on #{date}")
          next
        end

        rates << Rate.new(date: date, from: from, to: to, rate: rate_value)
      rescue Faraday::Error => e
        # Skip dates where the API returns an error (e.g., future dates, missing data)
        Rails.logger.warn("#{self.class.name} failed to fetch rate for #{from}->#{to} on #{date}: #{e.message}")
        next
      end

      rates
    end
  end

  private
    def base_domain
      ENV["EXCHANGE_API_URL"] || "currency-api.pages.dev"
    end

    def url_for_date(date_or_latest)
      if base_domain.include?("://")
        # Custom URL provided (e.g., for testing) — use as-is with date path
        "#{base_domain}/#{date_or_latest}"
      else
        # Default Cloudflare Pages CDN: {date}.{domain}
        "https://#{date_or_latest}.#{base_domain}"
      end
    end

    # Fetches currency data for a given date. If the specific date returns a 404,
    # falls back to "latest" (useful when today's data isn't published yet).
    def fetch_with_fallback(currency_key, date)
      client.get("#{url_for_date(date)}/v1/currencies/#{currency_key}.json")
    rescue Faraday::ResourceNotFound
      client.get("#{url_for_date("latest")}/v1/currencies/#{currency_key}.json")
    end

    def client
      @client ||= Faraday.new do |faraday|
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
