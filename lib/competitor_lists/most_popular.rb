class CompetitorLists::MostPopular < CompetitorLists::Base::Base
  TITLE = 'Firms that are popular'

  def title
    "#{TITLE} in #{cache_values[:city]}"
  end

  def self._eligible?(attrs)
    return false unless attrs[:city].present?
    sql = <<-SQL
      SELECT COUNT(*) FROM (#{_sql(attrs)}) AS subquery
    SQL
    Competitor.connection.select_value(sql) > 0
  end

  def self.cache_values_span
    Competitor.locations(nil, nil).map { |l| { city: l } }
  end

  def self.cache_key_attrs
    {
      city: Proc.new { |founder| founder.city }
    }
  end

  def self.cache_key_fallbacks
    {
      city: Proc.new { |request| request.session[:city] }
    }
  end

  def self._sql(attrs)
    Competitor
      .where('competitors.location && ?', "{#{attrs[:city]}}")
      .joins(:companies)
      .joins(:investors)
      .where('companies.location = ?', attrs[:city])
      .order('ti_sum DESC, c_cnt DESC')
      .group('competitors.id')
      .select('competitors.id', 'COALESCE(SUM(investors.target_investors_count), 0) AS ti_sum', 'COUNT(companies.id) AS c_cnt')
      .limit(10)
      .to_sql
  end

  def _sql
    self.class._sql(cache_values)
  end

  def sort
    <<-SQL
      subquery.ti_sum DESC, subquery.c_cnt DESC
    SQL
  end

  def order_sql
    <<-SQL
      row_number() OVER (ORDER BY #{sort}) AS rn
    SQL
  end

  def with_order_subquery
    <<-SQL
      SELECT subquery.id, #{order_sql}
      FROM (#{_sql}) AS subquery
      LIMIT 10
    SQL
  end

  def sql
    <<-SQL
      SELECT competitors.*, wo.rn
      FROM (#{with_order_subquery}) AS wo
      INNER JOIN competitors USING (id)
    SQL
  end

  def order
    :rn
  end
end