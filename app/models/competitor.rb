class Competitor < ApplicationRecord
  include Concerns::AttributeSortable

  COMPETITORS = {
    'Rough Draft Ventures': Http::Rdv,
    'Y Combinator': nil,
    'First Round Capital': nil,
    'TechStars': nil,
  }.with_indifferent_access.freeze

  FUND_TYPES = {
    accelerator: 'Accelerator',
    seed: 'Seed',
    angel: 'Angel',
    venture: 'Venture',
    series_A: 'Series A',
    series_B: 'Series B',
  }.with_indifferent_access.freeze

  INDUSTRIES = {
    consumer: 'Consumer',
    enterprise: 'Enterprise',
    ecommerce: 'E-Commerce',
    delivery: 'Delivery',
    saas: 'SaaS',
    ai: 'AI/ML',
    robotics: 'Robotics',
    food: 'Food & Drink',
    mobile: 'Mobile',
    healthcare: 'Healthcare',
    media: 'Media',
    finance: 'Finance',
    education: 'Education',
    lifesci: 'Life Sci.',
    retail: 'Retail',
    realestate: 'Real Estate',
    travel: 'Travel',
    automotive: 'Automotive',
    sports: 'Sports',
    cleantech: 'Clean Tech',
    iot: 'IoT',
    social: 'Social',
    energy: 'Energy',
    hardware: 'Hardware',
    gaming: 'Gaming',
    space: 'Space',
    data: 'Data',
    transportation: 'Transportation',
    marketplace: 'Marketplace',
    security: 'Security',
  }.with_indifferent_access.freeze

  RELATED_INDUSTRIES = {
    saas: ['Software as a Service'],
    gaming: ['Video Games'],
    transportation: ['Public Transportation', 'Ride Sharing'],
    mobile: ['Mobile Devices', 'Telecommunications', 'Mobile Apps'],
    food: ['Food and Beverage', 'Food Delivery', 'Nutrition', 'Food', 'Restaurants'],
    social: ['Social', 'Messaging', 'Social Media'],
    ai: ['Machine Learning', 'Artificial Intelligence'],
    enterprise: ['Enterprise Software', 'B2B'],
    healthcare: ['Health Care', 'Medical'],
    media: ['Entertainment', 'Music', 'Video'],
    finance: ['FinTech'],
    energy: ['Electric Vehicle', 'Energy Management'],
    data: ['Analytics'],
    iot: ['Internet of Things'],
    security: ['Network Security', 'Cyber Security'],
  }.freeze

  CLOSEST_INDUSTRY_THRESHOLD = 0.4

  sort :industry
  sort :fund_type
  sort :location

  has_many :investors, dependent: :destroy
  has_many :target_investors, through: :investors
  has_many :investments, dependent: :destroy
  has_many :companies, through: :investments
  has_many :notes, as: :subject, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :crunchbase_id, uniqueness: { allow_nil: true }
  validates :al_id, uniqueness: { allow_nil: true }

  after_commit :start_crunchbase_job, on: :create
  before_validation :normalize_location

  def self.closest_industry(industry)
    distances = INDUSTRIES.flat_map do |k, friendly|
      ([friendly] + (RELATED_INDUSTRIES[k] || [])).map do |s|
        [Levenshtein.distance(s, industry) / [k.length, industry.length].max.to_f, k]
      end
    end
    if (best = distances.sort.first).first < CLOSEST_INDUSTRY_THRESHOLD
      best.last
    else
      nil
    end
  end

  def self.create_from_name!(name)
    existing = search(name: name).first
    return existing if existing.present?

    if (crunchbase_id = Http::Crunchbase::Organization.find_investor_id(name)).present?
      from_crunchbase! crunchbase_id, name
    elsif (al_id = Http::AngelList::Startup.find_id(name))
      from_angelist! al_id, name
    else
      create! name: name
    end
  end

  def self.create_from_domain!(domain, name)
    crunchbase_id = Http::Crunchbase::Organization.find_domain_id(domain)
    from_crunchbase! crunchbase_id, name if crunchbase_id.present?
  end

  def self.from_crunchbase!(crunchbase_id, name)
    found = where(crunchbase_id: crunchbase_id).or(where(name: name)).first
    found = create!(crunchbase_id: crunchbase_id, name: name) unless found.present?
    found.tap do |competitor|
      competitor.crunchbase_id = crunchbase_id
      competitor.name = name
    end
  end

  def self.from_angelist!(al_id, name)
    where(al_id: al_id).first_or_create! do |competitor|
      competitor.name = name
    end
  end

  def self.for_company(company)
    org = company.crunchbase_org(5)
    where(name: COMPETITORS.keys).select do |competitor|
        org.has_investor?(competitor.crunchbase_id) ||
        COMPETITORS[competitor.name]&.new&.invested?(company.name)
    end
  end

  def self.to_param(company)
    return false unless company.competitors.present?
    company.competitors.map(&:acronym).join(', ')
  end


  def self.filtered(params, opts = {})
    CompetitorLists::Filtered.new(params).results(**opts)
  end

  def self.filtered_count(params)
    CompetitorLists::Filtered.new(params).result_count
  end

  def self.locations(query, limit = 5)
    connection.select_values <<-SQL
      SELECT ulocations FROM (
        SELECT unnest(location)
        FROM competitors
        WHERE
          location <> '{}'
          AND location IS NOT NULL
      ) AS s(ulocations)
      WHERE ulocations ILIKE '#{query.present? ? sanitize_sql_like(query) : ''}%'
      GROUP BY ulocations
      ORDER BY count(ulocations) DESC
      LIMIT #{limit}
    SQL
  end

  def self.lists(founder)
    CompetitorLists::Base.get_eligibles(founder).map { |l| l.new(founder).as_json(json: :list) }
  end

  def self.list(founder, name)
    CompetitorLists::Base.get_if_eligible(founder, name)&.new(founder)
  end

  def as_json(options = {})
    super options.reverse_merge(
      only: [
        :industry,
        :name,
        :fund_type,
        :location,
        :photo,
      ],
      methods: [
        :acronym,
        :track_status
      ]
    )
  end

  def as_meta_json
    as_json(
      only: [
        :name,
        :location,
        :photo,
        :meta,
      ],
      methods: [
        :acronym,
        :track_status
      ]
    )
  end

  def as_list_json
    as_json(only: [:photo, :id], methods: [:acronym])
  end

  def as_search_json
    as_json(only: [:name, :industry, :fund_type], methods: [])
  end

  def acronym
    name.split('').select { |l| /[[:upper:]]/.match l }.join
  end

  def crunchbase_fund
    @crunchbase_fund ||= Http::Crunchbase::Fund.new(crunchbase_id, nil)
  end

  def angellist_startup
    @angellist_startup ||= Http::AngelList::Startup.new(al_id)
  end

  private

  def normalize_location
    self.location = self.location.map(&Util.method(:normalize_city)) if self.location.present?
  end

  def track_status
    if self.attributes.key?('track_status')
      (self[:track_status] && TargetInvestor::STAGES.keys[self[:track_status]])
    else
      target_investors.order(updated_at: :desc).limit(1).pluck(:stage).first
    end
  end

  def start_crunchbase_job
    CompetitorCrunchbaseJob.perform_later(id)
  end
end
