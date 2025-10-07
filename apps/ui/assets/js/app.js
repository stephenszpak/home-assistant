import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import "./mic"

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
  }
}

const hooks = window.AppHooks
const liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}, hooks})
liveSocket.connect()
window.liveSocket = liveSocket
