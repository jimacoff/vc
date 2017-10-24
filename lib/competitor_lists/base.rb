module CompetitorLists
  module ClassSetup
    def inherited(klass)
      @lists << klass
    end

    def init
      @lists = []
      Dir["#{File.dirname(__FILE__)}/*.rb"].each do |file|
        next if file == __FILE__
        require_dependency file
      end
    end

    def self.extended(base)
      base.init
    end

    def lists
      @lists
    end
  end

  module ClassSql
    def track_status_sql(competitors_table = 'competitors')
      <<-SQL
        LEFT JOIN LATERAL (
          SELECT target_investors.stage AS stage
          FROM investors
          INNER JOIN target_investors ON target_investors.investor_id = investors.id
          WHERE investors.competitor_id = #{competitors_table}.id
          ORDER BY target_investors.updated_at DESC
          LIMIT 1
        ) AS stages ON true
      SQL
    end

    def partners_sql(competitors_table = 'competitors')
      partners_sql = <<-SQL
        SELECT investors.id, investors.first_name, investors.last_name
        FROM investors
        LEFT OUTER JOIN investments ON investments.investor_id = investors.id
        WHERE investors.competitor_id = #{competitors_table}.id
        GROUP BY investors.id
        ORDER BY
          CASE
            WHEN investors.role IN (#{CompetitorCrunchbaseJob::INVESTOR_TITLE.map { |t| "'#{t}'" }.join(', ')}) THEN 1
            ELSE 0
          END DESC,
          MAX(investments.funded_at) DESC NULLS LAST,
          COUNT(investments.id) DESC,
          investors.featured DESC
      SQL
      <<-SQL
        LEFT JOIN LATERAL (
          SELECT array_agg(partners) AS partners_arr
          FROM (#{partners_sql}) AS partners
        ) AS partners ON true
      SQL
    end

    def recent_investments_sql(competitors_table = 'competitors')
      investments_sql = <<-SQL
        SELECT companies.id, companies.name, companies.domain, companies.crunchbase_id
        FROM companies
        INNER JOIN investments ON investments.company_id = companies.id
        WHERE investments.competitor_id = #{competitors_table}.id
        GROUP BY companies.id
        ORDER BY
          MAX(investments.funded_at) DESC NULLS LAST,
          COUNT(NULLIF(investments.featured, false)) DESC,
          companies.capital_raised DESC,
          COUNT(investments.id) DESC
        LIMIT 5
      SQL
      <<-SQL
        LEFT JOIN LATERAL (
          SELECT array_agg(recent_investments) AS ri_arr
          FROM (#{investments_sql}) AS recent_investments
        ) AS ri ON true
      SQL
    end

    def _meta_select(meta_sql)
      meta_sql.present? ? ', row_to_json(metaquery.*) AS meta' : ''
    end

    def _meta_join(meta_sql)
      meta_sql.present? ? "LEFT JOIN LATERAL (#{meta_sql}) metaquery ON true" : ''
    end

    def _order_clause(order)
      order.present? ? "ORDER BY #{order}" : ''
    end

    def _base_sql(sql, meta_sql, order, limit, offset)
      distinct_sql = <<-SQL
        SELECT DISTINCT ON (fullquery.id) fullquery.*
        FROM (#{sql}) AS fullquery
      SQL
      limited_sql = <<-SQL
        SELECT distincted.*
        FROM (#{distinct_sql}) AS distincted
        #{_order_clause(order)}
        OFFSET #{offset}
        LIMIT #{limit}
      SQL
      <<-SQL
        SELECT
          subquery.*,
          stages.stage AS track_status,
          array_to_json(partners.partners_arr) AS partners,
          array_to_json(ri.ri_arr) AS recent_investments
          #{_meta_select(meta_sql)}
        FROM (#{limited_sql}) AS subquery
        #{track_status_sql('subquery')}
        #{recent_investments_sql('subquery')}
        #{partners_sql('subquery')}
        #{_meta_join(meta_sql)}
      SQL
    end
  end

  module ClassBulk
    def get_if_eligible(founder, name)
      @lists.find { |l| l.to_param == name.to_sym && l.eligible?(founder) }
    end

    def get_eligibles(founder)
      @lists.select { |l| l.eligible? founder }
    end

    def eligible?(founder)
      true
    end

    def cache_key_attrs
      nil
    end

    def cache_key(founder, name)
      return nil unless cache_key_attrs.present?
      keys = ['competitor_lists', to_param, name]
      keys += cache_key_attrs.sort.map { |a| founder.send(a).to_s } if cache_key_attrs.is_a?(Array)
      keys.join('/')
    end

    def title
      self::TITLE
    end

    def to_param
      self.name.demodulize.underscore.to_sym
    end
  end

  module Results
    GET_LIMIT = 5

    def cache_key(name)
      self.class.cache_key(@founder, name)
    end

    def cached?
      self.class.cache_key_attrs.present?
    end

    def count_sql
      <<-SQL
        SELECT COUNT(DISTINCT subquery.id)
        FROM (#{sql}) AS subquery
      SQL
    end

    def find_sql(limit, offset: 0)
      self.class._base_sql(sql, '', order, limit, offset)
    end

    def find_with_meta_sql(limit, offset: 0)
      self.class._base_sql(sql, meta_sql, order, limit, offset)
    end

    def fetch_result_count
      Competitor.count_by_sql count_sql
    end

    def result_count
      if cached?
        Rails.cache.fetch(cache_key('count')) || 0
      else
        fetch_result_count
      end
    end

    def fetch_results(limit, offset, meta, json: nil)
      if meta
        mapper = json.present? ? "as_#{json}_json".to_sym : :as_meta_json
        Competitor.find_by_sql(find_with_meta_sql(limit, offset: offset)).map(&mapper)
      else
        mapper = json.present? ? "as_#{json}_json".to_sym : :as_json
        Competitor.find_by_sql(find_sql(limit, offset: offset)).map(&mapper)
      end
    end

    def results(limit: GET_LIMIT, offset: 0, meta: false, json: nil)
      if cached? && !json
        Rails.cache.fetch(cache_key('results'))
      else
        fetch_results(limit, offset, meta, json)
      end
    end

    def cache!(limit: GET_LIMIT * 2, offset: 0)
      Rails.cache.write(cache_key('results'), (results = fetch_results(limit, offset, true)))
      Rails.cache.write(cache_key('count'), results.count)
    end
  end

  class Base
    extend ClassSetup
    extend ClassSql
    extend ClassBulk
    include Results

    attr_reader :founder

    def initialize(founder)
      @founder = founder
    end

    def sql
      raise 'must implement sql'
    end

    def meta_sql
    end

    def meta_cols
    end

    def order
    end

    def title
      self.class.title
    end

    def to_param
      self.class.name.demodulize.underscore.to_sym
    end

    def as_json(opts = {})
      {
        competitors: results(**opts),
        columns: meta_cols,
        count: result_count,
        title: title,
        name: to_param
      }
    end
  end
end