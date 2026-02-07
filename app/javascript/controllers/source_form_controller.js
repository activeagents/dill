import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileField", "urlField", "textField", "typeOption", "outlineHint"]

  connect() {
    this.updateFieldVisibility()
  }

  typeChanged() {
    this.updateFieldVisibility()
  }

  updateFieldVisibility() {
    const selectedType = this.element.querySelector('input[name="source[source_type]"]:checked')?.value

    this.toggleField(this.fileFieldTarget, ["pdf", "image"].includes(selectedType))
    this.toggleField(this.urlFieldTarget, selectedType === "url")
    this.toggleField(this.textFieldTarget, ["text", "outline"].includes(selectedType))

    // Show/hide outline hint
    if (this.hasOutlineHintTarget) {
      this.outlineHintTarget.style.display = selectedType === "outline" ? "block" : "none"
    }

    // Update placeholder text based on type
    const textarea = this.textFieldTarget?.querySelector("textarea")
    if (textarea) {
      if (selectedType === "outline") {
        textarea.placeholder = "## Section Heading\n\nDescribe the expected content for this section...\n\n- Key point 1\n- Key point 2\n\n## Another Section\n\nMore outline content..."
      } else {
        textarea.placeholder = "Paste or type your text content here..."
      }
    }

    // Update radio card styles
    this.typeOptionTargets.forEach(option => {
      const isSelected = option.dataset.type === selectedType
      option.classList.toggle("radio-card--selected", isSelected)
    })
  }

  toggleField(field, show) {
    if (field) {
      field.style.display = show ? "block" : "none"
      const input = field.querySelector("input, textarea")
      if (input) {
        input.required = show
      }
    }
  }
}
