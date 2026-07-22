import { Controller } from "@hotwired/stimulus"

// Barre de progression du recalcul des prix (admin, index des jouets).
// Interroge refresh_prices_status toutes les 3 s ; quand il ne reste plus
// de jouet sans prix, recharge la page (le serveur affiche alors le flash
// "Prix recalculé pour N jouet(s) !").
export default class extends Controller {
  static targets = ["fill", "count", "stalled"]
  static values = { total: Number, remaining: Number, url: String }

  connect() {
    this.lastRemaining = this.remainingValue
    this.lastChangeAt = Date.now()
    this.timer = setInterval(() => this.poll(), 3000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    let remaining
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      remaining = (await response.json()).remaining
    } catch {
      return // réseau instable : on retente au prochain tick
    }

    if (remaining !== this.lastRemaining) {
      this.lastRemaining = remaining
      this.lastChangeAt = Date.now()
    }
    this.render(remaining)

    if (remaining === 0) {
      clearInterval(this.timer)
      setTimeout(() => window.location.reload(), 600)
    } else if (Date.now() - this.lastChangeAt > 90000) {
      clearInterval(this.timer)
      this.stalledTarget.hidden = false
    }
  }

  render(remaining) {
    const total = Math.max(this.totalValue, 1)
    const done = Math.min(total, Math.max(0, total - remaining))
    this.countTarget.textContent = `${done} / ${total}`
    this.fillTarget.style.width = `${Math.round((done / total) * 100)}%`
  }
}
