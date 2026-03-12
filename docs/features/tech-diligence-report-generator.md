# Tech Diligence Report Generator

A document analysis system that uses vision-language models (VLMs) to extract technical specifications from PDFs with full provenance tracking.

## Overview

The Tech Diligence Report Generator processes PDF documents by:
1. Extracting text from each page
2. Converting each page to a high-quality image for VLM analysis
3. Using GPT-4o vision to analyze both text and visual content (diagrams, tables, schematics)
4. Tracking provenance (source document, page number, relevant text) for every claim

## Components

### PDF Processing Pipeline

**PdfImageExtractor** (`app/services/pdf_image_extractor.rb`)
- Converts PDF pages to PNG images using `pdftoppm` (poppler-utils)
- 150 DPI for good quality while keeping file sizes manageable
- Supports single page or batch extraction

**DocumentProcessingJob** (`app/jobs/document_processing_job.rb`)
- Extracts text using `pdf-reader` gem
- Generates page images and stores as Active Storage blobs
- Stores references in `page_images` JSON column: `{ "1" => "signed_blob_id", ... }`

### TechDiligenceAgent

**Agent** (`app/agents/tech_diligence_agent.rb`)
- Inherits from `ApplicationAgent` with `has_context` for provenance tracking
- Supports vision API via `api_version: :chat`
- Four main actions:
  - `answer_questions` - Answer specific technical questions
  - `analyze_pages` - Deep analysis of specific pages
  - `extract_specs` - Extract structured specifications
  - `verify_claims` - Verify claims against document evidence

**Views** (`app/views/tech_diligence_agent/`)
- `answer_questions.text.erb` - Q&A prompt with citation requirements
- `analyze_pages.text.erb` - Page analysis prompt
- `extract_specs.text.erb` - Structured spec extraction
- `verify_claims.text.erb` - Claim verification prompt

### Provenance Tracking

**AgentFragment** (`app/models/agent_fragment.rb`)
- New fragment types: `citation`, `spec_extraction`
- Metadata JSON includes:
  - `page_number` - Source page
  - `source_document` - Document filename
  - `confidence` - Extraction confidence score
- Scopes: `citations`, `with_page_reference(page_num)`

## API Endpoints

```
POST /assistants/tech_diligence/questions
  document_id: integer (required)
  questions: array of strings
  use_vision: boolean (default: true)

POST /assistants/tech_diligence/pages
  document_id: integer (required)
  page_numbers: array of integers
  focus_areas: array of strings

POST /assistants/tech_diligence/specs
  document_id: integer (required)
  spec_categories: array (default: [cpu, memory, storage, connectivity, power])

POST /assistants/tech_diligence/verify
  document_id: integer (required)
  claims: array of strings
```

All endpoints return `{ stream_id: string }` for ActionCable streaming.

## Usage

### CLI Testing

```bash
# Process a PDF (extract text + page images)
rake tech_diligence:process_pdf[/path/to/motherboard_manual.pdf]

# Ask questions about a document
rake tech_diligence:ask[123,"What is the CPU socket type?"]

# Extract all specifications
rake tech_diligence:extract_specs[123]

# Run full test suite with example questions
rake tech_diligence:test_motherboard[123]
```

### Programmatic Usage

```ruby
# Load and process a document
document = Document.find(123)

# Ask questions with vision
agent = TechDiligenceAgent.with(
  document: document,
  questions: [
    "What is the CPU socket type?",
    "What is the maximum RAM speed?",
    "Does it have optical audio?"
  ],
  use_vision: true
)

response = agent.answer_questions.generate
puts response.message.content

# Check provenance
agent.context.fragments.citations.each do |citation|
  puts "Page #{citation.source_page_number}: #{citation.generated_content}"
end
```

## Citation Format

The agent is instructed to cite sources in a parseable format:

```
The CPU socket type is LGA 1700 [Source: motherboard_manual.pdf, Page 12]
```

These citations are automatically parsed and stored as `AgentFragment` records with full metadata.

## Requirements

- `pdftoppm` (from poppler-utils): `brew install poppler`
- `pdf-reader` gem (already in Gemfile)
- `image_processing` gem (already in Gemfile)
- OpenAI API key with GPT-4o vision access

## Future Enhancements

1. **Line-level provenance** - Track specific line numbers within pages
2. **Confidence scoring** - ML-based confidence for extracted claims
3. **Multi-document analysis** - Compare specs across multiple documents
4. **Export to structured formats** - JSON, CSV, or custom report templates
