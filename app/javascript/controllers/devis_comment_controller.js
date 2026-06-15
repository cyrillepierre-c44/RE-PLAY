import { Controller } from "@hotwired/stimulus"

const KEY = "devis-comment"

export default class extends Controller {
  connect() {
    const saved = localStorage.getItem(KEY)
    if (saved) this.element.innerHTML = saved
    this.element.addEventListener('input', () => this._save())
  }

  _save() {
    clearTimeout(this._t)
    this._t = setTimeout(() => {
      localStorage.setItem(KEY, this.element.innerHTML)
    }, 400)
  }
}
