import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "devis-conditions"
const DEFAULTS = { "validite": "60", "t1-pct": "50", "t2-pct": "30", "t2-date": "__/__/____", "fin-mission": "__/__/____" }
const MAX_EXTRAS = 2

export default class extends Controller {
  static targets = ["field", "solde", "addBtn", "tranches"]

  connect() {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY) || "{}")
    this.fieldTargets.forEach(el => {
      const key = el.dataset.key
      el.textContent = saved[key] ?? DEFAULTS[key] ?? el.textContent
      el.addEventListener("input", () => this._onChange())
      el.addEventListener("keydown", e => { if (e.key === "Enter") { e.preventDefault(); el.blur() } })
    })
    ;(saved._extras || []).forEach(({ pct, date }) => this._appendExtra(pct, date))
    this._updateSolde()
    this._updateAddBtn()
  }

  addTranche() {
    this._appendExtra("10", "__/__/____")
    this._onChange()
    this._updateAddBtn()
    const last = this._extras().at(-1)
    if (last) last.querySelector(".cond-pct").focus()
  }

  removeTranche(e) {
    e.currentTarget.closest(".cond-tranche--extra").remove()
    this._onChange()
    this._updateAddBtn()
  }

  _appendExtra(pct, date) {
    const div = document.createElement("div")
    div.className = "cond-tranche cond-tranche--extra"
    div.innerHTML = `<span class="cond-pct cond-editable" contenteditable="true">${pct}</span>%<span class="cond-label">le</span><span class="cond-editable cond-editable--date" contenteditable="true">${date}</span><button class="cond-remove" data-action="click->devis-conditions#removeTranche" type="button">×</button>`
    div.querySelectorAll("[contenteditable]").forEach(el => {
      el.addEventListener("input", () => this._onChange())
      el.addEventListener("keydown", e => { if (e.key === "Enter") { e.preventDefault(); el.blur() } })
    })
    // Insérer directement avant le bouton "+" dans .cond-tranches
    this.addBtnTarget.before(div)
  }

  _extras() {
    return Array.from(this.tranchesTarget.querySelectorAll(".cond-tranche--extra"))
  }

  _onChange() {
    this._updateSolde()
    clearTimeout(this._t)
    this._t = setTimeout(() => this._save(), 400)
  }

  _updateSolde() {
    const t1 = parseFloat(this._val("t1-pct")) || 0
    const t2 = parseFloat(this._val("t2-pct")) || 0
    const extra = this._extras().reduce((s, el) => s + (parseFloat(el.querySelector(".cond-pct").textContent) || 0), 0)
    if (this.hasSoldeTarget) this.soldeTarget.textContent = Math.max(0, 100 - t1 - t2 - extra)
  }

  _updateAddBtn() {
    if (this.hasAddBtnTarget) this.addBtnTarget.hidden = this._extras().length >= MAX_EXTRAS
  }

  _val(key) {
    const el = this.fieldTargets.find(f => f.dataset.key === key)
    return el ? el.textContent.trim() : ""
  }

  _save() {
    const data = {}
    this.fieldTargets.forEach(el => { data[el.dataset.key] = el.textContent.trim() })
    data._extras = this._extras().map(el => ({
      pct: el.querySelector(".cond-pct").textContent.trim(),
      date: el.querySelector(".cond-editable--date").textContent.trim()
    }))
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data))
  }
}
