import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customPanel", "periodBtn"]

  connect() {
    this.updateVisibility()
  }

  select(event) {
    const period = event.currentTarget.dataset.period
    this.element.querySelector("input[name='period']").value = period
    this.periodBtnTargets.forEach(btn => btn.classList.remove("active"))
    event.currentTarget.classList.add("active")
    this.updateVisibility()
    if (period !== "custom") this.doSubmit()
  }

  autoSubmit() {
    this.doSubmit()
  }

  dateChange() {
    const start = this.element.querySelector("input[name='start_date']")?.value
    const end   = this.element.querySelector("input[name='end_date']")?.value
    if (start && end) this.doSubmit()
  }

  doSubmit() {
    const params = new URLSearchParams(new FormData(this.element))
    window.location.href = `${window.location.pathname}?${params}#resultats`
  }

  updateVisibility() {
    const period = this.element.querySelector("input[name='period']").value
    this.customPanelTarget.classList.toggle("d-none", period !== "custom")
  }
}
