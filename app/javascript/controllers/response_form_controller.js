import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count", "submit"]

  initialize() {
    // Bind the turbo events
    this.handleTurboSubmitEnd = this.handleTurboSubmitEnd.bind(this)
  }

  connect() {
    // Listen for turbo:submit-end to handle post-submission state
    this.element.addEventListener("turbo:submit-end", this.handleTurboSubmitEnd)
    // Check if this is a fresh form (after Turbo Stream replacement)
    // by looking for a submitted flag in sessionStorage
    const sessionId = this.getSessionId()
    const wasSubmitted = sessionStorage.getItem(`submitted_${sessionId}`)

    if (wasSubmitted) {
      // Clear the submitted flag and don't load draft
      sessionStorage.removeItem(`submitted_${sessionId}`)
      this.clearDraft()
      this.inputTarget.value = ""
    } else {
      this.loadDraft()
    }

    this.updateCount()

    // Ensure submit button is enabled (in case of page cache or stale state)
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.innerHTML = `
        Continue
        <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
        </svg>
      `
    }
  }

  getSessionId() {
    // Extract session ID from form action URL
    const match = this.element.action.match(/journey_sessions\/(\d+)/)
    return match ? match[1] : "unknown"
  }

  updateCount() {
    if (!this.hasInputTarget || !this.hasCountTarget) return

    const length = this.inputTarget.value.length
    this.countTarget.textContent = length

    // Save draft to localStorage (but only if not empty)
    if (length > 0) {
      this.saveDraft()
    }
  }

  saveDraft() {
    const sessionId = this.getSessionId()
    localStorage.setItem(`draft_${sessionId}`, this.inputTarget.value)
  }

  loadDraft() {
    const sessionId = this.getSessionId()
    const draft = localStorage.getItem(`draft_${sessionId}`)
    if (draft && !this.inputTarget.value) {
      this.inputTarget.value = draft
    }
  }

  clearDraft() {
    const sessionId = this.getSessionId()
    localStorage.removeItem(`draft_${sessionId}`)
  }

  disconnect() {
    // Clean up event listener
    this.element.removeEventListener("turbo:submit-end", this.handleTurboSubmitEnd)
  }

  handleTurboSubmitEnd(event) {
    // This fires when the turbo submission completes
    // The form will be replaced by Turbo Stream, but if there's an error
    // we need to re-enable the button
    if (!event.detail.success) {
      this.resetSubmitButton()
    }
  }

  resetSubmitButton() {
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = false
      this.submitTarget.innerHTML = `
        Continue
        <svg class="w-4 h-4 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6" />
        </svg>
      `
    }
  }

  submit(event) {
    // Disable submit button to prevent double-submission
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.textContent = "Submitting..."
    }

    // Mark as submitted so the next form load knows to clear
    const sessionId = this.getSessionId()
    sessionStorage.setItem(`submitted_${sessionId}`, "true")

    // Clear the draft
    this.clearDraft()
  }
}
