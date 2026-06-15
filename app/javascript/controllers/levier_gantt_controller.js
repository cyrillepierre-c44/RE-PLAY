import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { key: String }

  connect() {
    this._state = this._load()
    this._build()
    if (this._state.start && this._state.end) this._renderBars()
  }

  // ── DOM construction ──────────────────────────────────────────────────

  _build() {
    // Ruler: [badge-start][ticks][badge-end]
    this._ruler = document.createElement('div')
    this._ruler.className = 'gantt-ruler'

    const sb = this._dateBadge()
    const eb = this._dateBadge()
    this._startInput = sb.inp; this._startLbl = sb.lbl
    this._endInput   = eb.inp; this._endLbl   = eb.lbl

    this._ticksEl = document.createElement('div')
    this._ticksEl.className = 'gantt-ticks'

    this._ruler.appendChild(sb.wrap)
    this._ruler.appendChild(this._ticksEl)
    this._ruler.appendChild(eb.wrap)

    if (this._state.start) { this._startInput.value = this._state.start; this._startLbl.textContent = this._fmt(this._state.start) }
    if (this._state.end)   { this._endInput.value   = this._state.end;   this._endLbl.textContent   = this._fmt(this._state.end) }

    this._startInput.addEventListener('change', () => this._onDatesChange())
    this._endInput.addEventListener('change',   () => this._onDatesChange())

    // Bars container
    this._barsEl = document.createElement('div')
    this._barsEl.className = 'gantt-bars'

    this.element.appendChild(this._ruler)
    this.element.appendChild(this._barsEl)

    // Match ruler height to .levier-sub once, after paint
    requestAnimationFrame(() => this._syncRulerHeight())
  }

  _dateBadge() {
    const wrap = document.createElement('span')
    wrap.className = 'gantt-date-btn'

    const lbl = document.createElement('span')
    lbl.className = 'gantt-date-lbl'
    lbl.textContent = '—'

    const inp = document.createElement('input')
    inp.type = 'date'

    wrap.appendChild(lbl)
    wrap.appendChild(inp)
    return { wrap, inp, lbl }
  }

  _syncRulerHeight() {
    const body  = this.element.closest('.levier-body')
    const subEl = body?.querySelector('.levier-sub')
    if (subEl) this._ruler.style.height = subEl.offsetHeight + 'px'
  }

  // ── Event handlers ────────────────────────────────────────────────────

  _onDatesChange() {
    this._state.start = this._startInput.value
    this._state.end   = this._endInput.value

    this._startLbl.textContent = this._state.start ? this._fmt(this._state.start) : '—'
    this._endLbl.textContent   = this._state.end   ? this._fmt(this._state.end)   : '—'

    if (this._state.start && this._state.end) {
      this._ensureItems()
      this._clampItems()
      this._renderBars()
    } else {
      this._barsEl.innerHTML  = ''
      this._ticksEl.innerHTML = ''
    }
    this._save()
  }

  // ── Data helpers ──────────────────────────────────────────────────────

  _liElements() {
    return Array.from(
      this.element.closest('.levier-body')?.querySelectorAll('ul > li') || []
    )
  }

  _ensureItems() {
    const n = this._liElements().length
    if (!Array.isArray(this._state.items) || this._state.items.length !== n) {
      this._state.items = Array.from({ length: n }, () => ({
        start: this._state.start, end: this._state.end
      }))
    }
  }

  _clampItems() {
    const s = this._state.start, e = this._state.end
    this._state.items = this._state.items.map(it => ({
      start: it.start >= s ? it.start : s,
      end:   it.end   <= e ? it.end   : e
    }))
  }

  // ── Render ────────────────────────────────────────────────────────────

  _renderBars() {
    const startDate = new Date(this._state.start)
    const endDate   = new Date(this._state.end)
    const totalMs   = endDate - startDate
    if (totalMs <= 0) return
    const totalDays = totalMs / 86400000

    this._renderTicks(startDate, endDate, totalDays)

    this._barsEl.innerHTML = ''
    this._ensureItems()
    const lis = this._liElements()

    this._state.items.forEach((item, i) => {
      const h   = lis[i]?.offsetHeight || 16
      this._barsEl.appendChild(this._buildBarRow({ item, i, startDate, totalDays, h }))
    })
  }

  _renderTicks(startDate, endDate, totalDays) {
    this._ticksEl.innerHTML = ''
    const useMonths = totalDays > 60
    const stepDays  = totalDays <= 14 ? 2 : 7
    const totalMs   = totalDays * 86400000
    // Marge : ignorer les ticks trop proches des bords (couverts par les badges)
    const margin    = totalMs * 0.08

    const cur = new Date(startDate)
    if (useMonths) {
      cur.setDate(1)
    } else if (stepDays === 7) {
      cur.setDate(cur.getDate() - (cur.getDay() + 6) % 7) // aligner lundi
    }
    // Pour stepDays=2 on part de startDate directement

    let guard = 0
    while (cur <= endDate && guard < 60) {
      guard++
      const elapsed = cur - startDate
      const pct     = elapsed / totalMs * 100

      if (pct >= 0 && pct <= 100 && elapsed > margin && (endDate - cur) > margin) {
        const tick = document.createElement('span')
        tick.className = 'gantt-tick'
        tick.style.left = pct + '%'
        tick.textContent = useMonths
          ? cur.toLocaleDateString('fr-FR', { month: 'short' })
          : `${String(cur.getDate()).padStart(2, '0')}/${String(cur.getMonth() + 1).padStart(2, '0')}`
        this._ticksEl.appendChild(tick)
      }
      useMonths ? cur.setMonth(cur.getMonth() + 1) : cur.setDate(cur.getDate() + stepDays)
    }
  }

  _buildBarRow({ item, i, startDate, totalDays, h }) {
    const row = document.createElement('div')
    row.className = 'gantt-row'
    row.style.height = h + 'px'

    const track = document.createElement('div')
    track.className = 'gantt-track'

    const s = new Date(item.start)
    const e = new Date(item.end)
    const leftPct  = Math.max(0, (s - startDate) / (totalDays * 86400000) * 100)
    const widthPct = Math.max(1, (e - s) / (totalDays * 86400000) * 100)

    const bar = document.createElement('div')
    bar.className = 'gantt-bar'
    bar.style.left  = leftPct + '%'
    bar.style.width = Math.min(widthPct, 100 - leftPct) + '%'

    const hl = document.createElement('div')
    hl.className = 'gantt-handle gantt-handle--l'
    const hr = document.createElement('div')
    hr.className = 'gantt-handle gantt-handle--r'

    bar.appendChild(hl)
    bar.appendChild(hr)
    track.appendChild(bar)
    row.appendChild(track)

    this._wireDrag({ bar, hl, hr, i, track, startDate, totalDays })
    return row
  }

  // ── Drag & resize ─────────────────────────────────────────────────────

  _wireDrag({ bar, hl, hr, i, track, startDate, totalDays }) {
    const startDrag = (mode) => (e) => {
      e.preventDefault()
      e.stopPropagation()
      const rect      = track.getBoundingClientRect()
      const origLeft  = parseFloat(bar.style.left)
      const origWidth = parseFloat(bar.style.width)
      const startX    = e.clientX

      const onMove = (ev) => {
        const dx = (ev.clientX - startX) / rect.width * 100
        if (mode === 'move') {
          bar.style.left = Math.max(0, Math.min(100 - origWidth, origLeft + dx)) + '%'
        } else if (mode === 'left') {
          const nl = Math.max(0, Math.min(origLeft + origWidth - 2, origLeft + dx))
          bar.style.left  = nl + '%'
          bar.style.width = (origWidth - (nl - origLeft)) + '%'
        } else {
          bar.style.width = Math.max(2, Math.min(100 - origLeft, origWidth + dx)) + '%'
        }
      }

      const onUp = () => {
        document.removeEventListener('mousemove', onMove)
        document.removeEventListener('mouseup', onUp)
        const fl   = parseFloat(bar.style.left)  / 100
        const fw   = parseFloat(bar.style.width) / 100
        const newS = this._toDateStr(new Date(startDate.getTime() + fl * totalDays * 86400000))
        const newE = this._toDateStr(new Date(startDate.getTime() + (fl + fw) * totalDays * 86400000))
        this._state.items[i] = { start: newS, end: newE }
        this._save()
      }

      document.addEventListener('mousemove', onMove)
      document.addEventListener('mouseup', onUp)
    }

    bar.addEventListener('mousedown', (e) => {
      if (e.target !== hl && e.target !== hr) startDrag('move')(e)
    })
    hl.addEventListener('mousedown', startDrag('left'))
    hr.addEventListener('mousedown', startDrag('right'))
  }

  // ── Utils ─────────────────────────────────────────────────────────────

  _fmt(str) {
    if (!str) return '—'
    const [, m, d] = str.split('-')
    return `${d}/${m}`
  }

  _toDateStr(date) {
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, '0')
    const d = String(date.getDate()).padStart(2, '0')
    return `${y}-${m}-${d}`
  }

  _load() {
    try { return JSON.parse(localStorage.getItem(this.keyValue) || '{}') } catch { return {} }
  }

  _save() {
    localStorage.setItem(this.keyValue, JSON.stringify(this._state))
  }
}
