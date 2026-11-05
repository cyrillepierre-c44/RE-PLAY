import { Controller } from "@hotwired/stimulus"

// Affiche le champ « Mot de passe actuel » dès qu'on saisit un nouveau mot de
// passe ou qu'on modifie l'adresse e-mail (les deux exigent le mot de passe).
export default class extends Controller {
  static targets = ["newPassword", "email"]
  static values = { originalEmail: String }

  toggle() {
    const field = document.getElementById("current-password-field")
    field.style.display = this.required ? "block" : "none"
  }

  get required() {
    const newPassword = this.hasNewPasswordTarget && this.newPasswordTarget.value.length > 0
    const emailChanged = this.hasEmailTarget &&
      this.emailTarget.value.trim().toLowerCase() !== this.originalEmailValue.toLowerCase()
    return newPassword || emailChanged
  }
}
