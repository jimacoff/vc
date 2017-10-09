class News < ApplicationRecord
  belongs_to :investor
  belongs_to :company

  validates :url, presence: true, uniqueness: { scope: [:investor, :company] }
  validates :title, presence: true
  validates :description, presence: true

  before_validation :set_meta!, on: :create

  attr_accessor :body

  def as_json(options = {})
    super options.reverse_merge(only: [:title, :url, :description, :published_at])
  end

  def page
    @page ||= begin
      if @body.present?
        MetaInspector.new(url, document: @body)
      else
        MetaInspector.new(url, download_images: false).tap do |page|
          raise ActiveRecord::RecordInvalid.new(self) unless page.response.status == 200
          @body = Util.fix_encoding(page.to_s)
        end
      end
    end
  rescue MetaInspector::Error
    raise ActiveRecord::RecordInvalid.new(self)
  end

  def sentiment
    @sentiment ||= GoogleCloud::Language.new(body, format: :html).sentiment if body.present?
  end

  def self.create_with_body(url, body, attrs = {})
    where(attrs.merge(url: url)).first_or_initialize.tap do |news|
      news.body = body
      news.save!
    end
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private

  def set_meta!
    self.title ||= page.best_title
    self.description ||= page.best_description
    self.sentiment_score ||= sentiment&.score
    self.sentiment_magnitude ||= sentiment&.magnitude

    self.title = CGI.unescapeHTML(self.title) if self.title.present?
  end
end
