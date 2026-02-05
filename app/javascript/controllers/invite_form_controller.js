import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["emailField", "maxUsesField"]

  connect() {
    this.toggleMultiUse()
  }

  toggleMultiUse() {
    const multiUseRadio = this.element.querySelector('input[name="invite[multi_use]"][value="true"]')
    const isMultiUse = multiUseRadio?.checked

    if (this.hasEmailFieldTarget) {
      this.emailFieldTarget.classList.toggle("hidden", isMultiUse)
      if (isMultiUse) {
        const emailInput = this.emailFieldTarget.querySelector("input")
        if (emailInput) emailInput.value = ""
      }
    }

    if (this.hasMaxUsesFieldTarget) {
      this.maxUsesFieldTarget.classList.toggle("hidden", !isMultiUse)
      // Clear max_uses when switching to single-use to prevent invalid state
      if (!isMultiUse) {
        const maxUsesInput = this.maxUsesFieldTarget.querySelector("input")
        if (maxUsesInput) maxUsesInput.value = ""
      }
    }
  }
}
