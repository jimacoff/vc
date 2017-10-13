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
  end

  module ClassSql
    def track_status_sql(competitors_table = 'competitors')
      <<-SQL
        LEFT JOIN LATERAL (
          SELECT target_investors.stage as stage
          FROM investors
          INNER JOIN target_investors ON target_investors.investor_id = investors.id
          WHERE investors.competitor_id = #{competitors_table}.id
          ORDER BY target_investors.updated_at DESC
          LIMIT 1
        ) AS stages ON true
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

    def _results_sql(sql, meta_sql)
      <<-SQL
        SELECT DISTINCT ON (subquery.id) subquery.*, stages.stage AS track_status #{_meta_select(meta_sql)}
        FROM (#{sql}) AS subquery
        LEFT OUTER JOIN investors ON investors.competitor_id = subquery.id
        #{track_status_sql('subquery')}
        #{_meta_join(meta_sql)}
      SQL
    end

    def _base_sql(sql, meta_sql, order, limit, offset)
      <<-SQL
        SELECT * FROM (#{_results_sql(sql, meta_sql)}) AS results
        #{_order_clause(order)}
        OFFSET #{offset}
        LIMIT #{limit}
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

    def title
      self::TITLE
    end

    def to_param
      self.name.demodulize.underscore.to_sym
    end
  end

  module Results
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

    def result_count
      Competitor.connection.select_value count_sql
    end

    def results(limit: GET_LIMIT, offset: 0, meta: false, json: nil)
      if meta
        mapper = json.present? ? "as_#{json}_json".to_sym : :as_meta_json
        Competitor.find_by_sql(find_with_meta_sql(limit, offset: offset)).map(&mapper)
      else
        mapper = json.present? ? "as_#{json}_json".to_sym : :as_json
        Competitor.find_by_sql(find_sql(limit, offset: offset)).map(&mapper)
      end
    end
  end

  class Base
    extend ClassSetup
    extend ClassSql
    extend ClassBulk
    include Results

    GET_LIMIT = 5

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