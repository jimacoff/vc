class CompanyRelationshipsJob < ApplicationJob
  queue_as :default

  TIMEOUT = 5
  SOCIAL_KEYS = %w(homepage twitter linkedin facebook)

  def perform(company_id)
    @company = Company.find(company_id)
    @org = @company.crunchbase_org(TIMEOUT)

    @company.set_extra_attributes!

    categories = @org.categories
    @company.industry = categories
                          .map { |c| Competitor.closest_industry(c['properties']['name']) }
                          .compact
                          .uniq if categories.present?
    @company.save! if @company.changed?

    add_founders
    add_investors
  end

  private

  def add_founders
    return unless (founders = @org.founders).present?
    founders.each do |founder|
      person = Http::Crunchbase::Person.new(founder['properties']['permalink'], TIMEOUT)
      social = SOCIAL_KEYS.map { |k| [k, person.public_send(k)] }.to_h
      founder = Founder.find_or_create_from_social!(person.first_name, person.last_name, social, context: @company)
      begin
        founder.tap { |f| f.companies << @company }.save! if founder.present?
      rescue ActiveRecord::RecordNotUnique => _
      end
    end
  end

  def add_investors
    return unless (investors = @org.investors).present?
    investors.each do |competitor|
      begin
        Competitor.where(crunchbase_id: competitor['properties']['permalink']).first_or_create! do |c|
          c.name = competitor['properties']['name']
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.info e
      end
    end
  end
end
