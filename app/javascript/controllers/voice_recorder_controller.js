import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "icon", "status", "textarea"]

  connect() {
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition
    if (!SR) {
      this.buttonTarget.disabled = true
      this.statusTarget.textContent = "Vocal non supporté — utilisez Chrome ou Edge"
      return
    }

    this.recognition = new SR()
    this.recognition.lang = "fr-FR"
    this.recognition.continuous = true
    this.recognition.interimResults = true
    this.isRecording = false
    this.prefix = ""        // contenu existant avant l'enregistrement
    this.sessionFinal = ""  // résultats finaux de la session en cours

    this.recognition.onresult = (event) => {
      let sessionFinal = ""
      let interim = ""
      for (let i = 0; i < event.results.length; i++) {
        if (event.results[i].isFinal) {
          sessionFinal += event.results[i][0].transcript + " "
        } else {
          interim += event.results[i][0].transcript
        }
      }
      this.sessionFinal = sessionFinal
      // Affiche : contenu existant + ce qui est reconnu dans cette session
      const separator = this.prefix && sessionFinal ? " " : ""
      this.textareaTarget.value = (this.prefix + separator + sessionFinal + interim).trim()
    }

    this.recognition.onerror = (event) => {
      if (event.error !== "aborted") {
        this.statusTarget.textContent = `Erreur : ${event.error}`
      }
      this.finalize()
    }

    this.recognition.onend = () => {
      // S'assure que le textarea contient le contenu final propre (sans résidus intermédiaires)
      const separator = this.prefix && this.sessionFinal ? " " : ""
      this.textareaTarget.value = (this.prefix + separator + this.sessionFinal).trim()
      this.setIdle()
    }
  }

  toggle() {
    if (this.isRecording) {
      this.isRecording = false
      this.recognition.stop()
    } else {
      // Capture le contenu existant comme préfixe immuable de cette session
      this.prefix = this.textareaTarget.value.trim()
      this.sessionFinal = ""
      this.recognition.start()
      this.isRecording = true
      this.buttonTarget.classList.add("recording")
      this.iconTarget.className = "fa-solid fa-stop"
      this.statusTarget.textContent = "Enregistrement en cours…"
    }
  }

  clear() {
    if (this.isRecording) {
      this.isRecording = false
      this.recognition.stop()
    }
    this.prefix = ""
    this.sessionFinal = ""
    this.textareaTarget.value = ""
    this.setIdle()
  }

  finalize() {
    const separator = this.prefix && this.sessionFinal ? " " : ""
    this.textareaTarget.value = (this.prefix + separator + this.sessionFinal).trim()
    this.setIdle()
  }

  setIdle() {
    this.isRecording = false
    this.buttonTarget.classList.remove("recording")
    this.iconTarget.className = "fa-solid fa-microphone"
    this.statusTarget.textContent = ""
  }

  disconnect() {
    if (this.recognition && this.isRecording) {
      this.recognition.stop()
    }
  }
}
