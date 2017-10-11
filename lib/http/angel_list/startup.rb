module Http::AngelList
  class Startup < Base
    def logo
      return nil unless found?
      return nil if @data['logo_url'] == 'https://angel.co/images/shared/nopic_startup.png'
      @data['logo_url']
    end

    def url
      url = @data['company_url'] if found?
      url if url.present? && !url.include?('google.com')
    end

    def description
      (@data['high_concept'] ? "#{@data['high_concept']}." : '') + (@data['product_desc'] || '') if found?
    end

    def markets
      return [] unless found? && @data['markets'].present?
      @markets ||= @data['markets'].map { |m| Competitor.closest_industry(m['display_name']) }.compact
    end

    def investments
      return [] unless found?
      @investments ||= fetch_roles!(direction: 'outgoing')
    end
  end
end
