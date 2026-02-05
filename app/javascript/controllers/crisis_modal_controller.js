import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["helplines", "checkbox", "continueButton"]
  static values = { region: String }

  connect() {
    this.populateHelplines()
    this.trapFocus()
    document.body.style.overflow = "hidden"
  }

  disconnect() {
    document.body.style.overflow = ""
  }

  populateHelplines() {
    const helplines = this.getHelplinesForRegion(this.regionValue)

    this.helplinesTarget.innerHTML = helplines.map(helpline => `
      <div class="flex items-center justify-between p-4 bg-slate-50 rounded-lg">
        <div>
          <p class="font-medium text-slate-900">${helpline.name}</p>
          <p class="text-sm text-slate-600">${helpline.description}</p>
        </div>
        <a href="tel:${helpline.phone.replace(/\s/g, '')}"
           class="inline-flex items-center px-4 py-2 border border-violet-300 rounded-lg text-sm font-medium text-violet-700 bg-violet-50 hover:bg-violet-100">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
          </svg>
          ${helpline.phone}
        </a>
      </div>
    `).join('')
  }

  getHelplinesForRegion(region) {
    const helplines = {
      uk: [
        { name: "Samaritans", phone: "116 123", description: "24/7 emotional support" },
        { name: "NHS 111", phone: "111", description: "NHS non-emergency medical help" }
      ],
      us: [
        { name: "988 Suicide & Crisis Lifeline", phone: "988", description: "24/7 crisis support" },
        { name: "Crisis Text Line", phone: "Text HOME to 741741", description: "Text-based crisis support" }
      ],
      eu: [
        { name: "European Emergency", phone: "112", description: "Emergency services" }
      ],
      au: [
        { name: "Lifeline", phone: "13 11 14", description: "24/7 crisis support" },
        { name: "Beyond Blue", phone: "1300 22 4636", description: "Mental health support" }
      ]
    }

    return helplines[region] || helplines.uk
  }

  toggleContinue() {
    this.continueButtonTarget.disabled = !this.checkboxTarget.checked
  }

  close() {
    this.element.remove()
    document.body.style.overflow = ""
  }

  trapFocus() {
    // Focus the first interactive element
    const firstButton = this.element.querySelector('button, a')
    if (firstButton) firstButton.focus()
  }
}
