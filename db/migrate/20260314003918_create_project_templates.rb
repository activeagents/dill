class CreateProjectTemplates < ActiveRecord::Migration[8.2]
  def change
    create_table :project_templates do |t|
      t.string :name, null: false
      t.text :description
      t.text :ai_instructions
      t.json :section_schema, default: []
      t.string :theme, default: "blue"
      t.boolean :shared, default: true, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :project_templates, :shared
  end
end
