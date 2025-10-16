import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import "./mic"
import { VoiceMode } from "./hooks/voice_mode"
import { ClockTick } from "./clock_hooks"
import { SleepManager } from "./sleep_timer"
// optional UI hooks
// lightweight ambient/choreography
const Ambient = {
  mounted() {
    const root = this.el
    const hour = new Date().getHours()
    root.classList.remove('ambient-dawn','ambient-day','ambient-dusk','ambient-night')
    let cls = 'ambient-day'
    if (hour < 6) cls = 'ambient-night'
    else if (hour < 10) cls = 'ambient-dawn'
    else if (hour < 17) cls = 'ambient-day'
    else if (hour < 20) cls = 'ambient-dusk'
    else cls = 'ambient-night'
    root.classList.add(cls)
  }
}

const WeatherCycle = {
  mounted() {
    const STATES = Array.from(this.el.querySelectorAll('[data-cycle]'))
    if (STATES.length < 2) return
    let i = 0
    const show = (idx) => STATES.forEach((el, j) => { el.style.opacity = (j===idx? '1':'0'); el.style.display = (j===idx? 'block':'none') })
    show(0)
    this._t = setInterval(() => { i = (i+1) % STATES.length; show(i) }, 7000)
  },
  destroyed() { clearInterval(this._t) }
}

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")

// App-level hook for TTS playback and speaking indicator
window.AppHooks = window.AppHooks || {}
window.AppHooks.App = {
  mounted() {
    this.handleEvent("tts", async ({ text, volume }) => {
      try {
        const resp = await fetch("/api/tts", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": csrfToken || ""
          },
          body: JSON.stringify({ text })
        })
        const buf = await resp.arrayBuffer()
        const blob = new Blob([buf], { type: resp.headers.get("content-type") || "audio/wav" })
        const url = URL.createObjectURL(blob)
        const audio = new Audio(url)
        if (typeof volume === "number") {
          try { audio.volume = Math.max(0, Math.min(1, volume)) } catch (_) {}
        }
        audio.addEventListener("play", () => this.pushEvent("speaking", { state: true }))
        audio.addEventListener("ended", () => {
          this.pushEvent("speaking", { state: false })
          URL.revokeObjectURL(url)
        })
        audio.play().catch(() => this.pushEvent("speaking", { state: false }))
      } catch (e) {
        this.pushEvent("speaking", { state: false })
        console.error("TTS playback error", e)
      }
    })

    // Load persisted banner settings
    const mode = localStorage.getItem("banner_mode")
    const font = localStorage.getItem("banner_font")
    const hide = localStorage.getItem("banner_hide")
    this.pushEvent("banner_settings", { mode, font, hide })

    this.handleEvent("banner:save", ({ mode, font, hide }) => {
      if (mode) localStorage.setItem("banner_mode", mode)
      if (font) localStorage.setItem("banner_font", font)
      if (hide) localStorage.setItem("banner_hide", hide)
    })

    // Load clock prefs and send to LiveView
    const clock_use_24h = localStorage.getItem("clock_use_24h")
    const clock_show_seconds = localStorage.getItem("clock_show_seconds")
    const clock_tz = localStorage.getItem("clock_tz")
    this.pushEvent("clock:prefs", {
      clock_use_24h: clock_use_24h === null ? null : clock_use_24h === 'true',
      clock_show_seconds: clock_show_seconds === null ? null : clock_show_seconds === 'true',
      clock_tz: clock_tz || null
    })
  }
}

window.AppHooks.VoiceMode = VoiceMode
window.AppHooks.ClockTick = ClockTick
window.AppHooks.SleepManager = SleepManager
window.AppHooks.Ambient = Ambient
window.AppHooks.WeatherCycle = WeatherCycle
const hooks = window.AppHooks
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks})
liveSocket.connect()
window.liveSocket = liveSocket
