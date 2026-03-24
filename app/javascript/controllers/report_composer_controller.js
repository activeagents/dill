import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

/**
 * Report Composer Controller
 *
 * Provides a modal interface for AI-powered report composition:
 * - Compose new sections from document sources
 * - Ask questions answered from document context
 * - Generate content for existing sections
 */
export default class extends Controller {
  static targets = ["dialog", "content", "status", "input", "modeSwitch", "copyButton", "createButton"]
  static values = {
    reportId: Number,
    sectionId: Number,
    mode: { type: String, default: "ask" }  // "ask" or "compose"
  }

  connect() {
    console.log('[Report Composer] Controller connected')
    this.cable = window.App || (window.App = {})
    if (!this.cable.cable) {
      this.cable.cable = createConsumer()
    }
    this.subscription = null
    this.accumulatedContent = ''
    this.isStreaming = false
  }

  disconnect() {
    this.cleanup()
  }

  /**
   * Open the composer modal
   */
  open(event) {
    event?.preventDefault()

    // Reset state
    this.accumulatedContent = ''
    this.isStreaming = false
    this.contentTarget.innerHTML = '<p class="composer__placeholder">Enter your question or topic above and click Submit to get AI-generated content from your documents.</p>'
    this.inputTarget.value = ''
    this.setStatus('Ready', false)
    this.copyButtonTarget.disabled = true
    this.createButtonTarget.disabled = true

    // Show modal
    this.dialogTarget.showModal()
    this.inputTarget.focus()
  }

  /**
   * Close the modal
   */
  close() {
    this.cleanup()
    this.dialogTarget.close()
  }

  /**
   * Switch between ask and compose modes
   */
  switchMode(event) {
    this.modeValue = event.currentTarget.value
    this.updateModeUI()
  }

  updateModeUI() {
    // Update placeholder text based on mode
    if (this.modeValue === "compose") {
      this.inputTarget.placeholder = "Enter a topic to compose a section about (e.g., 'Memory specifications and supported configurations')"
    } else {
      this.inputTarget.placeholder = "Ask a question about your documents (e.g., 'What is the maximum RAM capacity?')"
    }
  }

  /**
   * Submit the current input
   */
  async submit(event) {
    event?.preventDefault()

    const input = this.inputTarget.value.trim()
    if (!input) {
      alert('Please enter a question or topic')
      return
    }

    this.isStreaming = true
    this.accumulatedContent = ''
    this.contentTarget.innerHTML = ''
    this.copyButtonTarget.disabled = true
    this.createButtonTarget.disabled = true

    if (this.modeValue === "compose") {
      this.setStatus('Composing section...', true)
      await this.composeSection(input)
    } else {
      this.setStatus('Searching documents...', true)
      await this.askQuestion(input)
    }
  }

  /**
   * Ask a question and get an answer from documents
   */
  async askQuestion(question) {
    try {
      const response = await fetch('/assistants/composer/answer', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          report_id: this.reportIdValue,
          question: question
        })
      })

      const data = await response.json()

      if (data.error) {
        this.showError(data.error)
        return
      }

      // Subscribe to stream
      await new Promise(resolve => setTimeout(resolve, 100))
      this.subscribeToStream(data.stream_id)
    } catch (error) {
      console.error('[Report Composer] Request error:', error)
      this.showError('Failed to start AI processing')
    }
  }

  /**
   * Compose a new section from a topic
   */
  async composeSection(topic) {
    try {
      const response = await fetch('/assistants/composer/section', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          report_id: this.reportIdValue,
          topic: topic,
          section_type: 'analysis'
        })
      })

      const data = await response.json()

      if (data.error) {
        this.showError(data.error)
        return
      }

      // Subscribe to stream
      await new Promise(resolve => setTimeout(resolve, 100))
      this.subscribeToStream(data.stream_id)
    } catch (error) {
      console.error('[Report Composer] Request error:', error)
      this.showError('Failed to start AI processing')
    }
  }

  subscribeToStream(streamId) {
    console.log('[Report Composer] Subscribing to stream:', streamId)

    this.subscription = this.cable.cable.subscriptions.create(
      { channel: "AssistantStreamChannel", stream_id: streamId },
      {
        connected: () => {
          console.log('[Report Composer] Connected to stream')
        },
        disconnected: () => {
          console.log('[Report Composer] Disconnected from stream')
        },
        received: (message) => {
          this.handleStreamMessage(message)
        }
      }
    )
  }

  handleStreamMessage(message) {
    console.log('[Report Composer] Message received:', message)

    if (message.tool_status) {
      this.setStatus(message.tool_status.description, true)
    } else if (message.content) {
      this.accumulatedContent = message.content
      this.contentTarget.innerHTML = this.renderMarkdown(this.accumulatedContent)
      this.contentTarget.scrollTop = this.contentTarget.scrollHeight
    } else if (message.done) {
      this.onStreamComplete()
    } else if (message.error) {
      this.showError(message.error)
    }
  }

  onStreamComplete() {
    console.log('[Report Composer] Stream complete')
    this.isStreaming = false
    this.setStatus('Complete', false)
    this.copyButtonTarget.disabled = false
    this.createButtonTarget.disabled = false

    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
  }

  /**
   * Copy content to clipboard
   */
  async copy() {
    if (!this.accumulatedContent) return

    try {
      await navigator.clipboard.writeText(this.accumulatedContent)

      const originalText = this.copyButtonTarget.textContent
      this.copyButtonTarget.textContent = 'Copied!'
      setTimeout(() => {
        this.copyButtonTarget.textContent = originalText
      }, 1500)
    } catch (error) {
      console.error('[Report Composer] Copy failed:', error)
    }
  }

  /**
   * Create a new page from the generated content
   * This creates a new Page section in the report
   */
  async createPage() {
    if (!this.accumulatedContent) return

    try {
      // Create a new page with the generated content
      const response = await fetch(`/reports/${this.reportIdValue}/pages`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml'
        },
        body: JSON.stringify({
          page: {
            title: this.extractTitle(this.accumulatedContent),
            body: this.accumulatedContent
          }
        })
      })

      if (response.ok) {
        // Close modal and let Turbo handle the response
        this.close()
        // Reload the page to show the new section
        window.location.reload()
      } else {
        const errorText = await response.text()
        console.error('[Report Composer] Create page failed:', errorText)
        this.showError('Failed to create page')
      }
    } catch (error) {
      console.error('[Report Composer] Create page error:', error)
      this.showError('Failed to create page')
    }
  }

  /**
   * Extract a title from the generated content
   */
  extractTitle(content) {
    // Try to find a markdown heading
    const headingMatch = content.match(/^#+ (.+)$/m)
    if (headingMatch) {
      return headingMatch[1].trim()
    }

    // Fall back to first line
    const firstLine = content.split('\n')[0]
    if (firstLine.length > 50) {
      return firstLine.substring(0, 47) + '...'
    }
    return firstLine || 'Generated Content'
  }

  showError(message) {
    this.isStreaming = false
    this.setStatus('Error', false)
    this.contentTarget.innerHTML = `<p class="composer__error">${message}</p>`
    this.copyButtonTarget.disabled = true
    this.createButtonTarget.disabled = true
  }

  setStatus(text, isLoading) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = text
      this.statusTarget.classList.toggle('composer__status--loading', isLoading)
    }
  }

  /**
   * Simple markdown to HTML renderer
   */
  renderMarkdown(text) {
    if (!text) return ''

    let content = text.trim()
    if (content.startsWith('```')) {
      content = content.replace(/^```\w*\n?/, '').replace(/\n?```$/, '')
    }

    let html = content
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

    // Code blocks
    html = html.replace(/```(\w*)\n?([\s\S]*?)```/g, '<pre><code>$2</code></pre>')

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code>$1</code>')

    // Headers
    html = html.replace(/^### (.+)$/gm, '<h3>$1</h3>')
    html = html.replace(/^## (.+)$/gm, '<h2>$1</h2>')
    html = html.replace(/^# (.+)$/gm, '<h1>$1</h1>')

    // Bold
    html = html.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')

    // Italic
    html = html.replace(/\*([^*]+)\*/g, '<em>$1</em>')

    // Source citations - highlight them
    html = html.replace(/\[Source: ([^\]]+)\]/g, '<span class="composer__citation">[Source: $1]</span>')

    // Blockquotes
    html = html.replace(/^&gt; (.+)$/gm, '<blockquote>$1</blockquote>')

    // Lists
    html = html.replace(/^- (.+)$/gm, '<li>$1</li>')
    html = html.replace(/^\d+\. (.+)$/gm, '<li>$1</li>')
    html = html.replace(/(<li>.*<\/li>\n?)+/g, '<ul>$&</ul>')

    // Paragraphs
    html = html.replace(/\n\n+/g, '</p><p>')
    html = html.replace(/(?<!\>)\n(?!<)/g, '<br>')

    if (!html.match(/^<(h[1-6]|p|ul|ol|pre|blockquote)/)) {
      html = '<p>' + html + '</p>'
    }

    html = html.replace(/<p><\/p>/g, '')
    html = html.replace(/<p>(<h[1-6]>)/g, '$1')
    html = html.replace(/(<\/h[1-6]>)<\/p>/g, '$1')

    return html
  }

  cleanup() {
    if (this.subscription) {
      this.subscription.unsubscribe()
      this.subscription = null
    }
    this.isStreaming = false
    this.accumulatedContent = ''
  }
}
