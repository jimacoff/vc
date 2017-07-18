class CompetitorCrunchbaseJob < ApplicationJob
  queue_as :default

  def perform(competitor_id)
    competitor = Competitor.find(competitor_id)
    fund = competitor.crunchbase_fund

    description = fund.short_description
    competitor.description = description if description.present?
    competitor.save! if competitor.changed?

    fund.team.each do |job|
      Investor.from_crunchbase( job['relationships']['person']['properties']['permalink'])
    end

    fund.investments.each do |investment|
      company = investment['relationships']['funding_round']['relationships']['funded_organization']
      Company.where(crunchbase_id: company['properties']['permalink']).first_or_create! do |c|
        c.name = company['properties']['name']
        c.competitors << competitor
      end
    end
  end
end
