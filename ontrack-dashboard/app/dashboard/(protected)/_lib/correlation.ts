export type CheckinRow = {
  checkin_date: string  // yyyy-MM-dd
  sleep: number | null
  energy: number | null
  wellbeing: number | null
  mood: number | null
  stress: number | null
}

export type MetricKey = 'sleep' | 'energy' | 'wellbeing' | 'mood' | 'stress'

export function pearson(xs: number[], ys: number[]): number {
  const n = xs.length
  if (n < 3) return 0
  const sx = xs.reduce((a, b) => a + b, 0)
  const sy = ys.reduce((a, b) => a + b, 0)
  const mx = sx / n
  const my = sy / n
  let num = 0
  let dx2 = 0
  let dy2 = 0
  for (let i = 0; i < n; i++) {
    const dx = xs[i] - mx
    const dy = ys[i] - my
    num += dx * dy
    dx2 += dx * dx
    dy2 += dy * dy
  }
  const den = Math.sqrt(dx2 * dy2)
  return den === 0 ? 0 : num / den
}

export type PairResult = {
  a: MetricKey
  b: MetricKey
  lag: number
  r: number
  n: number
}

const METRICS: MetricKey[] = ['sleep', 'energy', 'wellbeing', 'mood', 'stress']

function addDays(date: string, days: number): string {
  const [y, m, d] = date.split('-').map(Number)
  const dt = new Date(Date.UTC(y, m - 1, d))
  dt.setUTCDate(dt.getUTCDate() + days)
  const yy = dt.getUTCFullYear()
  const mm = String(dt.getUTCMonth() + 1).padStart(2, '0')
  const dd = String(dt.getUTCDate()).padStart(2, '0')
  return `${yy}-${mm}-${dd}`
}

/** Returns the strongest (a, b, lag) pair by absolute Pearson r, with at least 5 paired points. */
export function bestCorrelation(rows: CheckinRow[]): PairResult | null {
  const sorted = [...rows].sort((x, y) => x.checkin_date.localeCompare(y.checkin_date))
  const byDate = new Map(sorted.map(r => [r.checkin_date, r]))
  const pairs: PairResult[] = []

  for (const a of METRICS) {
    for (const b of METRICS) {
      if (a === b) continue
      for (const lag of [0, 1]) {
        if (lag === 0 && METRICS.indexOf(a) >= METRICS.indexOf(b)) continue
        const xs: number[] = []
        const ys: number[] = []
        for (const row of sorted) {
          const va = row[a]
          if (typeof va !== 'number') continue
          const partner = byDate.get(addDays(row.checkin_date, lag))
          if (!partner) continue
          const vb = partner[b]
          if (typeof vb !== 'number') continue
          xs.push(va)
          ys.push(vb)
        }
        if (xs.length >= 5) {
          pairs.push({ a, b, lag, r: pearson(xs, ys), n: xs.length })
        }
      }
    }
  }
  if (pairs.length === 0) return null
  pairs.sort((x, y) => Math.abs(y.r) - Math.abs(x.r))
  return pairs[0]
}

export function correlationSentence(pair: PairResult): string {
  const dir = pair.r >= 0 ? 'higher' : 'lower'
  const r = pair.r.toFixed(2)
  if (pair.lag === 0) {
    return `Days with higher ${pair.a} also show ${dir} ${pair.b} (r=${r}, n=${pair.n})`
  }
  return `Higher ${pair.a} on one day predicts ${dir} ${pair.b} the next (r=${r}, n=${pair.n})`
}
