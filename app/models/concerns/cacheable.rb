module Concerns
  module Cacheable
    extend ActiveSupport::Concern

    private

    %w(hour day week month year).each do |period|
      define_method("cache_for_a_#{period}") do |options = {}, &block|
        cached(options.merge({ expires_in: jitter(1, period) }), &block)
      end
    end

    def cached(options = {}, &block)
      cache_fetch base_cache_key, options, &block
    end

    def get_cached(options = {})
      cache_get base_cache_key, options
    end

    def key_cached(key_hash, options = {}, &block)
      key = "#{base_cache_key}/#{key_hash.sort.to_param.gsub('/', '%2F')}"
      cache_fetch key, options, &block
    end

    def cache_fetch(key, options, &block)
      Rails.cache.fetch(key, options.reverse_merge(cache_options), &block)
    end

    def cache_get(key, options)
      Rails.cache.fetch(key, options.reverse_merge(cache_options))
    end

    def cache_options
      { expires_in: jitter(1, :week) }
    end

    def jitter(value, period)
      extra = begin
        (rand * value).send(period)
      rescue
        0.0
      end
      value.send(period) + extra
    end

    def base_cache_key
      from_model = defined?(:id) && id.blank? ? "#{cache_key}/#{rand}" : cache_key
      location = caller_locations.find { |loc| !loc.to_s.include?(__FILE__) }
      "#{from_model}/#{location.label}"
    end
  end
end
