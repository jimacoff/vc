class External::Api::V1::InvestorsController < External::Api::V1::ApiV1Controller
  include External::Concerns::Censorable

  before_action :authenticate_api_user!

  filter %w(comments competitor.comments)

  def index
    render_censored Investor.order(updated_at: :asc).limit(25).offset(page * 25)
  end

  def recommendations
    recommendations_shown!
    render_censored current_external_founder.recommended_investors(limit: 5, offset: 5 * page)
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
      render_censored results
    end
  end

  def fuzzy_search
    query = { first_name: params[:q], last_name: params[:q], competitors: { name: params[:q] } }
    results = Investor
                .includes(:notes, competitor: :notes)
                .references(:competitors)
                .fuzzy_search(query, false)
                .where.not(id: existing_target_investor_ids)
                .order('featured')
    render_censored results
  end

  def update
    investor = Investor.find(params[:id])

    if investor_params.present?
      investor.update! investor_params
    end

    if investor_note_params.present?
      note = investor.notes.first_or_initialize(founder: current_external_founder)
      note.body = investor_note_params[:note]
      note.save!
    end

    if competitor_params[:competitor].present?
      investor.competitor.update! competitor_params[:competitor]
    end

    if competitor_note_params[:competitor].present?
      note = investor.competitor.notes.first_or_initialize(founder: current_external_founder)
      note.body = competitor_note_params[:competitor][:note]
      note.save!
    end

    render_censored investor
  end

  def create
    if investor_create_query_params.present?
      query = investor_create_query_params[:query]
      investor = Investor.from_name(query)
      render_censored investor || begin
       first_name, last_name = split_name(query)
       {first_name: first_name, last_name: last_name, competitor: {}}
      end
    else
      investor = Investor.new investor_create_params
      investor.competitor =  Competitor.create_from_name!(competitor_create_params[:competitor][:name])
      investor.save!
      render_censored investor
    end
  end

  private

  def search_params
    { competitors: { name: params[:firm_name] } }.deep_compact
  end

  def fuzzy_search_params
    params.permit(:first_name, :last_name).to_h.compact
  end

  def existing_target_investor_ids
    current_external_founder.existing_target_investor_ids
  end

  def recommendations_shown!
    session[:recommendations_shown] = true
  end

  def page
    (params[:page] || 0).to_i
  end

  def investor_create_query_params
    params.require(:investor).permit(:query)
  end

  def investor_create_params
    params.require(:investor).permit(:first_name, :last_name, :email)
  end

  def competitor_create_params
    params.require(:investor).permit(competitor: :name)
  end

  def investor_params
    params.require(:investor).permit(:industry, :funding_size)
  end

  def investor_note_params
    params.require(:investor).permit(:note)
  end

  def competitor_params
    params.require(:investor).permit(competitor: [:industry, :funding_size])
  end

  def competitor_note_params
    params.require(:investor).permit(competitor: :note)
  end
end
