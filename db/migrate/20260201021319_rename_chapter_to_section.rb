class RenameChapterToSection < ActiveRecord::Migration[8.2]
  def up
    # Rename sections table to text_blocks (old Section model -> TextBlock)
    rename_table :sections, :text_blocks

    # Rename chapters table to sections (old Chapter model -> Section)
    rename_table :chapters, :sections

    # Rename chapterable columns in sections table
    rename_column :sections, :chapterable_id, :sectionable_id
    rename_column :sections, :chapterable_type, :sectionable_type

    # Rename chapter_id in edits table to section_id
    rename_column :edits, :chapter_id, :section_id

    # Rename chapterable columns in edits table
    rename_column :edits, :chapterable_id, :sectionable_id
    rename_column :edits, :chapterable_type, :sectionable_type

    # Update polymorphic type values
    execute <<-SQL
      UPDATE sections SET sectionable_type = 'TextBlock' WHERE sectionable_type = 'Section';
    SQL

    execute <<-SQL
      UPDATE edits SET sectionable_type = 'TextBlock' WHERE sectionable_type = 'Section';
    SQL

    # Recreate the search index with new name
    execute "DROP TABLE IF EXISTS chapter_search_index;"
    execute <<-SQL
      CREATE VIRTUAL TABLE section_search_index USING fts5(title, content, tokenize='porter');
    SQL
  end

  def down
    # Recreate the old search index
    execute "DROP TABLE IF EXISTS section_search_index;"
    execute <<-SQL
      CREATE VIRTUAL TABLE chapter_search_index USING fts5(title, content, tokenize='porter');
    SQL

    # Revert polymorphic type values
    execute <<-SQL
      UPDATE sections SET sectionable_type = 'Section' WHERE sectionable_type = 'TextBlock';
    SQL

    execute <<-SQL
      UPDATE edits SET sectionable_type = 'Section' WHERE sectionable_type = 'TextBlock';
    SQL

    # Rename columns back
    rename_column :edits, :sectionable_type, :chapterable_type
    rename_column :edits, :sectionable_id, :chapterable_id
    rename_column :edits, :section_id, :chapter_id

    rename_column :sections, :sectionable_type, :chapterable_type
    rename_column :sections, :sectionable_id, :chapterable_id

    # Rename tables back
    rename_table :sections, :chapters
    rename_table :text_blocks, :sections
  end
end
