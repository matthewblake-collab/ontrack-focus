'use client'

import { useMemo, useState, useTransition } from 'react'
import { useRouter } from 'next/navigation'
import { useRealtime } from '../_lib/useRealtime'
import {
  groupByMarker,
  latestByMarker,
  type BloodMarkerRow,
} from '../_lib/bloodMarkers'
import type { ProtocolType } from '../_lib/protocolConfig'
import { PROTOCOL_CONFIGS } from '../_lib/protocolConfig'
import { MarkerCard } from './MarkerCard'
import { MarkerDrawer } from './MarkerDrawer'
import { AddPanelForm } from './AddPanelForm'
import { FlagSummary } from './FlagSummary'

export function BloodworkClient({
  userId,
  initial,
  protocolType,
}: {
  userId: string
  initial: BloodMarkerRow[]
  protocolType: ProtocolType | null
}) {
  const router = useRouter()
  const [rows, setRows] = useState<BloodMarkerRow[]>(initial)
  const [selected, setSelected] = useState<string | null>(null)
  const [, startTransition] = useTransition()

  useRealtime<BloodMarkerRow>({
    userId,
    table: 'blood_markers',
    event: 'INSERT',
    onChange: row => setRows(prev => [...prev, row]),
  })

  const grouped = useMemo(() => groupByMarker(rows), [rows])
  const latest = useMemo(() => latestByMarker(rows), [rows])

  const protocolMarkers = useMemo(
    () => (protocolType ? PROTOCOL_CONFIGS[protocolType]?.trackedMarkers ?? [] : []),
    [protocolType]
  )

  const allMarkers = useMemo(() => {
    const set = new Set<string>([...protocolMarkers, ...rows.map(r => r.marker)])
    return Array.from(set).sort((a, b) => {
      const aP = protocolMarkers.includes(a) ? 0 : 1
      const bP = protocolMarkers.includes(b) ? 0 : 1
      if (aP !== bP) return aP - bP
      return a.localeCompare(b)
    })
  }, [rows, protocolMarkers])

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Bloodwork</h2>
        <AddPanelForm
          userId={userId}
          protocolType={protocolType}
          onSaved={() => startTransition(() => router.refresh())}
        />
      </div>

      <div className="card border-l-2 border-amber-500/60 text-xs text-text-dim">
        <span className="font-medium text-amber-400">Disclaimer:</span> For personal reference only.
        Not medical advice. All testing and interpretation must be supervised by a licensed medical
        professional.
      </div>

      <FlagSummary protocolType={protocolType} latestByMarker={latest} />

      {allMarkers.length === 0 ? (
        <div className="card text-text-dim text-sm">
          No bloodwork data yet. Tap &quot;Add blood panel&quot; to log your first results.
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
          {allMarkers.map(m => (
            <MarkerCard
              key={m}
              marker={m}
              latest={latest.get(m) ?? null}
              onClick={() => setSelected(m)}
              highlighted={protocolMarkers.includes(m)}
            />
          ))}
        </div>
      )}

      <MarkerDrawer
        marker={selected}
        rows={selected ? grouped.get(selected) ?? [] : []}
        protocolType={protocolType}
        onClose={() => setSelected(null)}
      />
    </div>
  )
}
