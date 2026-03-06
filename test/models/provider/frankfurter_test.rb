require "test_helper"

class Provider::FrankfurterTest < ActiveSupport::TestCase
  include ExchangeRateProviderInterfaceTest

  setup do
    @subject = Provider::Frankfurter.new
  end

  test "health check" do
    VCR.use_cassette("frankfurter/health") do
      response = @subject.healthy?
      assert response.success?
    end
  end
end
