import { Controller } from "@hotwired/stimulus"

// Création d'une caisse : le compteur et la barre suivent les vérifications du
// TRI cochées, et le bouton d'enregistrement ne se libère qu'à 100 %.
export default class extends Controller {
  static targets = ["check", "count", "fill", "submit", "hint"]
  static values = { required: Boolean }

  connect() {
    this.refresh()
  }

  refresh() {
    const total = this.checkTargets.length
    const done = this.checkTargets.filter(input => input.checked).length
    const complete = done === total
    this.countTarget.textContent = `${done} / ${total}`
    this.fillTarget.style.width = `${Math.round((done * 100) / total)}%`
    this.element.classList.toggle("tri-checklist--complete", complete)
    if (!this.requiredValue) return

    this.submitTarget.disabled = !complete
    this.hintTarget.hidden = complete
  }
}
