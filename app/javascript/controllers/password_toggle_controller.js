import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("input[type=password]").forEach(input => {
      const wrapper = document.createElement("div")
      wrapper.style.cssText = "position:relative;display:block;width:100%;"

      input.parentElement.insertBefore(wrapper, input)
      wrapper.appendChild(input)

      const btn = document.createElement("button")
      btn.type = "button"
      btn.innerHTML = '<i class="fa-regular fa-eye"></i>'
      btn.style.cssText = "position:absolute;top:50%;right:0.75rem;transform:translateY(-50%);background:none;border:none;color:#9CA3AF;cursor:pointer;padding:0;font-size:1rem;line-height:1;"
      btn.setAttribute("tabindex", "-1")

      btn.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        const visible = input.type === "text"
        input.type = visible ? "password" : "text"
        btn.innerHTML = visible
          ? '<i class="fa-regular fa-eye"></i>'
          : '<i class="fa-regular fa-eye-slash"></i>'
      })

      wrapper.appendChild(btn)
    })
  }
}
