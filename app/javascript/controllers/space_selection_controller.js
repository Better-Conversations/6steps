import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "check", "input", "submit", "form"]

  connect() {
    this.selectedSpace = null
  }

  select(event) {
    const card = event.currentTarget
    const space = card.dataset.space

    // Update selected space
    this.selectedSpace = space
    this.inputTarget.value = space

    // Update visual state of all cards
    this.cardTargets.forEach(c => {
      const isSelected = c.dataset.space === space
      if (isSelected) {
        c.classList.remove("border-slate-200", "bg-white")
        c.classList.add("border-violet-500", "bg-violet-50")
      } else {
        c.classList.remove("border-violet-500", "bg-violet-50")
        c.classList.add("border-slate-200", "bg-white")
      }
    })

    // Show/hide check marks
    this.checkTargets.forEach(check => {
      const isSelected = check.dataset.spaceCheck === space
      check.classList.toggle("hidden", !isSelected)
    })

    // Enable submit button
    this.submitTarget.disabled = false
  }
}
