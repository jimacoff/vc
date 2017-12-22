class External::Api::V1::InvestorsController < External::Api::V1::ApiV1Controller
  include External::Concerns::Censorable
  include External::ApplicationHelper

  LIMIT = 10

  before_action :authenticate_api_user!, only: [:fuzzy_search, :update]

  filter %w(email)
  
  def show
    render_censored  Investor.find(params[:id])
  end

  def interactions
    render json: { interactions: Investor.find(params[:id]).interactions(current_external_founder) }
  end

  def review
    render json: { review: Investor.find(params[:id]).review }
  end

  def locations
    render json: arr_to_options(Investor.locations(params[:q]))
  end

  def filter
    investors = Investor.where filter_params.to_h.except(:industry, :fund_type).compact
    investors = investors.where("industry @> '{#{filter_params[:industry]}}'") if filter_params[:industry].present?
    investors = investors.where("fund_type @> '{#{filter_params[:fund_type]}}'") if filter_params[:fund_type].present?
    investors = investors.order('featured DESC, target_investors_count DESC')
    investors = investors.limit(LIMIT).offset(page * LIMIT)
    render_censored investors.map(&:as_search_json)
  end

  def search
    return render json: [] if search_params.blank? && fuzzy_search_params.blank?
    results = Investor.includes(:competitor).references(:competitors)
    results = results.search(search_params) if search_params.present?
    results = results.fuzzy_search(fuzzy_search_params) if fuzzy_search_params.present?
    results = results.where.not(id: existing_target_investor_ids) if existing_target_investor_ids.count > 0
    results = results.order('featured')
    if params[:pluck].present?
      extract = lambda do |m|
        components = params[:pluck].split('.').reverse
        m = m.send(components.pop) while components.present?
        m
      end
      render json: results.map(&extract).uniq
    else
      render_censored results.map(&:as_search_json)
    end
  end

  def fuzzy_search
    query = { first_name: params[:q], last_name: params[:q], competitors: { name: params[:q] } }
    results = Investor
                .includes(:competitor)
                .references(:competitors)
                .fuzzy_search(query, false)
                .where.not(id: existing_target_investor_ids)
                .order('featured DESC')
                .limit(10)
    render_censored results.map(&:as_search_json)
  end

  def update
    investor = Investor.find(params[:id])

    if (stage = investor_params[:stage]).present?
      target = TargetInvestor.from_investor!(current_external_founder, investor)
      current_external_founder.investor_targeted! investor.id
      target.update! stage: stage
      render_censored(investor) and return
    end

    if investor == current_external_investor
      investor.update!(verified: true) unless investor.verified?

      if investor_update_params.present?
        investor.update! investor_update_params
      end

      if investor_industries.present?
        investor.update! industry: investor_industries.map { |i| i['value'] }
      end

      if investor_companies.present?
        existing = investor.companies.pluck(:id)
        ids = investor_companies.map { |c| c['id'] }
        puts "#{existing}, #{ids}"
        (ids - existing).each do |id|
          Investment.where(company: Company.find(id), competitor: investor.competitor).first_or_create!.tap do |inv|
            inv.update! investor: investor
          end
        end
        (existing - ids).each do |id|
          Investment.where(company_id: id, competitor: investor.competitor, investor: investor).update_all(investor_id: nil)
        end
      end
    end

    render_censored investor.as_search_json
  end

  private

  def investor_update_params
    params.require(:investor).permit(:city, :twitter, :linkedin, :homepage, :email, :facebook, :description, :role, :photo, :al_username, :crunchbase_id)
  end

  def investor_companies
    params.require(:investor).permit![:companies]
  end

  def investor_industries
    params.require(:investor).permit![:industries]
  end

  def search_params
    { competitors: { name: params[:firm_name] } }.deep_compact
  end

  def fuzzy_search_params
    params.permit(:first_name, :last_name).to_h.compact
  end

  def existing_target_investor_ids
    current_external_founder.existing_target_investor_ids
  end

  def filter_params
    params.permit(:industry, :location, :fund_type)
  end

  def investor_params
    params.require(:investor).permit(:stage)
  end
end
