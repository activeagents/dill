class CreateInformationRequests < ActiveRecord::Migration[8.2]
  def change
    create_table :information_requests do |t|
      t.references :report, null: false, foreign_key: true
      t.references :section, null: true, foreign_key: true
      t.text :question, null: false
      t.string :expected_response
      t.integer :status, default: 0, null: false
      t.integer :priority, default: 2, null: false
      t.text :notes
      t.date :due_date
      t.string :category  # e.g., "technical", "financial", "legal"

      t.timestamps
    end

    add_index :information_requests, :status
    add_index :information_requests, :priority
  end
end
