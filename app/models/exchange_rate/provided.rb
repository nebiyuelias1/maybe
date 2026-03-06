module ExchangeRate::Provided
  extend ActiveSupport::Concern

  class_methods do
    def provider
      registry = Provider::Registry.for_concept(:exchange_rates)
      registry.get_provider(:exchange_api)
    end

    def fallback_providers
      registry = Provider::Registry.for_concept(:exchange_rates)
      [
        registry.get_provider(:frankfurter),
        registry.get_provider(:synth)
      ].compact
    end

    def find_or_fetch_rate(from:, to:, date: Date.current, cache: true)
      rate = find_by(from_currency: from, to_currency: to, date: date)
      return rate if rate.present?

      return nil unless provider.present?

      response = provider.fetch_exchange_rate(from: from, to: to, date: date)

      # Try fallback providers if the primary fails
      unless response.success?
        fallback_providers.each do |fallback|
          response = fallback.fetch_exchange_rate(from: from, to: to, date: date)
          break if response.success?
        end
      end

      return nil unless response.success?

      rate = response.data
      ExchangeRate.find_or_create_by!(
        from_currency: rate.from,
        to_currency: rate.to,
        date: rate.date,
        rate: rate.rate
      ) if cache
      rate
    end

    # @return [Integer] The number of exchange rates synced
    def import_provider_rates(from:, to:, start_date:, end_date:, clear_cache: false)
      unless provider.present?
        Rails.logger.warn("No provider configured for ExchangeRate.import_provider_rates")
        return 0
      end

      result = ExchangeRate::Importer.new(
        exchange_rate_provider: provider,
        from: from,
        to: to,
        start_date: start_date,
        end_date: end_date,
        clear_cache: clear_cache
      ).import_provider_rates

      # If the primary provider returned no rates, try fallbacks in order
      if result.nil?
        fallback_providers.each do |fallback|
          result = ExchangeRate::Importer.new(
            exchange_rate_provider: fallback,
            from: from,
            to: to,
            start_date: start_date,
            end_date: end_date,
            clear_cache: clear_cache
          ).import_provider_rates
          break if result.present?
        end
      end

      result
    end
  end
end
