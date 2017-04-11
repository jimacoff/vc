class User < ActiveRecord::Base
  include Concerns::Slackable
  include Concerns::Cacheable

  QUORUM_PERCENTAGE = 0.6

  belongs_to :team
  has_many :votes
  has_many :calendar_events
  has_and_belongs_to_many :companies

  validates :username, presence: true, uniqueness: true
  validates :cached_name, presence: true, uniqueness: true
  validates :slack_id, uniqueness: { allow_nil: true }
  validates :trello_id, uniqueness: { allow_nil: true }

  before_validation :set_slack_id, on: :create
  before_validation :set_cached_name, on: :create
  after_create :add_to_wit

  devise :omniauthable, omniauth_providers: [:google_oauth2]

  def self.inactive(team, since = Time.now)
    where(team: team)
    .where(
      arel_table[:inactive_since].lt(since).
      or(arel_table[:created_at].gt(since))
    )
  end

  def self.active(team, since = Time.now)
    where(team: team)
    .where(
      arel_table[:inactive_since].gteq(since).
      or(arel_table[:inactive_since].eq(nil))
    )
    .where(
      arel_table[:created_at].lteq(since)
    )
  end

  def self.quorum(team, at)
    (active(team, at).count * QUORUM_PERCENTAGE).to_i
  end

  def active?
    (inactive_since.blank? || inactive_since >= Time.now) && created_at <= Time.now
  end

  def toggle_active!(time = Time.now)
    update!(inactive_since: active? ? time : nil)
  end

  def stats
    {
      yes_votes: votes.yes.count,
      no_votes: votes.no.count,
      agreed: agreed.count,
      disagreed: disagreed.count,
      averages: Vote.metrics(votes)
    }.with_indifferent_access
  end

  def email
    "#{username}@#{ENV['DOMAIN']}"
  end

  def slack_name
    cached { "@#{slack_user.name}" } if slack_user.present?
  end

  def send!(message)
    slack_send! slack_id, message
  end

  def name
    slack_or_block :real_name do
      trello_user.try(:full_name).present? ? trello_user.full_name : cached_name
    end
  end

  def first_name
    slack_or_block(:first_name) { name.split(' ').first }
  end

  def last_name
    slack_or_block(:last_name) { name.split(' ').drop(1).join(' ') }
  end

  def initials
    cached { trello_user.try(:initials) || "#{first_name.first}#{last_name.first}" }
  end

  def title
    slack_or_block :title
  end

  def ensure_token
    authentication_token || Devise.friendly_token.tap do |token|
      update! authentication_token: token
    end
  end

  def self.from_omniauth(auth)
    from_email(auth.info.email)&.tap do |user|
      user.update! access_token: auth.credentials.token, refresh_token: auth.credentials.refresh_token
    end
  end

  def self.from_slack(slack_id)
    user = where(slack_id: slack_id).first
    return user if user.present?

    user = slack_client_factory.users_info(user: slack_id).user
    from_email user.profile.email
  rescue Slack::Web::Api::Error
    nil
  end

  def self.from_trello(trello_id)
    user = where(trello_id: trello_id).first
    return user if user.present?

    user = Trello::Member.find trello_id
    if user.email.present?
      from_email user.email
    else
      where(cached_name: user.full_name).or(where(username: user.username)).first
    end
  rescue Trello::Error
    nil
  end

  def self.from_email(email)
    from_username_domain *email.split('@')
  end

  def self.from_username_domain(username, domain)
    return nil unless domain == ENV['DOMAIN']
    where(username: username).first_or_create!
  end

  def self.from_multi(multi)
    Array.wrap(multi).map do |item|
      return item if item.is_a?(User) || item.is_a?(Team)
      return find(item) if item.is_a?(Integer)
      return where(username: item).first if item.is_a?(String)
    end.compact
  end

  def trello_user
    @trello_user ||= find_trello_user.tap do |user|
      if user.present?
        self.trello_id = user.id
        save! if changed?
      end
    end
  end

  def find_trello_user
    [trello_id, email, username, slack_user&.name].each do |query|
      next unless query.present?
      user = begin
        Trello::Member.find(query)
      rescue Trello::Error, SystemStackError
        nil
      end
      return user if user.present?
    end
    nil
  end

  def as_json(options = {})
    options.reverse_merge!(
      only: [:username, :inactive_since, :trello_id, :slack_id]
    )
    super(options).merge(
      name: cached_name,
      team: team.name
    )
  end

  def admin?
    username == ENV['ADMIN']
  end

  private

  def add_to_wit
    Http::Wit::Entity.new('slack_user').add_value("<@#{slack_id}>") if slack_id.present?
  end

  def set_cached_name
    self.cached_name ||= name || username
  end

  def set_slack_id
    self.slack_id ||= begin
      members = slack_client.users_search(user: email).members
      members = slack_client.users_search(user: username).members unless members.present?
      members.first
    end.try(:id)
  end

  def slack_or_block(property)
    key_cached [property] do
      from_slack = slack_user&.profile&.public_send(property)
      if from_slack.present?
        from_slack.titleize
      else
        yield if block_given?
      end
    end
  end

  def slack_user
    @slack_user ||= slack_client.users_info(user: slack_id).user if slack_id.present?
  end

  def agreed
    @agreed ||= company_votes.select { |c, v| c.funded? == v.yes? }
  end

  def disagreed
    @disagreed ||= company_votes.except(agreed.keys)
  end

  def company_votes
    @company_votes ||= votes.includes(:company).final.map { |vote| [vote.company, vote] }.to_h
  end
end
