import { Controller } from "@hotwired/stimulus"

// Tableau de bord : tout chiffre cliquable ouvre la liste des jouets concernés
// dans une fenêtre par-dessus la page (plein écran sur téléphone). On la voit
// tout de suite, et en la fermant on retrouve sa place dans le tableau de bord.
// Le contenu est chargé dans le turbo-frame `quality-detail` placé dans la fenêtre.
export default class extends Controller {
  static targets = ["modal", "frame"]

  open(event) {
    const link = event.target.closest("a[data-turbo-frame='quality-detail'], .quality-trend a")
    if (!link) return

    // Turbo n'intercepte pas les liens d'un dessin SVG (la courbe) : on charge le cadre à la main.
    if (link.closest("svg")) {
      event.preventDefault()
      this.frameTarget.src = link.getAttribute("href")
    }
    window.bootstrap.Modal.getOrCreateInstance(this.modalTarget).show()
  }

  print() {
    window.print()
  }
}
