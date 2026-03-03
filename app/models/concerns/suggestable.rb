module Suggestable
  extend ActiveSupport::Concern

  included do
    has_many :suggestions, as: :suggestable, dependent: :destroy
  end

  def pending_suggestions
    suggestions.pending.ordered
  end

  def pending_suggestions_count
    suggestions.pending.count
  end

  def has_pending_suggestions?
    suggestions.pending.exists?
  end

  def create_suggestion(type:, original_text: nil, suggested_text: nil, comment: nil, author: nil, ai_generated: false, start_offset: nil, end_offset: nil)
    suggestions.create!(
      suggestion_type: type,
      original_text: original_text,
      suggested_text: suggested_text,
      comment: comment,
      author: author,
      ai_generated: ai_generated,
      start_offset: start_offset,
      end_offset: end_offset
    )
  end

  def apply_suggestion(suggestion)
    return false unless suggestion.pending?
    return false unless suggestion.suggestable == self

    transaction do
      applied = case suggestion.suggestion_type
      when "edit"
        apply_edit(suggestion)
      when "delete"
        apply_delete(suggestion)
      when "add"
        apply_add(suggestion)
      when "comment"
        true # Comments don't modify content, just mark as accepted
      else
        false
      end

      return false unless applied
      suggestion.accept!
    end

    true
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved
    false
  end

  private

  def apply_edit(suggestion)
    return false if suggestion.original_text.blank? || suggestion.suggested_text.blank?

    with_lock do
      content = suggestable_content
      return false unless content&.include?(suggestion.original_text)
      update_suggestable_content(content.sub(suggestion.original_text, suggestion.suggested_text))
    end
  end

  def apply_delete(suggestion)
    return false if suggestion.original_text.blank?

    with_lock do
      content = suggestable_content
      return false unless content&.include?(suggestion.original_text)
      update_suggestable_content(content.sub(suggestion.original_text, ""))
    end
  end

  def apply_add(suggestion)
    return false if suggestion.suggested_text.blank?

    with_lock do
      content = suggestable_content || ""
      update_suggestable_content(content + "\n\n" + suggestion.suggested_text)
    end
  end

  # Override in including classes for model-specific content access
  def suggestable_content
    nil
  end

  def update_suggestable_content(_new_content)
    false
  end
end
