export const SleepManager = {
  mounted() {
    const timeout = Number(this.el.dataset.sleepTimeoutMs || 60000)
    const reset = () => {
      clearTimeout(this._t)
      this._t = setTimeout(() => this.pushEvent('ui:sleep', {}), timeout)
    }
    this._reset = reset

    ;['mousemove','keydown','pointerdown','touchstart','focus'].forEach(evt =>
      window.addEventListener(evt, reset, { passive: true })
    )

    this.handleEvent('answer:updated', reset)
    this.handleEvent('voice:state', reset)
    this.handleEvent('ask:started', reset)
    this.handleEvent('ask:ended', reset)

    reset()
  },
  destroyed() {
    clearTimeout(this._t)
    ;['mousemove','keydown','pointerdown','touchstart','focus'].forEach(evt =>
      window.removeEventListener(evt, this._reset)
    )
  }
}

