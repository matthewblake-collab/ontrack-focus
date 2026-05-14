'use client'

import { useState } from 'react'
import type { CheckinRow } from '../_lib/correlation'
import { useRealtime } from '../_lib/useRealtime'
import { TodayCard } from './TodayCard'
import { SparklinesWidget } from './SparklinesWidget'
import { CorrelationStrip } from './CorrelationStrip'
import { ThirtyDayChart } from './ThirtyDayChart'

function todayISO(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = String(d.getMonth() + 1).padStart(2, '0')
  const dd = String(d.getDate()).padStart(2, '0')
  return `${y}-${m}-${dd}`
}

export function OverviewClient({ userId, initial }: { userId: string; initial: CheckinRow[] }) {
  const [rows, setRows] = useState<CheckinRow[]>(initial)

  useRealtime<CheckinRow>({
    userId,
    table: 'daily_checkins',
    event: 'INSERT',
    onChange: row => {
      setRows(prev => {
        if (prev.some(r => r.checkin_date === row.checkin_date)) {
          return prev.map(r => (r.checkin_date === row.checkin_date ? row : r))
        }
        return [row, ...prev]
      })
    },
  })

  useRealtime<CheckinRow>({
    userId,
    table: 'daily_checkins',
    event: 'UPDATE',
    onChange: row => {
      setRows(prev => prev.map(r => (r.checkin_date === row.checkin_date ? row : r)))
    },
  })

  const today = rows.find(r => r.checkin_date === todayISO()) ?? null

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">Overview</h2>
      <TodayCard today={today} />
      <SparklinesWidget rows={rows} />
      <CorrelationStrip rows={rows} />
      <ThirtyDayChart rows={rows} />
    </div>
  )
}
