import { Controller } from "@hotwired/stimulus"

const PERIOD_LABELS = {
  today:     "Aujourd'hui",
  prev_day:  "Hier",
  last_week: "Semaine dernière",
  custom:    "Sélection libre — choisissez vos dates ci-dessous"
}

export default class extends Controller {
  static targets = ["customPanel", "periodBtn", "feedback"]

  connect() {
    this.anchor = "resultats"
    this.updateVisibility()
    this.updateFeedback()
  }

  select(event) {
    const period = event.currentTarget.dataset.period
    this.element.querySelector("input[name='period']").value = period
    this.periodBtnTargets.forEach(btn => btn.classList.remove("active"))
    event.currentTarget.classList.add("active")
    this.updateVisibility()
    this.updateFeedback()
  }

  setAnchor(event) {
    this.anchor = event.currentTarget.dataset.anchor || "resultats"
  }

  submit(event) {
    event.preventDefault()
    const params = new URLSearchParams(new FormData(this.element))
    window.location.href = `${window.location.pathname}?${params}#${this.anchor}`
  }

  updateVisibility() {
    const period = this.element.querySelector("input[name='period']").value
    if (period === "custom") {
      this.customPanelTarget.classList.remove("d-none")
    } else {
      this.customPanelTarget.classList.add("d-none")
    }
  }

  updateFeedback() {
    if (!this.hasFeedbackTarget) return
    const period = this.element.querySelector("input[name='period']").value
    const label = PERIOD_LABELS[period] || period
    this.feedbackTarget.innerHTML = `<i class="fa-solid fa-circle-check me-1"></i>${label}`
  }
}
