class ProjectTemplatesController < ApplicationController
  before_action :set_project_template, only: %i[show edit update destroy preview create_report]

  def index
    @project_templates = ProjectTemplate.available_to(Current.user).ordered
    @my_templates = @project_templates.owned_by(Current.user)
    @shared_templates = @project_templates.shared.where.not(created_by: Current.user)
  end

  def show
  end

  def new
    @project_template = ProjectTemplate.new(
      section_schema: default_section_schema,
      theme: "blue",
      shared: true
    )
  end

  def edit
  end

  def create
    @project_template = ProjectTemplate.new(project_template_params)
    @project_template.created_by = Current.user

    if @project_template.save
      redirect_to @project_template, notice: "Template created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project_template.update(project_template_params)
      redirect_to @project_template, notice: "Template updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project_template.destroy
    redirect_to project_templates_path, notice: "Template deleted."
  end

  def preview
    # Preview what a report would look like from this template
    @preview_sections = @project_template.section_schema
  end

  def create_report
    title = params[:report_title].presence || "New #{@project_template.name}"

    @report = @project_template.generate_report(
      title: title,
      user: Current.user
    )

    # Grant access to the creator
    @report.update_access(editors: [Current.user.id], readers: [])

    redirect_to @report, notice: "Report created from template. Upload documents to begin."
  end

  private

  def set_project_template
    @project_template = ProjectTemplate.available_to(Current.user).find(params[:id])
  end

  def project_template_params
    params.require(:project_template).permit(
      :name,
      :description,
      :ai_instructions,
      :theme,
      :shared,
      section_schema: [:title, :type, :instructions, :placeholder, :required, :multiple]
    )
  end

  def default_section_schema
    [
      {
        "title" => "Executive Summary",
        "type" => "Page",
        "instructions" => "Write a concise executive summary covering key findings.",
        "placeholder" => "",
        "required" => true
      }
    ]
  end
end
