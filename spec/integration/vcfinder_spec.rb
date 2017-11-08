require 'rails_helper'

RSpec.describe 'vcwiz request', type: :request do
  before do
    @company = FactoryBot.create(:company, :verified, :with_external)
    @founder = FactoryBot.create(:founder, companies: [@company])
    @target_investor = FactoryBot.create(:target_investor, founder: @founder)

    sign_in @founder
  end

  it 'renders the react component' do
    get external_vcwiz_root_path
    follow_redirect!
    assert_select 'div[data-react-class=Discover]'
  end

  it 'can fetch the target investors' do
    get external_api_v1_target_investors_path
    expect(response.parsed_body.length).to eq(1)
  end
end