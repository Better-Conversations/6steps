import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]
  static values = { startedAt: Number }

  connect() {
    if (this.startedAtValue) {
      this.startTimer()
    }
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  startTimer() {
    this.updateDisplay()
    this.interval = setInterval(() => this.updateDisplay(), 1000)
  }

  updateDisplay() {
    const now = Math.floor(Date.now() / 1000)
    const elapsed = now - this.startedAtValue
    const minutes = Math.floor(elapsed / 60)
    const seconds = elapsed % 60

    this.displayTarget.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`

    // Show warning at 25 minutes
    if (elapsed >= 25 * 60 && elapsed < 26 * 60) {
      this.showTimeWarning()
    }

    // Show final warning at 29 minutes
    if (elapsed >= 29 * 60) {
      this.displayTarget.classList.add('text-red-600', 'font-medium')
    }
  }

  showTimeWarning() {
    if (!this.warningShown) {
      this.warningShown = true
      // Could dispatch an event or show a notification
      console.log("5 minutes remaining in session")
    }
  }
}
