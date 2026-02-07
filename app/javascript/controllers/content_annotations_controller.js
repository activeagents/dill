import { Controller } from "@hotwired/stimulus"

/**
 * Content Annotations Controller
 *
 * Handles interactive behavior for content annotations:
 * - Tooltips on mark[data-origin] elements showing content origin
 * - Clickable diff recommendations showing accept/reject popover
 * - Suggestion resolution via PATCH to suggestions endpoint
 */
export default class extends Controller {
  connect() {
    this.activePopover = null
    this.handleDocumentClick = this.handleDocumentClick.bind(this)
    document.addEventListener("click", this.handleDocumentClick)

    this.setupDiffRecommendations()
  }

  disconnect() {
    document.removeEventListener("click", this.handleDocumentClick)
    this.removeActivePopover()
  }

  /**
   * Attach click handlers to diff recommendation elements
   */
  setupDiffRecommendations() {
    this.element.querySelectorAll(".diff-recommendation").forEach((el) => {
      el.addEventListener("click", (event) => {
        event.stopPropagation()
        this.showDiffPopover(el)
      })
    })
  }

  /**
   * Show accept/reject popover for a diff recommendation
   */
  showDiffPopover(diffEl) {
    this.removeActivePopover()

    const suggestionId = diffEl.dataset.suggestionId
    if (!suggestionId) return

    const reason = diffEl.dataset.reason

    const popover = document.createElement("div")
    popover.className = "diff-action-popover"

    if (reason) {
      const reasonP = document.createElement("p")
      reasonP.textContent = reason
      popover.appendChild(reasonP)
    }

    const actions = document.createElement("div")
    actions.className = "flex gap-half"

    const acceptBtn = document.createElement("button")
    acceptBtn.className = "btn btn--small btn--primary"
    acceptBtn.textContent = "Accept"
    acceptBtn.addEventListener("click", (e) => {
      e.stopPropagation()
      this.resolveSuggestion(suggestionId, "accept", diffEl)
    })

    const rejectBtn = document.createElement("button")
    rejectBtn.className = "btn btn--small"
    rejectBtn.textContent = "Reject"
    rejectBtn.addEventListener("click", (e) => {
      e.stopPropagation()
      this.resolveSuggestion(suggestionId, "reject", diffEl)
    })

    actions.appendChild(acceptBtn)
    actions.appendChild(rejectBtn)
    popover.appendChild(actions)

    diffEl.style.position = "relative"
    diffEl.appendChild(popover)
    this.activePopover = popover
  }

  /**
   * Send accept/reject PATCH request
   */
  async resolveSuggestion(suggestionId, action, diffEl) {
    try {
      const response = await fetch(`/suggestions/${suggestionId}/${action}`, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
          "Accept": "application/json"
        }
      })

      if (response.ok) {
        this.removeActivePopover()
        this.applyResolution(diffEl, action)
      } else {
        console.error(`[Content Annotations] Failed to ${action} suggestion:`, response.status)
      }
    } catch (error) {
      console.error(`[Content Annotations] Error resolving suggestion:`, error)
    }
  }

  /**
   * Update the DOM after a suggestion is accepted/rejected
   */
  applyResolution(diffEl, action) {
    const removeEl = diffEl.querySelector(".diff-remove")
    const addEl = diffEl.querySelector(".diff-add")

    if (action === "accept") {
      // Keep the suggested text, remove the original
      if (removeEl) removeEl.remove()
      if (addEl) {
        // Unwrap the ins element, keeping its text content
        addEl.replaceWith(document.createTextNode(addEl.textContent))
      }
    } else {
      // Keep the original text, remove the suggestion
      if (addEl) addEl.remove()
      if (removeEl) {
        // Unwrap the del element, keeping its text content
        removeEl.replaceWith(document.createTextNode(removeEl.textContent))
      }
    }

    // Clean up the wrapper span
    const parent = diffEl.parentNode
    if (parent) {
      while (diffEl.firstChild) {
        parent.insertBefore(diffEl.firstChild, diffEl)
      }
      diffEl.remove()
    }
  }

  /**
   * Close popover when clicking outside
   */
  handleDocumentClick() {
    this.removeActivePopover()
  }

  removeActivePopover() {
    if (this.activePopover) {
      this.activePopover.remove()
      this.activePopover = null
    }
  }
}
