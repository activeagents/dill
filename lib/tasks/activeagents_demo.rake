# frozen_string_literal: true

namespace :demo do
  desc "Generate ActiveAgents.ai Technical Due Diligence Report demo"
  task activeagents: :environment do
    puts "Generating ActiveAgents.ai Tech DD Demo Report..."
    puts ""

    # Find or use specified user
    user = if ENV["USER_EMAIL"]
      User.find_by!(email_address: ENV["USER_EMAIL"])
    else
      User.find_by(email_address: "justin@activeagents.ai") || User.first
    end

    puts "User: #{user.email_address}"
    puts ""

    # Generate the report
    report = ActiveAgentsDemoContent.generate(user: user)

    puts "Report created successfully!"
    puts ""
    puts "  Title: #{report.title}"
    puts "  Subtitle: #{report.subtitle}"
    puts "  Sections: #{report.sections.count}"
    puts "  URL: /#{report.slug}"
    puts ""

    # Summary of sections
    puts "Sections:"
    report.sections.each_with_index do |section, i|
      type = section.sectionable_type.underscore.humanize
      severity = section.finding? ? " (#{section.finding.severity})" : ""
      puts "  #{i + 1}. [#{type}] #{section.title}#{severity}"
    end
    puts ""

    puts "Done! View the report at: http://localhost:3000/#{report.slug}"
  end

  desc "Regenerate Mermaid diagrams for ActiveAgents demo"
  task activeagents_diagrams: :environment do
    diagram_dir = Rails.root.join("tmp/diagrams/activeagents_demo")

    unless Dir.exist?(diagram_dir)
      puts "Diagram directory not found: #{diagram_dir}"
      puts "Please create .mmd files first."
      exit 1
    end

    mmd_files = Dir.glob(diagram_dir.join("*.mmd"))

    if mmd_files.empty?
      puts "No .mmd files found in #{diagram_dir}"
      exit 1
    end

    puts "Regenerating #{mmd_files.count} diagrams..."
    puts ""

    mmd_files.each do |mmd_file|
      png_file = mmd_file.sub(".mmd", ".png")
      basename = File.basename(mmd_file)

      print "  #{basename} -> #{File.basename(png_file)}..."

      result = system("mmdc -i #{mmd_file} -o #{png_file} -t dark -b transparent -w 1500 -H 1000 2>/dev/null")

      if result && File.exist?(png_file)
        size_kb = (File.size(png_file) / 1024.0).round(1)
        puts " OK (#{size_kb} KB)"
      else
        puts " FAILED"
      end
    end

    puts ""
    puts "Done!"
  end

  desc "Clean up ActiveAgents demo report(s)"
  task activeagents_clean: :environment do
    reports = Report.where("title LIKE ?", "%ActiveAgents%")

    if reports.empty?
      puts "No ActiveAgents demo reports found."
      exit 0
    end

    puts "Found #{reports.count} ActiveAgents demo report(s):"
    reports.each do |report|
      puts "  - #{report.title} (#{report.sections.count} sections)"
    end

    print "\nDelete these reports? [y/N] "
    response = $stdin.gets&.chomp&.downcase

    if response == "y"
      reports.destroy_all
      puts "Deleted!"
    else
      puts "Cancelled."
    end
  end
end
