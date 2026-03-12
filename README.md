# Dill

AI-powered due diligence platform with document analysis powered by [ActiveAgent](https://github.com/activeagents/activeagent).

## Features

- **Document Analysis** - Upload PDFs and get AI-powered analysis
- **Tech Diligence Reports** - Automated technical due diligence report generation
- **Writing Assistant** - Improve, grammar check, summarize, expand, and brainstorm content
- **Research Assistant** - Autonomous web research with browser automation
- **Real-time Streaming** - Live AI responses via ActionCable
- **Context Persistence** - Full audit trail of AI interactions stored in the database

## AI Agent Architecture

### Core Dependencies

```ruby
# Gemfile
gem "activeagent", "~> 1.0.1"   # Agent framework (like ActionMailer for AI)
gem "solid_agent", "~> 0.1.1"   # Database persistence & tool DSL
```

### Agent Structure

```
app/
├── agents/
│   ├── application_agent.rb         # Base agent with shared concerns
│   ├── writing_assistant_agent.rb   # Writing improvement features
│   ├── research_assistant_agent.rb  # Web research with browser tools
│   ├── file_analyzer_agent.rb       # PDF/image analysis
│   └── tech_diligence_agent.rb      # Technical due diligence reports
├── models/
│   ├── agent_context.rb             # Conversation/session storage
│   ├── agent_message.rb             # Individual messages
│   └── agent_generation.rb          # AI response metadata & tokens
└── views/
    ├── writing_assistant_agent/     # Prompt templates
    ├── research_assistant_agent/    # Includes tools/*.json.erb
    ├── file_analyzer_agent/
    └── tech_diligence_agent/
```

## Setup

### 1. Install Dependencies

```bash
bundle install
```

### 2. Configure API Keys

Add to your environment or Rails credentials:

```bash
# .env or environment variables
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key  # Optional
```

### 3. Database Setup

Run migrations for agent context tables:

```bash
bin/rails db:migrate
```

### 4. Start the Server

```bash
bin/dev
```

## Documentation

- [Active Agents Integration](docs/active-agents-integration.md) - Detailed implementation guide
- [Tech Diligence Report Generator](docs/features/tech-diligence-report-generator.md) - Document analysis feature
- [Claude Integration Guide](docs/CLAUDE.md) - Agent development patterns

## License

MIT License
