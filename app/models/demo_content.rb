class DemoContent
  class << self
    def create_manual(user)
      report = create_report(user)
      load_markdown_pages(report)
    end

    private
      def create_report(user)
        Report.create(title: "The Dill Manual", everyone_access: true).tap do |report|
          with_attachment("dill-manual.jpg") { |attachment| report.cover.attach(attachment) }
          report.update_access(readers: [], editors: [ user.id ])
        end
      end

      def load_markdown_pages(report)
        pages = {}

        Dir.glob(Rails.root.join("app/assets/markdown/demo/*.md")).each do |fname|
          front_matter = FrontMatterParser::Parser.parse_file(fname)

          if front_matter["class"] == "Section"
            load_section(report, front_matter)
          else
            page = load_markdown_page(report, front_matter)
            attach_images(page)
            pages[page.section.slug] = page
          end
        end

        report.sections.each do |section|
          next unless section.page?
          localize_ref_links(section.page, pages)
        end
      end

      def load_markdown_page(report, front_matter)
        report.press(Page.new(body: front_matter.content), title: front_matter["title"]).page
      end

      def load_section(report, front_matter)
        report.press TextBlock.new(body: front_matter.content, theme: front_matter["theme"]), title: front_matter["title"]
      end

      def attach_images(page)
        re = %r{
          \/u\/           # leading portion of path
          (\S+-\w+\.\w+)  # filename including slug and extension
        }x

        body = page.body.content.gsub(re) do |match|
          with_attachment($1) { |attachment| page.body.uploads.attach(attachment) }

          attachment = page.body.uploads.attachments.last
          attachment.analyze

          "/u/" + attachment.slug
        end

        page.update!(body: body)
      end

      def localize_ref_links(page, pages)
        re = %r{
          (\[.+\])              # link title
          \(                    # opening paren
          \/\d+\/[\w-]+\/\d+\/  # leading portion of path
          ([\w-]+)              # section slug
        }x

        body = page.body.content.gsub(re) do |match|
          link_title, section_slug, anchor = $1, $2, $3
          linked_page = pages[section_slug]
          raise "Invalid reference link: #{section_slug}" unless linked_page.present?

          url = Rails.application.routes.url_helpers.sectionable_slug_path(linked_page.section, anchor: anchor, only_path: true)

          "#{link_title}(#{url}"
        end

        page.update!(body: body)
      end

      def with_attachment(filename)
        File.open(Rails.root.join("app/assets/images/demo/#{filename}")) do |file|
          yield io: file, filename: filename
        end
      end
  end
end
