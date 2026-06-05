import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: Number, actif: Boolean, module: String, numero: Number }
  static targets = ["switchLabel", "bar", "pctInput"]

  toggle(event) {
    this.actifValue = event.target.checked
    this.element.classList.toggle("levier--off", !this.actifValue)
    if (this.hasSwitchLabelTarget) {
      this.switchLabelTarget.textContent = this.actifValue ? "Inclus" : "Exclu"
    }
    this._save({ actif: this.actifValue })
    window.dispatchEvent(new CustomEvent("levier:toggled", {
      detail: { module: this.moduleValue, numero: this.numeroValue, actif: this.actifValue }
    }))
  }

  setProgression(event) {
    const val = Math.min(100, Math.max(0, parseInt(event.target.value) || 0))
    if (this.hasBarTarget) {
      this.barTarget.style.width = val + "%"
    }
    clearTimeout(this._debounce)
    this._debounce = setTimeout(() => this._save({ progression: val }), 500)
  }

  _save(data) {
    const token = document.querySelector('[name="csrf-token"]')?.content
    fetch(`/projet_leviers/${this.idValue}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token
      },
      body: JSON.stringify({ projet_levier: data })
    })
  }
}
