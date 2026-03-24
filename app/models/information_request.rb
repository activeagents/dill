class InformationRequest < ApplicationRecord
  belongs_to :report
  belongs_to :section, optional: true

  enum :status, {
    pending: 0,
    sent: 1,
    received: 2,
    not_applicable: 3
  }, default: :pending

  enum :priority, {
    critical: 0,
    high: 1,
    medium: 2,
    low: 3
  }, default: :medium

  CATEGORIES = %w[technical financial legal operational compliance other].freeze

  validates :question, presence: true
  validates :category, inclusion: { in: CATEGORIES, allow_blank: true }

  scope :pending, -> { where(status: :pending) }
  scope :outstanding, -> { where(status: [:pending, :sent]) }
  scope :by_priority, -> { order(:priority) }
  scope :by_due_date, -> { order(:due_date) }
  scope :overdue, -> { where("due_date < ?", Date.current).outstanding }

  # Mark as sent (e.g., when exported or emailed to target)
  def mark_sent!
    update!(status: :sent)
  end

  # Mark as received when answer arrives
  def mark_received!(notes: nil)
    update!(status: :received, notes: notes)
  end

  # Mark as not applicable (question no longer needed)
  def mark_not_applicable!(reason: nil)
    update!(status: :not_applicable, notes: reason)
  end

  # Check if overdue
  def overdue?
    due_date.present? && due_date < Date.current && outstanding?
  end

  # Check if outstanding (not yet resolved)
  def outstanding?
    pending? || sent?
  end

  # Format for export
  def to_export_format
    {
      question: question,
      category: category,
      priority: priority,
      expected_response: expected_response,
      due_date: due_date&.to_s,
      section: section&.title
    }
  end
end
