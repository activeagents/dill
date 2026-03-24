import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template", "section"]

  connect() {
    this.updateNumbers()
  }

  addSection() {
    const template = this.templateTarget.innerHTML
    const index = this.sectionTargets.length
    const newSection = template.replace(/INDEX/g, index)

    this.listTarget.insertAdjacentHTML("beforeend", newSection)
    this.updateNumbers()

    // Focus the new section's title input
    const newSectionEl = this.listTarget.lastElementChild
    const titleInput = newSectionEl.querySelector('input[type="text"]')
    if (titleInput) titleInput.focus()
  }

  removeSection(event) {
    const section = event.target.closest("[data-section-schema-target='section']")
    if (this.sectionTargets.length > 1) {
      section.remove()
      this.updateNumbers()
    } else {
      alert("A template must have at least one section.")
    }
  }

  updateNumbers() {
    this.sectionTargets.forEach((section, index) => {
      const numberEl = section.querySelector(".section-number")
      if (numberEl) {
        numberEl.textContent = `${index + 1}.`
      }
      section.dataset.index = index
    })
  }
}
