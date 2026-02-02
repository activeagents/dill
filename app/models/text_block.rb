class TextBlock < ApplicationRecord
  include Sectionable

  def searchable_content
    body
  end
end
