class External::VCWiz::IntroController < External::FrontendController
  def opt_in
    intro_request.opt_in! optin?
    intro_request.decide! accept?

    title 'Opt-In'
    render_default
  end

  def decide
    intro_request.decide! accept?

    title 'Intro Decision'
    render_default
  end

  def pixel
    pixel = TrackingPixel.where(token: params[:token]).first!
    pixel.target_investor&.investor_opened! pixel.intro_request&.id, pixel.email_id
    PixelHitJob.perform_later(pixel.id, DateTime.now.to_s, Util.ip_address(request.env), request.user_agent)
    expires_now
    send_file Rails.root.join('public', 'pixel.png'), type: 'image/png', disposition: 'inline'
  end

  private

  def render_default
    component 'Intro'
    props investor: intro_request.investor.as_json(methods: [:competitor]), founder: intro_request.founder, company: intro_request.company.as_json_search
    render layout: 'vcwiz'
  end

  def optin?
    params[:optin] == 'true'
  end

  def accept?
    params[:accept] == 'true'
  end

  def intro_request
    @intro_request ||= IntroRequest.where(token: params[:token]).first!.tap do |intro_request|
      sign_in_external_investor! intro_request.investor
    end
  end
end
