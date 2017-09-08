class News < ApplicationRecord
  belongs_to :investor
  belongs_to :company

  validates :investor, presence: true
  validates :url, presence: true, uniqueness: { scope: [:investor] }
  validates :title, presence: true
  validates :description, presence: true

  before_validation :set_meta!, on: :create

  def page
    @page ||= MetaInspector.new(url, download_images: false)
  end

  def as_json(options = {})
    super options.reverse_merge(only: [:title, :url, :description])
  end

  private

  def set_meta!
    self.title ||= page.best_title
    self.description ||= page.best_description
  end
end
