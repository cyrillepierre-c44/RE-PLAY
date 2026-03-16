import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customPanel", "periodBtn"]

  connect() {
    this.anchor = "resultats"
    this.updateVisibility()
  }

  select(event) {
    const period = event.currentTarget.dataset.period
    this.element.querySelector("input[name='period']").value = period
    this.periodBtnTargets.forEach(btn => btn.classList.remove("active"))
    event.currentTarget.classList.add("active")
    this.updateVisibility()
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
}
