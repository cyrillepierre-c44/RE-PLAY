import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["newPassword"]

  toggle() {
    const field = document.getElementById("current-password-field")
    field.style.display = this.newPasswordTarget.value.length > 0 ? "block" : "none"
  }
}
