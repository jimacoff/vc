class CompetitorLists::MostPopularGlobal < CompetitorLists::MostPopular
  def title
    "#{TITLE} on VCWiz"
  end

  def self._eligible?(attrs)
    true
  end

  def self.derived?
    false
  end

  def self.cache_values_span
    []
  end

  def self.cache_key_attrs
    true
  end

  def self.cache_key_fallbacks
    {}
  end

  def self._sql(attrs)
    Competitor
      .joins(:companies)
      .joins(:investors)
      .order('ti_sum DESC, c_cnt DESC')
      .group('competitors.id')
      .select('competitors.id', 'COALESCE(SUM(investors.target_investors_count), 0) AS ti_sum', 'COUNT(companies.id) AS c_cnt')
      .limit(10)
      .to_sql
  end
end