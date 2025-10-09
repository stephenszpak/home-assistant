import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import "./mic"
import { VoiceMode } from "./hooks/voice_mode"

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
  }
}

window.AppHooks.VoiceMode = VoiceMode
const hooks = window.AppHooks
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks})
liveSocket.connect()
window.liveSocket = liveSocket
