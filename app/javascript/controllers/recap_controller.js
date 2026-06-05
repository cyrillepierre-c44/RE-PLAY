import { Controller } from "@hotwired/stimulus"

// Static levier data [hours, budget_ht] indexed by numero (1-based → index 0-based)
const DATA = {
  A: [[20, 1800], [25, 2250], [45, 4050], [25, 2250], [43, 3870]],
  B: [[25, 2250], [35, 3150], [55, 4950], [38, 3420], [40, 3600]],
  C: [[15, 1350], [20, 1800], [35, 3150], [20, 1800], [19, 1710]]
}

export default class extends Controller {
  static values = { module: String }
  static targets = [
    "row", "totalHours", "totalBudget",      // module tables
    "moduleRow", "grandHours", "grandBudget" // global table
  ]

  connect() {
    this._onToggle = this._handleToggle.bind(this)
    window.addEventListener("levier:toggled", this._onToggle)
  }

  disconnect() {
    window.removeEventListener("levier:toggled", this._onToggle)
  }

  _handleToggle({ detail: { module, numero, actif } }) {
    if (this.moduleValue) {
      if (this.moduleValue !== module) return
      this._updateRow(numero, actif)
      this._recalcTotal()
    } else {
      this._updateGlobal()
    }
  }

  _updateRow(numero, actif) {
    this.rowTargets.forEach(row => {
      if (parseInt(row.dataset.levierNum) === numero) {
        row.style.display = actif ? "" : "none"
      }
    })
  }

  _recalcTotal() {
    let h = 0, b = 0
    this.rowTargets.forEach(row => {
      if (row.style.display !== "none") {
        h += parseInt(row.dataset.hours)
        b += parseInt(row.dataset.budget)
      }
    })
    if (this.hasTotalHoursTarget) this.totalHoursTarget.textContent = h + "h"
    if (this.hasTotalBudgetTarget) this.totalBudgetTarget.textContent = this._fmt(b) + " € HT"
  }

  _updateGlobal() {
    let grandH = 0, grandB = 0
    this.moduleRowTargets.forEach(row => {
      const mod = row.dataset.module
      let modH = 0, modB = 0
      DATA[mod].forEach(([h, b], i) => {
        const sel = `[data-levier-tracker-module-value="${mod}"][data-levier-tracker-numero-value="${i + 1}"]`
        const el = document.querySelector(sel)
        if (el && !el.classList.contains("levier--off")) { modH += h; modB += b }
      })
      const hCell = row.querySelector("[data-mod-hours]")
      const bCell = row.querySelector("[data-mod-budget]")
      if (hCell) hCell.textContent = modH + "h"
      if (bCell) bCell.textContent = this._fmt(modB) + " €"
      grandH += modH; grandB += modB
    })
    if (this.hasGrandHoursTarget) this.grandHoursTarget.textContent = grandH + "h"
    if (this.hasGrandBudgetTarget) this.grandBudgetTarget.textContent = this._fmt(grandB) + " € HT"
  }

  _fmt(n) {
    return n.toLocaleString("fr-FR")
  }
}
