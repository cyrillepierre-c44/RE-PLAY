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
