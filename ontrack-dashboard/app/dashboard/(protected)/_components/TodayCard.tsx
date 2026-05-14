'use client'

import type { CheckinRow, MetricKey } from '../_lib/correlation'

const metrics: { key: MetricKey; label: string }[] = [
  { key: 'sleep',     label: 'Sleep' },
  { key: 'energy',    label: 'Energy' },
  { key: 'wellbeing', label: 'Wellbeing' },
  { key: 'mood',      label: 'Mood' },
  { key: 'stress',    label: 'Stress' },
]

function colourFor(v: number | null | undefined): string {
  if (v === null || v === undefined) return 'text-text-muted'
  if (v >= 8) return 'text-green-400'
  if (v >= 5) return 'text-amber-400'
  return 'text-red-400'
}

function todayISO(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${dd}`
}

export function TodayCard({ today }: { today: CheckinRow | null }) {
  const expected = todayISO()
  if (!today || today.checkin_date !== expected) {
    return (
      <div className="card border-l-2 border-amber-500/60">
        <h3 className="text-sm font-medium">No check-in for today</h3>
        <p className="text-xs text-text-dim mt-1">
          Log today&apos;s check-in in OnTrack Focus to see your score here.
        </p>
      </div>
    )
  }
  return (
    <div className="card">
      <div className="flex items-center justify-between mb-3">
        <h3 className="text-sm font-medium">Today</h3>
        <span className="text-xs text-text-muted">{today.checkin_date}</span>
      </div>
      <div className="grid grid-cols-5 gap-2">
        {metrics.map(m => {
          const v = today[m.key]
          return (
            <div key={m.key} className="text-center">
              <div className={`text-2xl font-bold ${colourFor(v)}`}>{v ?? '—'}</div>
              <div className="text-[10px] text-text-muted mt-1">{m.label}</div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
