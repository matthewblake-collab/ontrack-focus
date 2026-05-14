'use client'

import { useState } from 'react'
import type { SupplementLogRow, SupplementRow } from '../_lib/adherence'
import type { DiscountUnlock, PartnerCodeRow } from '../_lib/partners'
import { useRealtime } from '../_lib/useRealtime'
import { StackList } from './StackList'
import { AdherenceHeatmap } from './AdherenceHeatmap'
import { SupplementEditDrawer } from './SupplementEditDrawer'
import { PrefillPrompt } from './PrefillPrompt'

export function SupplementsClient({
  userId,
  initialSupplements,
  initialLogs,
  codes,
  unlocks,
  prefillName,
}: {
  userId: string
  initialSupplements: SupplementRow[]
  initialLogs: SupplementLogRow[]
  codes: PartnerCodeRow[]
  unlocks: DiscountUnlock[]
  prefillName: string | null
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

  // Hide prefill prompt if a supplement with that name already exists
  const alreadyExists = prefillName
    ? supplements.some(s => s.name.toLowerCase() === prefillName.toLowerCase())
    : false

  return (
    <div className="space-y-4">
      <h2 className="text-lg font-semibold">Supplements</h2>
      {prefillName && !alreadyExists && (
        <PrefillPrompt
          userId={userId}
          name={prefillName}
          onAdded={row => setSupplements(prev => [row, ...prev])}
        />
      )}
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
