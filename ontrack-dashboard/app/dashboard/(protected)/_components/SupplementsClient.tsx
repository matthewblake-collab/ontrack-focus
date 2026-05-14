'use client'

import { useState } from 'react'
import type { SupplementLogRow, SupplementRow } from '../_lib/adherence'
import type { DiscountUnlock, PartnerCodeRow } from '../_lib/partners'
import { useRealtime } from '../_lib/useRealtime'
import { StackList } from './StackList'
import { AdherenceHeatmap } from './AdherenceHeatmap'
import { SupplementEditDrawer } from './SupplementEditDrawer'

export function SupplementsClient({
  userId,
  initialSupplements,
  initialLogs,
  codes,
  unlocks,
}: {
  userId: string
  initialSupplements: SupplementRow[]
  initialLogs: SupplementLogRow[]
  codes: PartnerCodeRow[]
  unlocks: DiscountUnlock[]
}) {
  const [supplements, setSupplements] = useState(initialSupplements)
  const [logs, setLogs] = useState(initialLogs)
  const [editing, setEditing] = useState<SupplementRow | null>(null)

  useRealtime<SupplementRow>({
    userId,
    table: 'supplements',
    event: 'UPDATE',
    onChange: row =>
      setSupplements(prev => prev.map(s => (s.id === row.id ? row : s))),
  })

  useRealtime<SupplementLogRow>({
    userId,
    table: 'supplement_logs',
    event: 'INSERT',
    onChange: row => setLogs(prev => [row, ...prev]),
  })

  const protocolSupps = supplements.filter(s => s.in_protocol)
  const otherSupps = supplements.filter(s => !s.in_protocol)

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">Supplements</h2>
      <AdherenceHeatmap supplements={supplements} logs={logs} />

      {protocolSupps.length > 0 && (
        <>
          <h3 className="text-sm font-medium mt-4 text-accent">In protocol</h3>
          <StackList
            userId={userId}
            supplements={protocolSupps}
            logs={logs}
            codes={codes}
            unlocks={unlocks}
            onEdit={setEditing}
          />
        </>
      )}

      {otherSupps.length > 0 && (
        <>
          <h3 className="text-sm font-medium mt-4 text-text-dim">Other supplements</h3>
          <StackList
            userId={userId}
            supplements={otherSupps}
            logs={logs}
            codes={codes}
            unlocks={unlocks}
            onEdit={setEditing}
          />
        </>
      )}

      <SupplementEditDrawer
        supplement={editing}
        onClose={() => setEditing(null)}
        onSaved={u => setSupplements(prev => prev.map(s => (s.id === u.id ? u : s)))}
      />
    </div>
  )
}
