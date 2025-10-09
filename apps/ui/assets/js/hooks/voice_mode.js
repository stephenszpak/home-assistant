import { Socket } from "phoenix"

const OPENAI_WSS = (model) => `https://api.openai.com/v1/realtime?model=${encodeURIComponent(model)}`

export const VoiceMode = {
  mounted() {
    this.pc = null
    this.stream = null
    this.remoteAudio = new Audio()
    this.remoteAudio.autoplay = true
    this.remoteAudio.playsInline = true
    this.remoteAudio.muted = false

    this.handleEvent("voice:start", () => this.start())
    this.handleEvent("voice:stop", () => this.stop())
  },
  async start() {
    if (this.pc) return
    try {
      this.pushEvent("voice_state", { state: "connecting" })
      const tokenResp = await fetch("/api/voice/token", { method: "POST" })
      if (!tokenResp.ok) throw new Error("token_failed")
      const { token } = await tokenResp.json()
      if (!token) throw new Error("no_token")

      this.stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      this.pc = new RTCPeerConnection({
        iceServers: [{ urls: ["stun:stun.l.google.com:19302"] }]
      })
      this.stream.getTracks().forEach(t => this.pc.addTrack(t, this.stream))
      this.pc.ontrack = (e) => {
        if (e.streams && e.streams[0]) {
          this.remoteAudio.srcObject = e.streams[0]
          this.remoteAudio.addEventListener("playing", () => this.pushEvent("voice_state", { state: "speaking" }))
          this.remoteAudio.addEventListener("ended", () => this.pushEvent("voice_state", { state: "listening" }))
        }
      }
      this.pushEvent("voice_state", { state: "listening" })
      this.pushEvent("voice:start", {})

      // Local captions fallback for partials
      const SR = window.SpeechRecognition || window.webkitSpeechRecognition
      if (SR) {
        const recog = (this._recog = new SR())
        recog.continuous = true
        recog.interimResults = true
        recog.lang = "en-US"
        recog.onresult = (e) => {
          let buf = ""
          for (let i = e.resultIndex; i < e.results.length; i++) buf += e.results[i][0].transcript
          const txt = buf.trim()
          if (txt) this.pushEvent("voice:partial", { text: txt })
        }
        try { recog.start() } catch(_) {}
      }

      const offer = await this.pc.createOffer({ offerToReceiveAudio: true })
      await this.pc.setLocalDescription(offer)
      const model = (window.OPENAI_REALTIME_MODEL || "gpt-4o-realtime-preview")
      const sdpResp = await fetch(OPENAI_WSS(model), {
        method: "POST",
        headers: { "Authorization": `Bearer ${token}`, "Content-Type": "application/sdp" },
        body: offer.sdp
      })
      if (!sdpResp.ok) throw new Error("sdp_failed")
      const answer = { type: "answer", sdp: await sdpResp.text() }
      await this.pc.setRemoteDescription(answer)
    } catch (err) {
      console.error("voice start error", err)
      this.pushEvent("voice_session_error", { message: err.message || "voice_error" })
      this.stop()
    }
  },
  async stop() {
    try {
      if (this.pc) {
        this.pc.getSenders().forEach(s => { try { s.track && s.track.stop() } catch(_){} })
        this.pc.close()
      }
      if (this.stream) this.stream.getTracks().forEach(t => t.stop())
    } catch(_) {}
    this.pc = null
    this.stream = null
    this.remoteAudio.srcObject = null
    this.pushEvent("voice_session_stopped", {})
    this.pushEvent("voice_state", { state: "idle" })
    this.pushEvent("voice:cancel", {})
  }
}
