class IntroRequest < ApplicationRecord
  TOKEN_MAGIC = 'VCWIZ_INTRO_'
  DEVICE_TYPES = %w(desktop mobile tablet other unknown)
  MAX_IN_FLIGHT = 5

  belongs_to :investor
  belongs_to :company
  belongs_to :founder
  belongs_to :target_investor

  validates :investor, presence: true, uniqueness: { scope: [:founder, :company] }
  validates :company, presence: true
  validates :founder, presence: true
  validates :token, presence: true

  validate :limit_outstanding_requests, on: :create

  enum open_device_type: DEVICE_TYPES

  before_validation :check_opt_out!, on: :create
  before_validation :set_token!, on: :create
  after_commit :send!, on: :create

  def self.from_target_investor!(target_investor)
    create!(
      target_investor: target_investor,
      investor: target_investor.investor,
      founder: target_investor.founder,
      company: target_investor.founder.primary_company,
    )
  end

  def decide!(decision)
    update! accepted: decision
    send_decision!
  end

  def send_decision!
    return unless decided?
    if accepted
      IntroMailer.intro_email(self).deliver_later
    else
      if investor.opted_in?
        IntroMailer.no_intro_email(self).deliver_later
        IntroMailer.reason_email(self).deliver_later
      else
        IntroMailer.no_opt_in_email(self).deliver_later
      end
    end
  end

  def decided?
    accepted != nil
  end

  def public_token
    "#{TOKEN_MAGIC}#{token}"
  end

  def add_domain!(url)
    self.click_domains << URI.parse(url).host
    save!
  end

  def travel_status
    if open_country.blank?
      nil
    elsif open_country != 'US'
      :pleasure_traveling
    else
      investor.travel_status open_city
    end
  end

  def clicked?(url)
    ((URI.parse(url).host rescue nil) || url).in? click_domains
  end

  %w(twitter linkedin).each do |s|
    define_method "clicked_#{s}?" do
      clicked? "www.#{s}.com"
    end
  end

  def clicked_website?
    company.domain.present? ? clicked?(company.domain) : false
  end

  def clicked_deck?
    pitch_deck.present? ? clicked?(pitch_deck) : false
  end

  def clicks
    %w(twitter linkedin website deck).map { |s| [s,
                                                 send("clicked_#{s}?")] }.to_h
  end

  def as_json(options = {})
    super options.reverse_merge(only: [:id, :opened_at, :open_city, :accepted, :reason], methods: [:clicks, :travel_status])
  end

  private

  def limit_outstanding_requests
    if self.class.unscoped.where(founder: founder, accepted: nil).count > MAX_IN_FLIGHT - 1
      errors.add(:base, 'too many outstanding requests')
    end
  end

  def check_opt_out!
    self.accepted = false if investor.opted_out?
  end

  def send!
    if investor.opted_out?
      send_decision!
    else
      target_investor&.intro_requested! self.id
      if investor.opted_in?
        IntroMailer.request_email(self).deliver_later
      else
        IntroMailer.opt_in_email(self).deliver_later
      end
    end
  end

  def set_token!
    self.token ||= SecureRandom.hex.first(10).upcase
  end
end
