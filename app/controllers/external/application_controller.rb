class External::ApplicationController < ::ApplicationController
  layout 'external'
  before_action :populate_gon

  private

  def populate_gon
    gon.founder = current_external_founder
  end

  def check_founder!
    redirect_to omniauth_path('google_external') unless external_founder_signed_in? && authenticate_external_founder!
  end
end
