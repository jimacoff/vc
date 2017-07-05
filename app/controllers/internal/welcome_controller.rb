class Internal::WelcomeController < Internal::ApplicationController
  include Concerns::Slackable

  def index
    if internal_user_signed_in?
      if Company.pitched.undecided.count > 0
        redirect_to controller: 'companies', action: 'voting'
      else
        redirect_to controller: 'companies', action: 'index'
      end
    end
  end

  def send_slack_feedback
    if internal_user_signed_in?
      message = "<@#{params[:bot]}>: <@#{current_internal_user.slack_id}> found that annoying!"
      slack_send! params[:channel], message
      flash[:success] = 'Thanks for your feedback!'
    end
    redirect_to internal_root_path
  end
end
