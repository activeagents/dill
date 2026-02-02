class Edit < ApplicationRecord
  belongs_to :section
  delegated_type :sectionable, types: Sectionable::TYPES, dependent: :destroy

  enum :action, %w[ revision trash ].index_by(&:itself)

  scope :sorted, -> { order(created_at: :desc) }
  scope :before, ->(edit) { where("created_at < ?", edit.created_at) }
  scope :after, ->(edit) { where("created_at > ?", edit.created_at) }

  def previous
    section.edits.before(self).last
  end

  def next
    section.edits.after(self).first
  end
end
