export const ClockTick = {
  mounted() {
    const host = this.el.querySelector('#clock') || this.el
    const showSeconds = (host.dataset.showSeconds || host.dataset.showseconds) === 'true'
    const tz = host.dataset.tz || Intl.DateTimeFormat().resolvedOptions().timeZone
    const use24h = (host.dataset.use24h || host.dataset.use_24h) === 'true'

    const hEl = host.querySelector("[data-role='h']")
    const mEl = host.querySelector("[data-role='m']")
    const sEl = host.querySelector("[data-role='s']")
    const ampmEl = host.querySelector("[data-role='ampm']")
    const dayEl = host.querySelector("[data-role='day']")
    const dateEl = host.querySelector("[data-role='date']")

    if (sEl) sEl.classList.toggle('hidden', !showSeconds)

    const fmt = () => {
      const now = new Date()
      const opts = { hour: 'numeric', minute: '2-digit', ...(showSeconds ? { second: '2-digit' } : {}), hour12: !use24h, timeZone: tz }
      const parts = new Intl.DateTimeFormat(undefined, opts).formatToParts(now)
      const get = (t) => parts.find(p => p.type === t)?.value || ''
      let hour = get('hour')
      let minute = get('minute')
      let second = showSeconds ? get('second') : ''
      let dayPeriod = use24h ? '' : (get('dayPeriod') || '').toUpperCase()

      if (hEl) hEl.textContent = hour
      if (mEl) mEl.textContent = minute
      if (sEl && showSeconds) sEl.textContent = second
      if (ampmEl) ampmEl.textContent = dayPeriod

      const dayOpts = { weekday: 'long', timeZone: tz }
      const dateOpts = { month: 'long', day: 'numeric', timeZone: tz }
      if (dayEl) dayEl.textContent = new Intl.DateTimeFormat(undefined, dayOpts).format(now).toUpperCase()
      if (dateEl) dateEl.textContent = new Intl.DateTimeFormat(undefined, dateOpts).format(now).toUpperCase()
    }

    fmt()
    this._timer = setInterval(fmt, showSeconds ? 1000 : 60000)
  },
  destroyed() { if (this._timer) clearInterval(this._timer) }
}
