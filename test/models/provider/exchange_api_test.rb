require "test_helper"

class Provider::ExchangeApiTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest

  setup do
    @subject = Provider::ExchangeApi.new
  end

  test "health check" do
    VCR.use_cassette("exchange_api/health") do
      response = @subject.healthy?
      assert response.success?
    end
  end
end
