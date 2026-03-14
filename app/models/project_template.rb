class ProjectTemplate < ApplicationRecord
  belongs_to :created_by, class_name: "User"

  validates :name, presence: true
  validates :section_schema, presence: true

  scope :shared, -> { where(shared: true) }
  scope :owned_by, ->(user) { where(created_by: user) }
  scope :available_to, ->(user) { shared.or(owned_by(user)) }
  scope :ordered, -> { order(:name) }

  # Available themes (matches Report)
  THEMES = %w[black blue green magenta orange violet white].freeze

  # Generate a new report from this template
  def generate_report(title:, user:)
    report = Report.create!(
      title: title,
      theme: theme
    )

    # Create sections from schema
    section_schema.each_with_index do |section_def, index|
      sectionable = create_sectionable(section_def)
      report.press(sectionable, {
        title: section_def["title"],
        status: "active",
        position_score: index
      })
    end

    report
  end

  # Extract template schema from an existing report
  def self.from_report(report, name:, user:)
    schema = report.sections.ordered.map do |section|
      {
        "title" => section.title,
        "type" => section.sectionable_type,
        "instructions" => "",
        "placeholder" => extract_placeholder(section.sectionable),
        "required" => true
      }
    end

    new(
      name: name,
      description: "Template created from #{report.title}",
      section_schema: schema,
      theme: report.theme,
      created_by: user,
      shared: false
    )
  end

  private

  def create_sectionable(section_def)
    type = section_def["type"] || "Page"
    placeholder = section_def["placeholder"] || ""

    case type
    when "Page"
      Page.create!(body: placeholder)
    when "TextBlock"
      TextBlock.create!(plain_text: placeholder)
    when "Finding"
      Finding.create!(
        description: placeholder,
        severity: "medium",
        status: "open",
        category: "other"
      )
    when "Picture"
      Picture.create!
    when "Document"
      Document.create!
    else
      Page.create!(body: placeholder)
    end
  end

  def self.extract_placeholder(sectionable)
    case sectionable
    when Page
      sectionable.body.presence || ""
    when TextBlock
      sectionable.plain_text.presence || ""
    when Finding
      sectionable.description.presence || ""
    else
      ""
    end
  end
end
