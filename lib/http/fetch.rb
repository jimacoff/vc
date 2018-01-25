class Http::Fetch
  CACHE_DIR = "#{Rails.root}/tmp/http_cache"
  EASY_OPTIONS = { follow_location: true, version: Curl::HTTP_2_0 }
  MULTI_OPTIONS = { pipeline: Curl::CURLPIPE_MULTIPLEX | Curl::CURLPIPE_HTTP1 }
  OK = '200 OK'
  DEFAULT_ERROR = 500

  class Error < StandardError
  end

  def self.cache
    @cache ||= ActiveSupport::Cache.lookup_store(:file_store, CACHE_DIR)
  end

  def self.safe_status(resp)
    begin
      resp.status
    rescue NoMethodError # taf2/curb#325
      raise Error.new(DEFAULT_ERROR)
    end
  end

  def self.get_advanced(url, headers)
    return nil unless url.present?
    resp = Curl::Easy.perform(url) do |curl|
      curl.headers.merge!(headers)
    end
    if (status = safe_status resp) == OK
      Util.fix_encoding resp.body_str
    else
      raise Error.new(status)
    end
  end

  def self.get_one(url)
    get([url]).values.first
  end

  def self.get(urls)
    urls.compact!
    results = cache.read_multi(*urls)
    remaining = urls - results.keys

    exception = nil
    Curl::Multi.get(remaining, EASY_OPTIONS, MULTI_OPTIONS) do |resp|
      begin
        if safe_status(resp) == OK
          body = Util.fix_encoding resp.body_str
          results[resp.url] = body
          cache.write(resp.url, body)
        else
          results[resp.url] = nil
        end
      rescue HTTP::Fetch::Error
        results[resp.url] = nil
      rescue Exception => e
        exception = e
      end
    end if remaining.present?
    begin
      GC.start
    rescue Curl::Err::MultiBadEasyHandle
      # ignored
    end
    raise exception if exception.present?
    results
  end
end
