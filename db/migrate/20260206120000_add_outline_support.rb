class AddOutlineSupport < ActiveRecord::Migration[8.2]
  def change
    # Parsed outline structure (sections, headings, key points)
    add_column :sources, :structured_content, :json, default: {}

    # Track whether AI generation used outline context
    add_column :agent_fragments, :outline_source_id, :integer
    add_column :agent_fragments, :outline_match_data, :json, default: {}
    add_index :agent_fragments, :outline_source_id
    add_foreign_key :agent_fragments, :sources, column: :outline_source_id, on_delete: :nullify

    # Store AI reasoning for diff recommendations (rendered in data-reason HTML attribute)
    add_column :suggestions, :reasoning, :text
    add_column :suggestions, :source_category, :string
    add_index :suggestions, :source_category
  end
end
