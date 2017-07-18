module Concerns
  module AttributeSortable
    extend ActiveSupport::Concern

    included do
      @sorted_attributes = []

      before_save :sort_sortables
    end

    class_methods do
      def sort(name)
        @sorted_attributes << name
      end

      def sorted_attributes
        @sorted_attributes
      end
    end

    def sort_sortables
      self.class.sorted_attributes.each do |attr|
        next unless self[attr].present?
        self[attr] = self[attr].sort
      end
    end
  end
end