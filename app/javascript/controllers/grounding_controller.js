import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["circle", "text", "instruction", "startButton", "continueButton"]

  connect() {
    this.step = 0
    this.steps = [
      { text: "Breathe in", duration: 4000, class: "bg-teal-200 scale-110" },
      { text: "Hold", duration: 4000, class: "bg-teal-300" },
      { text: "Breathe out", duration: 6000, class: "bg-teal-100 scale-90" },
      { text: "Hold", duration: 2000, class: "bg-teal-50" }
    ]
    this.cycles = 0
    this.maxCycles = 3
  }

  start() {
    this.startButtonTarget.classList.add("hidden")
    this.instructionTarget.textContent = "Follow the circle and breathe..."
    this.runCycle()
  }

  runCycle() {
    if (this.cycles >= this.maxCycles) {
      this.complete()
      return
    }

    this.runStep()
  }

  runStep() {
    const step = this.steps[this.step]

    // Update text
    this.textTarget.textContent = step.text

    // Update circle appearance
    this.circleTarget.className = `inline-flex items-center justify-center w-20 h-20 rounded-full ${step.class} transition-all duration-1000`

    // Schedule next step
    setTimeout(() => {
      this.step++
      if (this.step >= this.steps.length) {
        this.step = 0
        this.cycles++
      }
      this.runCycle()
    }, step.duration)
  }

  complete() {
    this.textTarget.textContent = "Done"
    this.circleTarget.className = "inline-flex items-center justify-center w-20 h-20 rounded-full bg-green-100 text-green-600 transition-all duration-500"
    this.instructionTarget.textContent = "Well done. You can continue when you're ready."
    this.continueButtonTarget.classList.remove("hidden")
  }

  continue() {
    // Hide the grounding section
    this.element.parentElement.remove()
  }
}
