import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timer = setTimeout(() => this.dismiss(), 2000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    this.element.classList.remove("show")
    this.element.classList.add("hiding")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }
}
