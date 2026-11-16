import { Controller } from "@hotwired/stimulus"

// Écran de contrôle qualité : six causes de refus recoupent un des six critères
// du jouet (Nettoyage ↔ Propre, Complétude ↔ Complet…). Cocher la cause décoche
// tout de suite le critère, pour que l'admin voie la carte telle que l'opérateur
// la retrouvera. Le serveur applique la même règle (QualityControl).
export default class extends Controller {
  sync(event) {
    const cause = event.target
    const criterion = this.element.querySelector(`input[type=checkbox][name="toy[${cause.dataset.criterion}]"]`)
    if (!criterion || !cause.checked) return

    criterion.checked = false
    const label = this.element.querySelector(`label[for="${criterion.id}"]`)
    if (!label) return
    label.classList.add("is-linked")
    setTimeout(() => label.classList.remove("is-linked"), 1500)
  }
}
