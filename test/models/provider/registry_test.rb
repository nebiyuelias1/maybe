require "test_helper"

class Provider::RegistryTest < ActiveSupport::TestCase
  test "exchange_api is always available (no API key needed)" do
    assert_instance_of Provider::ExchangeApi, Provider::Registry.get_provider(:exchange_api)
  end

  test "exchange_api is the primary exchange_rates provider" do
    registry = Provider::Registry.for_concept(:exchange_rates)
    provider = registry.get_provider(:exchange_api)
    assert_instance_of Provider::ExchangeApi, provider
  end

  test "frankfurter is always available (no API key needed)" do
    assert_instance_of Provider::Frankfurter, Provider::Registry.get_provider(:frankfurter)
  end

  test "frankfurter is available as fallback exchange_rates provider" do
    registry = Provider::Registry.for_concept(:exchange_rates)
    provider = registry.get_provider(:frankfurter)
    assert_instance_of Provider::Frankfurter, provider
  end

  test "synth is available as fallback exchange_rates provider when configured" do
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      registry = Provider::Registry.for_concept(:exchange_rates)
      provider = registry.get_provider(:synth)
      assert_instance_of Provider::Synth, provider
    end
  end

  test "exchange_rates providers are ordered: exchange_api, frankfurter, synth" do
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      registry = Provider::Registry.for_concept(:exchange_rates)
      providers = registry.providers.compact
      assert_instance_of Provider::ExchangeApi, providers[0]
      assert_instance_of Provider::Frankfurter, providers[1]
      assert_instance_of Provider::Synth, providers[2]
    end
  end

  test "synth configured with ENV" do
    Setting.stubs(:synth_api_key).returns(nil)

    with_env_overrides SYNTH_API_KEY: "123" do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:synth)
    end
  end

  test "synth configured with Setting" do
    Setting.stubs(:synth_api_key).returns("123")

    with_env_overrides SYNTH_API_KEY: nil do
      assert_instance_of Provider::Synth, Provider::Registry.get_provider(:synth)
    end
  end

  test "synth not configured" do
    Setting.stubs(:synth_api_key).returns(nil)

    with_env_overrides SYNTH_API_KEY: nil do
      assert_nil Provider::Registry.get_provider(:synth)
    end
  end
end
