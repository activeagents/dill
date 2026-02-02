module Section::Editable
  extend ActiveSupport::Concern

  MINIMUM_TIME_BETWEEN_VERSIONS = 10.minutes

  included do
    has_many :edits, dependent: :delete_all

    after_update :record_moved_to_trash, if: :was_trashed?
  end

  def edit(sectionable_params: {}, section_params: {})
    if record_new_edit?(sectionable_params)
      update_and_record_edit section_params, sectionable_params
    else
      update_without_recording_edit section_params, sectionable_params
    end
  end

  private
    def record_new_edit?(sectionable_params)
      will_change_sectionable?(sectionable_params) && last_edit_old?
    end

    def last_edit_old?
      edits.empty? || edits.last.created_at.before?(MINIMUM_TIME_BETWEEN_VERSIONS.ago)
    end

    def will_change_sectionable?(sectionable_params)
      sectionable_params.select do |key, value|
        sectionable.attributes[key.to_s] != value
      end.present?
    end

    def update_without_recording_edit(section_params, sectionable_params)
      transaction do
        sectionable.update!(sectionable_params)

        edits.last&.touch
        update! section_params
      end
    end

    def update_and_record_edit(section_params, sectionable_params)
      transaction do
        new_sectionable = dup_sectionable_with_attachments sectionable
        new_sectionable.update!(sectionable_params)

        edits.revision.create!(sectionable: sectionable)
        update! section_params.merge(sectionable: new_sectionable)
      end
    end

    def dup_sectionable_with_attachments(sectionable)
      sectionable.dup.tap do |new|
        sectionable.attachment_reflections.each do |name, _|
          new.send(name).attach(sectionable.send(name).blob)
        end
      end
    end

    def record_moved_to_trash
      edits.trash.create!(sectionable: sectionable)
    end

    def was_trashed?
      trashed? && previous_changes.include?(:status)
    end
end
