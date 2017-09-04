class IntroMailer < ApplicationMailer
  helper :intro_mail
  default from: ENV['MAILGUN_EMAIL']
  before_action :set_mailgun_options!

  def opt_in_email(request)
    set_instance_vars! request
    mail to: named_email(@investor), subject: "#{@company.name} <> #{@competitor.name}"
  end

  def request_email(request)
    set_instance_vars! request
    mail to: named_email(@investor), subject: "#{@company.name} <> #{@competitor.name}"
  end

  def intro_email(request)
    set_instance_vars! request
    mail to: [named_email(@investor), named_email(@founder)], subject: "#{@company.name} <> #{@competitor.name}"
  end

  def no_opt_in_email(request)
    set_instance_vars! request
    mail to: named_email(@founder), subject: "Introduction to #{@investor.name} (#{@competitor.name})"
  end

  def no_intro_email(request)
    set_instance_vars! request
    mail to: named_email(@founder), subject: "Introduction to #{@investor.name} (#{@competitor.name})"
  end

  private

  def set_mailgun_options!
    mail.delivery_method.settings = {
      address:              'smtp.mailgun.org',
      port:                 587,
      domain:               ENV['MAILGUN_EMAIL'].split('@').last,
      user_name:            ENV['MAILGUN_EMAIL'],
      password:             ENV['MAILGUN_PASSWORD'],
      authentication:       'plain',
      enable_starttls_auto: true
    }
  end

  def named_email(person)
    "#{person.name} <#{person.email}>"
  end

  def set_instance_vars!(request)
    @request = request
    @investor = request.investor
    @company = request.company
    @founder = request.founder
    @competitor = @investor.competitor
  end
end
