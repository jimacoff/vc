class Entity < ApplicationRecord
  has_many :person_entities, dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { minimum: 3 }
  validates :category, presence: true

  def nice_name
    ')'.in?(name) ? name.split(' (')[0...-1].join(' (') : name
  end

  def self.normalize(name)
    name.gsub(/\W/, ' ').squish.strip
  end

  def self.from_name(raw_name)
    return nil if (name = normalize(raw_name)).length < 3
    where(name: name).first_or_create!(category: 'OTHER')
  end

  def self.from_text(body, format: :text)
    cloud = GoogleCloud::Language.new(body, format: format)
    return [] unless cloud.present? && (entities = cloud.entities).present?
    from_cloud entities.proper
  end

  def self.from_html(body)
    from_text body, format: :html
  end

  def self.from_cloud(entities)
    entities.to_a.map do |e|
      next unless (wiki = e.metadata['wikipedia_url']).present?
      next if normalize(e.name).length <= 3
      from_wiki(wiki, mid: e.metadata['mid'])
    end.compact
  end

  def self.from_wiki(wiki, attrs = {})
    name = CGI.unescape(wiki.split('wiki/').last.gsub("_", " "))
    begin
      where(wiki: wiki).first_or_create!(attrs.merge(name: name))
    rescue ActiveRecord::RecordInvalid
      where(name: name).first
    end
  end

  def self.custom_fuzzy_search(q, person_type, limit: 5)
    sql = <<-SQL
      SELECT entities.*
      FROM entities
      INNER JOIN person_entities ON person_entities.entity_id = entities.id AND person_entities.person_type = '#{person_type}'
      WHERE #{Util.sanitize_sql('((entities.name % ?) OR (entities.name ILIKE ?))', q, "#{q}%")}
      ORDER BY #{Util.sanitize_sql('COALESCE(similarity(entities.name, ?), 0) DESC', q)}
      LIMIT #{limit}
    SQL
    Entity.find_by_sql(sql)
  end

  def as_json(options = {})
    super(options.reverse_merge(only: [:wiki])).merge('name' => nice_name)
  end

  def as_search_json
    as_json(only: [:id])
  end
end
