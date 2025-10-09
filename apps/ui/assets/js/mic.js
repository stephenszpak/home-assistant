import {Socket} from "phoenix"
(() => {
  const Hooks = (window.AppHooks = window.AppHooks || {})

  function ensureSocket() {
    if (window.STTSocket) return window.STTSocket
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
    const sock = new Socket("/socket", {params: {_csrf_token: csrfToken}})
    sock.connect()
    window.STTSocket = sock
    return sock
  }

  Hooks.Mic = {
    mounted() {
      this.listening = false
      this._rec = null
      this._stream = null
      this._recog = null
      this._finalText = ""
      this._interimText = ""
      this._hadText = false
      this.handleEvent("mic:stop", () => this.stop())
      this.el.addEventListener("click", () => (this.listening ? this.stop() : this.start()))
    },
    async start() {
      if (this.listening) return
      try {
        this._setListening()
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
        this._stream = stream
        // Channel setup
        const socket = ensureSocket()
        this._chan = socket.channel("stt:" + Date.now())
        await this._chan.join()
        this._chan.on("partial", (payload) => {
          if (payload && payload.text) this.pushEvent("mic_live_text", { text: payload.text })
        })
        // Try browser speech recognition for live captions (progressive enhancement)
        const SR = window.SpeechRecognition || window.webkitSpeechRecognition
        if (SR) {
          const recog = (this._recog = new SR())
          recog.continuous = true
          recog.interimResults = true
          // Force English for on-device captions to match Voice Mode
          recog.lang = "en-US"
          recog.onresult = (e) => {
            let finalChunk = ""
            let interimChunk = ""
            for (let i = e.resultIndex; i < e.results.length; i++) {
              const res = e.results[i]
              if (res.isFinal) finalChunk += res[0].transcript + " "
              else interimChunk += res[0].transcript
            }
            if (finalChunk) this._finalText += finalChunk
            this._interimText = interimChunk
            const combined = (this._finalText + this._interimText).trim()
            this.pushEvent("voice:partial", { text: combined })
            if (combined) this._hadText = true
          }
          // When speech ends, stop recording quickly
          recog.onspeechend = () => { if (this.listening) setTimeout(() => this.stop(), 125) }
          recog.onend = () => {}
          recog.onerror = () => {}
          try { recog.start() } catch (_) {}
        }
        const mime = MediaRecorder.isTypeSupported("audio/webm") ? "audio/webm" : "audio/ogg"
        await this._chan.push("start", { mime, realtime: false })
        const rec = (this._rec = new MediaRecorder(stream, { mimeType: mime }))
        const chunks = []
        rec.ondataavailable = async (e) => {
          if (e.data.size > 0) {
            chunks.push(e.data)
            // stream chunk to server
            try {
              const ab = await e.data.arrayBuffer()
              const b64 = btoa(String.fromCharCode(...new Uint8Array(ab)))
              this._chan.push("chunk", { data: b64 })
            } catch (_) {}
          }
        }
        rec.onstop = async () => {
          try {
            // Always use the banner (on-device) transcript for Ask
            const combined = (this._finalText + this._interimText).trim()
            if (combined) {
              this.pushEvent("voice:final", { text: combined })
              this.pushEvent("send", { text: combined })
            } else {
              // Briefly wait for any last SR result, then cancel
              setTimeout(() => {
                const retry = (this._finalText + this._interimText).trim()
                if (retry) {
                  this.pushEvent("voice:final", { text: retry })
                  this.pushEvent("send", { text: retry })
                } else {
                  this.pushEvent("voice:cancel", {})
                }
              }, 150)
            }
            // Stop server-side channel stream (cleanup only)
            try { await this._chan.push("stop", {}) } catch(_) {}
          } catch (err) {
            console.error("STT error", err)
            this.pushEvent("voice:cancel", {})
          } finally {
            if (this._recog) { try { this._recog.stop() } catch (_) {} }
            this._cleanupStream()
            this.pushEvent("mic_live_text", { text: "" })
            this._finalText = ""
            this._interimText = ""
            this._setIdle()
          }
        }
        rec.start(500) // reduce chunk frequency; lower server pressure
        // Auto-stop after 10s if user doesn't tap to stop
        this._autoTimer = setTimeout(() => this.stop(), 10000)
      } catch (err) {
        console.error("Mic error", err)
        this._setIdle()
      }
    },
    stop() {
      if (!this.listening) return
      this.listening = false
      if (this._autoTimer) { clearTimeout(this._autoTimer); this._autoTimer = null }
      if (this._rec && this._rec.state !== "inactive") {
        try { this._rec.stop() } catch (_) {}
      }
      if (this._recog) { try { this._recog.stop() } catch (_) {} }
      // banner cleared through voice events only
      this._setIdle()
      this._cleanupStream()
    },
    _cleanupStream() {
      if (this._stream) {
        try { this._stream.getTracks().forEach((t) => t.stop()) } catch (_) {}
        this._stream = null
      }
    },
    _setListening() {
      this.listening = true
      try { this.pushEvent("mic_state", { listening: true }) } catch (_) {}
    },
    _setIdle() {
      this.listening = false
      try { this.pushEvent("mic_state", { listening: false }) } catch (_) {}
    }
  }
})()
