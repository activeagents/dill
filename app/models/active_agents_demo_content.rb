# frozen_string_literal: true

# Generates a demo Technical Due Diligence report for ActiveAgents.ai
# This creates a recursive showcase: Dill (built on ActiveAgents) analyzing ActiveAgents
#
# Usage:
#   ActiveAgentsDemoContent.generate(user: User.first)
#   # or via rake task:
#   bin/rails demo:activeagents
#
class ActiveAgentsDemoContent
  DIAGRAM_DIR = "tmp/diagrams/activeagents_demo"

  class << self
    def generate(user:)
      report = create_report(user)
      create_sections(report)
      report
    end

    private

    def create_report(user)
      Report.create!(
        title: "Technical Due Diligence: ActiveAgents.ai",
        subtitle: "AI Framework Assessment - Dill.vc Demo",
        theme: "blue"
      ).tap do |report|
        report.update_access(readers: [], editors: [ user.id ])
      end
    end

    def create_sections(report)
      create_executive_summary(report)
      create_architecture_section(report)
      create_data_flow_section(report)
      create_database_section(report)
      create_deployment_section(report)
      create_dill_integration_section(report)
      create_security_findings(report)
      create_code_quality_section(report)
      create_scalability_section(report)
      create_risk_findings(report)
      create_recommendations(report)
    end

    # === Executive Summary ===
    def create_executive_summary(report)
      body = <<~MARKDOWN
        ## Executive Summary

        **Company:** ActiveAgents.ai
        **Product:** ActiveAgent - Rails AI Framework
        **Assessment Date:** #{Date.today.strftime("%B %Y")}
        **Assessor:** Dill.vc Technical Due Diligence Platform

        ### Overview

        ActiveAgents.ai provides an open-source AI agent framework for Ruby on Rails applications. The framework follows Rails conventions ("The Rails Way") by treating agents like controllers, prompts like views, and leveraging existing Rails patterns for configuration and organization.

        ### Key Findings Summary

        | Category | Assessment | Risk Level |
        |----------|------------|------------|
        | Architecture | Production-ready, well-structured | **Low** |
        | Security | Standard practices, room for hardening | **Medium** |
        | Scalability | Horizontally scalable with considerations | **Medium** |
        | Code Quality | Clean, follows Rails conventions | **Low** |
        | Documentation | Good coverage, comprehensive guides | **Low** |

        ### Business Model

        ActiveAgents.ai employs a freemium-to-enterprise escalation model:

        - **Open Source Core** (MIT License): Base framework, multi-provider support
        - **ActiveAgent.PRO** ($99/month): Advanced workflows, versioning, generative UI
        - **ActiveAgent Enterprise** ($269+/month): Multi-app deployment, priority support
        - **Hosted Platform**: Self-hosted (free) → Pro ($99/mo) → Enterprise ($2,000+/year)
        - **Professional Services**: Workshops ($2,500-$4,500), Advisory ($3,000+/month)

        ### Meta-Note

        > **This report was generated using Dill.vc, which is itself powered by ActiveAgent.**
        > This demonstrates the framework's production readiness - we use it daily to generate
        > technical due diligence reports like this one.

        ### Investment Recommendation

        **Proceed with standard diligence** - The technology is sound and production-proven. The recursive demonstration (Dill using ActiveAgent to analyze ActiveAgent) provides strong evidence of real-world viability. Key considerations include LLM provider dependency and open-source sustainability.
      MARKDOWN

      report.press(Page.new(body: body), title: "Executive Summary")
    end

    # === Technical Architecture ===
    def create_architecture_section(report)
      body = <<~MARKDOWN
        ## Technical Architecture Analysis

        ### Framework Design Philosophy

        ActiveAgent follows the principle that **"Agents are Controllers"** - developers leverage existing Rails knowledge to build AI-powered systems:

        - **Actions** become agent methods
        - **Views** become prompt templates (ERB)
        - **Callbacks** provide lifecycle hooks
        - **Configuration** uses Rails patterns (YAML, credentials)

        ### Core Components

        #### 1. ActiveAgent::Base
        The superclass for all agents, providing:
        - Multi-provider LLM support (OpenAI, Anthropic, Ollama, OpenRouter)
        - Prompt rendering via Action View
        - Streaming response handling
        - Tool/function calling DSL

        #### 2. Generation Providers
        Abstraction layer over LLM APIs with:
        - Unified interface across providers
        - Provider-specific optimizations
        - Automatic retry with exponential backoff
        - Token usage tracking

        #### 3. Tool System
        Declarative tool registration enabling:
        - JSON Schema-based function definitions
        - Automatic argument parsing
        - Tool result formatting
        - Multi-turn tool conversations

        #### 4. SolidAgent Extensions
        Database persistence layer adding:
        - `HasContext`: Full conversation persistence
        - `HasTools`: Tool registration DSL
        - `StreamsToolUpdates`: Real-time broadcasting

        ### Architecture Strengths

        1. **Rails-Native**: No foreign abstractions; leverages existing Rails ecosystem
        2. **Provider Agnostic**: Switch LLMs with configuration changes
        3. **Production-Ready**: Built-in streaming, retries, and observability
        4. **Extensible**: Clean inheritance model for customization
      MARKDOWN

      report.press(Page.new(body: body), title: "Technical Architecture Analysis")
      create_picture(report, "system_architecture.png", "System Architecture Diagram")
    end

    # === Data Flow ===
    def create_data_flow_section(report)
      body = <<~MARKDOWN
        ## Data Flow & Request Lifecycle

        ### Request Processing Pipeline

        The following sequence illustrates a typical agent request:

        1. **Request Initiation**: Controller receives HTTP request
        2. **Agent Instantiation**: `AgentClass.with(params).action`
        3. **Prompt Composition**: ERB template rendered with context
        4. **Context Persistence**: AgentContext created in database
        5. **LLM Generation**: Provider sends request to LLM API
        6. **Streaming Response**: Tokens broadcast via ActionCable
        7. **Tool Execution** (optional): Function calls handled, results returned
        8. **Response Storage**: Messages and generations persisted
        9. **Final Response**: Rendered result returned to client

        ### Streaming Architecture

        ActiveAgent supports real-time streaming through:

        ```ruby
        class MyAgent < ApplicationAgent
          on_stream :broadcast_chunk
          on_stream_close :broadcast_complete

          def analyze
            prompt(tools: tools, stream: true)
          end

          private

          def broadcast_chunk(chunk)
            ActionCable.server.broadcast(stream_id, { content: chunk })
          end
        end
        ```

        ### Tool Calling Flow

        When the LLM requests a tool call:

        1. Provider parses `tool_calls` from response
        2. Agent locates matching tool method
        3. Arguments extracted and validated
        4. Tool method executed, result captured
        5. AgentToolCall record created for audit
        6. Tool result sent back to LLM
        7. Generation continues until `finish_reason: stop`

        ### Performance Characteristics

        - **Latency**: Dominated by LLM API response time (typically 1-5s for first token)
        - **Throughput**: Horizontally scalable via Cloud Run auto-scaling
        - **Memory**: Minimal footprint; context stored in database, not memory
      MARKDOWN

      report.press(Page.new(body: body), title: "Data Flow & Request Lifecycle")
      create_picture(report, "data_flow.png", "Data Flow Sequence Diagram")
    end

    # === Database Schema ===
    def create_database_section(report)
      body = <<~MARKDOWN
        ## Database & Persistence Layer

        ### SolidAgent Schema

        The SolidAgent extension provides comprehensive persistence for AI interactions:

        #### AgentContext
        Top-level container for agent sessions:
        - Polymorphic association to any contextable model
        - Status tracking: `pending` → `processing` → `completed` / `failed`
        - Stores agent name, action, instructions, and input parameters

        #### AgentMessage
        Individual messages in the conversation:
        - Roles: `user`, `assistant`, `system`, `tool`
        - Position-based ordering for multi-turn conversations
        - Supports tool calls and tool responses

        #### AgentGeneration
        Metadata for each LLM generation:
        - Provider and model identification
        - Token usage (input, output, cached)
        - Finish reason and timing metrics
        - Raw request/response for debugging

        #### AgentToolCall
        Detailed tool execution records:
        - Tool name and arguments (JSON)
        - Execution result and status
        - Duration tracking for performance analysis

        #### AgentFragment
        Content transformation tracking:
        - Types: `citation`, `selection`, `spec_extraction`
        - Parent-child chains for version history
        - Confidence scoring and metadata

        #### AgentReference
        Extracted references from tool outputs:
        - URLs discovered during research
        - Source attribution for provenance

        ### Data Integrity

        - **Foreign Keys**: All relationships enforced at database level
        - **Indexes**: Optimized for common query patterns
        - **Soft Deletes**: Not implemented; consider for production
        - **Audit Trail**: Complete history of all AI interactions
      MARKDOWN

      report.press(Page.new(body: body), title: "Database & Persistence Layer")
      create_picture(report, "database_schema.png", "Database Schema Diagram")
    end

    # === Deployment ===
    def create_deployment_section(report)
      body = <<~MARKDOWN
        ## Infrastructure & Deployment Review

        ### CI/CD Pipeline

        #### GitHub Actions Workflow

        1. **CI Stage** (on every push):
           - Ruby 3.4.5 environment setup
           - RuboCop linting
           - Unit and system tests
           - Brakeman security scanning
           - Bundle audit for vulnerable dependencies

        2. **CD Stage** (on main branch):
           - Docker multi-stage build
           - Push to Google Artifact Registry
           - Deploy to Cloud Run with traffic migration

        ### Google Cloud Platform Architecture

        #### Cloud Run Service
        - **Auto-scaling**: 0 to N instances based on traffic
        - **Cold Start**: ~3-5 seconds (acceptable for async operations)
        - **Memory**: 512MB-2GB per instance
        - **Concurrency**: 80 requests per instance

        #### Cloud SQL (PostgreSQL 15)
        - **High Availability**: Regional with automatic failover
        - **Backups**: Daily automated, 7-day retention
        - **Connection**: Via Cloud SQL Proxy / Unix socket

        #### Cloud Storage
        - **Active Storage**: PDF uploads, images, attachments
        - **CDN**: Cloud CDN for static assets

        #### Secret Manager
        - API keys (OpenAI, Anthropic, Stripe)
        - Rails credentials (SECRET_KEY_BASE)
        - Database connection strings

        ### Deployment Security

        - **Workload Identity**: No service account keys in code
        - **VPC Connector**: Private communication with Cloud SQL
        - **HTTPS Only**: Cloud Run enforces TLS
        - **IAM**: Principle of least privilege
      MARKDOWN

      report.press(Page.new(body: body), title: "Infrastructure & Deployment Review")
      create_picture(report, "deployment.png", "Deployment Architecture Diagram")
    end

    # === Dill Integration Case Study ===
    def create_dill_integration_section(report)
      body = <<~MARKDOWN
        ## Integration Case Study: Dill.vc

        ### Overview

        Dill.vc is a technical due diligence platform built entirely on ActiveAgent. It demonstrates the framework's capabilities in a production environment with real customers.

        ### Agent Implementations

        Dill implements 6 specialized agents:

        #### 1. WritingAssistantAgent
        Text improvement and editing:
        - `improve`: Enhance writing quality
        - `grammar`: Correct grammar and spelling
        - `style`: Adjust tone and formality
        - `summarize`: Create concise summaries
        - `expand`: Elaborate on content

        #### 2. TechDiligenceAgent
        Document analysis with vision capabilities:
        - `answer_questions`: Q&A with multi-page context
        - `analyze_pages`: Deep visual analysis of diagrams
        - `extract_specs`: Structured specification extraction
        - `verify_claims`: Fact-checking against documents

        #### 3. ResearchAssistantAgent
        Autonomous web research:
        - Browser automation via Capybara/Cuprite
        - 8 tools: navigate, click, extract_text, extract_links, etc.
        - Reference extraction and persistence

        #### 4. ReportComposerAgent
        AI-powered report generation:
        - Section composition from document context
        - Question answering with citations
        - Streaming responses via ActionCable

        #### 5. TechExpertAgent
        Technical expertise queries:
        - Domain-specific knowledge application
        - Code analysis and recommendations

        #### 6. FileAnalyzerAgent
        Document processing:
        - PDF text and image extraction
        - Vision-language model integration

        ### Production Metrics

        - **Daily Active Agents**: All 6 agents used in production
        - **Token Volume**: ~500K tokens/day across agents
        - **Reliability**: 99.5%+ uptime since launch
        - **User Satisfaction**: Positive feedback on AI accuracy

        ### Code Example

        From Dill's `app/agents/application_agent.rb`:

        ```ruby
        class ApplicationAgent < ActiveAgent::Base
          include SolidAgent::HasContext
          include SolidAgent::HasTools
          include SolidAgent::StreamsToolUpdates
          include RecordsToolCalls

          layout "agent"
          generate_with :openai, model: "gpt-4o"
        end
        ```

        This demonstrates how easily agents integrate with Rails applications using ActiveAgent's inheritance model.
      MARKDOWN

      report.press(Page.new(body: body), title: "Integration Case Study: Dill.vc")
      create_picture(report, "dill_integration.png", "Dill Integration Architecture")
    end

    # === Security Findings ===
    def create_security_findings(report)
      report.press(Page.new(body: "## Security Assessment\n\nThe following findings relate to security considerations in the ActiveAgent framework and its typical deployment patterns."), title: "Security Assessment")

      create_finding(report,
        title: "API Key Management",
        severity: "medium",
        category: "security",
        description: <<~DESC,
          API keys for LLM providers are configured via Rails credentials or environment variables. While this follows Rails conventions, there's no built-in support for:

          - Key rotation without service restarts
          - Per-request key selection for multi-tenant scenarios
          - Audit logging of key usage per request
          - Rate limiting at the application level
        DESC
        evidence: <<~EVIDENCE,
          From `config/active_agent.yml`:
          ```yaml
          openai:
            api_key: <%= ENV['OPENAI_API_KEY'] %>
          ```

          Keys are loaded once at boot time and cached for the process lifetime.
        EVIDENCE
        recommendation: <<~REC
          1. Implement key rotation mechanism using Rails encrypted credentials refresh
          2. Add audit logging for provider API calls
          3. Consider HashiCorp Vault integration for enterprise deployments
          4. Implement application-level rate limiting per user/tenant
        REC
      )

      create_finding(report,
        title: "Rate Limiting Considerations",
        severity: "low",
        category: "security",
        description: <<~DESC,
          The framework delegates rate limiting to LLM providers rather than implementing application-level controls. This could lead to:

          - Unexpected costs from runaway requests
          - Denial of service from provider rate limit exhaustion
          - Difficulty in fair resource allocation among tenants
        DESC
        evidence: <<~EVIDENCE,
          No rate limiting middleware observed in the gem source. Provider rate limits are handled via retry logic:

          ```ruby
          retry_on_failure: true,
          max_retries: 3,
          retry_delay: 1.0
          ```
        EVIDENCE
        recommendation: <<~REC
          1. Implement Rack middleware for request rate limiting
          2. Add per-user/tenant token budgets
          3. Configure alerts for unusual usage patterns
          4. Consider Redis-based distributed rate limiting
        REC
      )

      create_finding(report,
        title: "Input Sanitization",
        severity: "info",
        category: "security",
        description: <<~DESC,
          Prompt injection is a known risk with LLM applications. ActiveAgent provides template-based prompts which help structure inputs, but there's no built-in sanitization layer for user-provided content.
        DESC
        evidence: <<~EVIDENCE,
          User inputs are interpolated directly into prompt templates:

          ```erb
          <%= @user_question %>
          ```

          No automatic escaping or sanitization is applied.
        EVIDENCE
        recommendation: <<~REC
          1. Document prompt injection risks in framework guides
          2. Provide optional sanitization helpers
          3. Consider adding prompt boundary markers
          4. Implement output validation for sensitive operations
        REC
      )
    end

    # === Code Quality ===
    def create_code_quality_section(report)
      body = <<~MARKDOWN
        ## Code Quality Analysis

        ### Overall Assessment

        The ActiveAgent codebase demonstrates strong adherence to Ruby and Rails conventions. The code is well-organized, readable, and follows established patterns.

        ### Positive Observations

        1. **Clean Architecture**: Clear separation between base framework and extensions
        2. **Rails Conventions**: Follows "The Rails Way" consistently
        3. **Modular Design**: Concerns and mixins used appropriately
        4. **Type Hints**: Sorbet signatures in critical paths (where applicable)

        ### Testing Strategy

        The framework includes:
        - Unit tests for core components
        - Integration tests for provider interactions
        - System tests for end-to-end flows

        Test coverage appears adequate for the core gem, though the SolidAgent extension could benefit from additional coverage.

        ### Documentation Quality

        - README provides good getting-started guide
        - YARD documentation for public APIs
        - Example applications demonstrate usage patterns
        - Landing page clearly explains business model and features
      MARKDOWN

      report.press(Page.new(body: body), title: "Code Quality Analysis")

      create_finding(report,
        title: "Test Coverage",
        severity: "info",
        category: "code_quality",
        description: <<~DESC,
          The core ActiveAgent gem has good test coverage for main functionality. However, some edge cases and error paths could benefit from additional testing:

          - Streaming interruption handling
          - Provider failover scenarios
          - Tool execution timeouts
          - Concurrent request handling
        DESC
        recommendation: <<~REC
          1. Add tests for streaming edge cases
          2. Implement chaos testing for provider failures
          3. Add load tests for concurrent operations
          4. Track coverage metrics in CI pipeline
        REC
      )

      create_finding(report,
        title: "Documentation Completeness",
        severity: "info",
        category: "code_quality",
        description: <<~DESC,
          Documentation is comprehensive for common use cases. Areas for improvement include:

          - Advanced configuration options
          - Performance tuning guides
          - Troubleshooting common issues
          - Migration guides between versions
        DESC
        recommendation: <<~REC
          1. Add performance optimization guide
          2. Create troubleshooting FAQ
          3. Document all configuration options
          4. Provide upgrade migration guides
        REC
      )

      create_finding(report,
        title: "Dependency Management",
        severity: "low",
        category: "code_quality",
        description: <<~DESC,
          The gem has minimal direct dependencies, which is positive. However, some transitive dependencies (particularly in provider SDKs) may have security implications.
        DESC
        evidence: <<~EVIDENCE,
          Direct dependencies from gemspec:
          - rails >= 7.0
          - openai (optional)
          - ruby-anthropic (optional)

          Provider SDKs are optional, reducing attack surface for minimal installations.
        EVIDENCE
        recommendation: <<~REC
          1. Run `bundle audit` in CI pipeline
          2. Use Dependabot for automated updates
          3. Pin major versions of critical dependencies
          4. Document minimum supported versions
        REC
      )
    end

    # === Scalability ===
    def create_scalability_section(report)
      body = <<~MARKDOWN
        ## Scalability Analysis

        ### Horizontal Scaling

        ActiveAgent is designed for horizontal scalability:

        1. **Stateless Agents**: No in-memory state between requests
        2. **Database Persistence**: All context stored in PostgreSQL
        3. **Cloud Run Compatible**: Auto-scales based on traffic
        4. **Background Jobs**: ActiveJob integration for async processing

        ### Bottlenecks & Considerations

        #### LLM API Latency
        - **Impact**: High - dominates request time
        - **Mitigation**: Streaming responses, background processing

        #### Database Writes
        - **Impact**: Medium - one write per message/generation
        - **Mitigation**: Batch writes, read replicas for queries

        #### Token Limits
        - **Impact**: Medium - large contexts require truncation
        - **Mitigation**: Smart context selection, summarization

        ### Scaling Recommendations

        | Scale | Approach |
        |-------|----------|
        | 0-1K users | Single Cloud Run instance, shared PostgreSQL |
        | 1K-10K users | Auto-scaling Cloud Run, Cloud SQL HA |
        | 10K-100K users | Read replicas, Redis caching, CDN |
        | 100K+ users | Multi-region, dedicated infrastructure |

        ### Cost Projections

        Primary cost drivers:
        1. **LLM API costs**: $0.01-0.03 per 1K tokens (GPT-4o)
        2. **Compute**: $0.00002 per vCPU-second (Cloud Run)
        3. **Database**: $50-500/month (Cloud SQL)
        4. **Storage**: Minimal for most use cases

        For a typical SaaS with 1,000 daily active users generating 100 agent interactions each:
        - ~100K interactions/day
        - ~10M tokens/day (assuming 100 tokens/interaction avg)
        - **Estimated LLM cost**: $100-300/day
        - **Estimated compute cost**: $10-50/day
      MARKDOWN

      report.press(Page.new(body: body), title: "Scalability Analysis")
    end

    # === Risk Assessment ===
    def create_risk_findings(report)
      report.press(Page.new(body: "## Risk Assessment\n\nThe following findings identify potential business and technical risks associated with adopting ActiveAgent as a core dependency."), title: "Risk Assessment")

      create_finding(report,
        title: "LLM Provider Dependency",
        severity: "medium",
        category: "architecture",
        description: <<~DESC,
          ActiveAgent abstracts LLM providers, but applications become dependent on provider-specific capabilities:

          - OpenAI: Best tool calling, function support
          - Anthropic: Extended context, different prompt style
          - Ollama: Limited to local models, varying quality

          Provider outages or API changes could impact service availability.
        DESC
        evidence: <<~EVIDENCE,
          Provider-specific code paths observed:
          ```ruby
          case provider
          when :openai
            format_openai_tools(tools)
          when :anthropic
            format_anthropic_tools(tools)
          end
          ```
        EVIDENCE
        recommendation: <<~REC
          1. Implement provider failover logic
          2. Test prompts across multiple providers
          3. Monitor provider status pages
          4. Maintain prompts compatible with multiple models
          5. Consider OpenRouter for automatic failover
        REC
      )

      create_finding(report,
        title: "Vendor Lock-in Risk",
        severity: "medium",
        category: "architecture",
        description: <<~DESC,
          While ActiveAgent is open source, significant investment in:
          - Custom agents and prompts
          - SolidAgent database schema
          - Tool implementations
          - Streaming infrastructure

          Migration to alternative frameworks would require substantial effort.
        DESC
        recommendation: <<~REC
          1. Document agent logic independent of framework
          2. Keep prompts in version-controlled templates
          3. Abstract business logic from framework specifics
          4. Evaluate exit strategy periodically
          5. Contribute to open source to ensure longevity
        REC
      )

      create_finding(report,
        title: "Open Source Sustainability",
        severity: "low",
        category: "other",
        description: <<~DESC,
          ActiveAgents.ai follows a commercial open-source model with freemium tiers. Key sustainability considerations:

          - Single maintainer/company risk
          - Community contribution levels
          - Long-term funding model viability
          - Competition from larger players (LangChain, etc.)
        DESC
        evidence: <<~EVIDENCE,
          Business model appears sustainable:
          - Open source core attracts users
          - Pro/Enterprise tiers capture value
          - Professional services provide revenue
          - Hosted platform offers recurring revenue
        EVIDENCE
        recommendation: <<~REC
          1. Monitor project activity and community health
          2. Consider contributing to ensure project vitality
          3. Evaluate support tier for critical deployments
          4. Keep aware of alternative frameworks
        REC
      )
    end

    # === Recommendations ===
    def create_recommendations(report)
      body = <<~MARKDOWN
        ## Recommendations

        ### Summary

        ActiveAgents.ai represents a well-designed, production-ready AI framework for Ruby on Rails applications. The recursive demonstration - Dill using ActiveAgent to analyze ActiveAgent - provides compelling evidence of real-world viability.

        ### Investment Thesis Support

        **Strengths:**
        - Strong technical foundation with Rails-native design
        - Clear monetization strategy (freemium to enterprise)
        - Production-proven through Dill.vc usage
        - Growing market for AI development tools

        **Risks:**
        - LLM provider dependency (mitigated by multi-provider support)
        - Open source sustainability (mitigated by commercial model)
        - Competition from well-funded alternatives

        ### Technical Recommendations

        #### Immediate (0-3 months)
        1. Implement application-level rate limiting
        2. Add comprehensive API key audit logging
        3. Enhance test coverage for edge cases
        4. Document performance tuning guidelines

        #### Medium-term (3-6 months)
        1. Add provider failover logic
        2. Implement multi-tenant key management
        3. Build observability dashboard
        4. Create migration guides

        #### Long-term (6-12 months)
        1. Evaluate SOC 2 compliance requirements
        2. Consider multi-region deployment options
        3. Build ecosystem of community extensions
        4. Develop enterprise security features

        ### Conclusion

        **Recommendation: Proceed with investment due diligence**

        The technology stack is sound, the business model is viable, and the product demonstrates clear value. The recursive nature of this assessment (Dill analyzing the framework it's built on) provides unique validation of production readiness.

        ---

        *This report was generated by Dill.vc, powered by ActiveAgent.*
        *Assessment demonstrates framework's production capabilities.*
      MARKDOWN

      report.press(Page.new(body: body), title: "Recommendations")
    end

    # === Helper Methods ===

    def create_picture(report, filename, title)
      path = Rails.root.join(DIAGRAM_DIR, filename)
      return unless File.exist?(path)

      picture = Picture.new
      picture.image.attach(
        io: File.open(path, "rb"),
        filename: filename,
        content_type: "image/png"
      )
      picture.save!
      report.press(picture, title: title)
    end

    def create_finding(report, title:, severity:, category:, description:, evidence: nil, recommendation: nil)
      finding = Finding.create!(
        severity: severity,
        status: "open",
        category: category,
        description: description.strip,
        evidence: evidence&.strip,
        recommendation: recommendation&.strip
      )
      report.press(finding, title: title)
    end
  end
end
