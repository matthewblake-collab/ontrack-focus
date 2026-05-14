'use client'

import { useMemo, useState } from 'react'
import { useRealtime } from '../_lib/useRealtime'
import type { JournalEntryRow } from '../_lib/journal'
import { JournalEntryCard } from './JournalEntryCard'
import { JournalFilters } from './JournalFilters'
import { NewEntryForm } from './NewEntryForm'

export function JournalClient({
  userId,
  initial,
  protocolId,
  protocolStartDate,
  protocolName,
}: {
  userId: string
  initial: JournalEntryRow[]
  protocolId: string | null
  protocolStartDate: string | null
  protocolName: string | null
}) {
  const [entries, setEntries] = useState<JournalEntryRow[]>(initial)
  const [selectedTag, setSelectedTag] = useState<string | null>(null)
  const [search, setSearch] = useState('')

  useRealtime<JournalEntryRow>({
    userId,
    table: 'health_journal',
    event: 'INSERT',
    onChange: row =>
      setEntries(prev => {
        if (prev.some(e => e.id === row.id)) return prev
        return [row, ...prev]
      }),
  })

  const allTags = useMemo(() => {
    const s = new Set<string>()
    for (const e of entries) if (e.tag) s.add(e.tag)
    return Array.from(s).sort()
  }, [entries])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return entries.filter(e => {
      if (selectedTag && e.tag !== selectedTag) return false
      if (q && !e.body.toLowerCase().includes(q)) return false
      return true
    })
  }, [entries, selectedTag, search])

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h2 className="text-lg font-semibold">Journal</h2>
        <NewEntryForm
          userId={userId}
          protocolId={protocolId}
          protocolStartDate={protocolStartDate}
          onSaved={row => setEntries(prev => [row, ...prev])}
        />
      </div>
      <JournalFilters
        tags={allTags}
        selectedTag={selectedTag}
        onTagChange={setSelectedTag}
        search={search}
        onSearchChange={setSearch}
      />
      {filtered.length === 0 ? (
        <div className="card text-text-dim text-sm">
          {entries.length === 0
            ? 'No journal entries yet. Tap + New entry to start.'
            : 'No entries match your filter.'}
        </div>
      ) : (
        <div className="space-y-2">
          {filtered.map(e => (
            <JournalEntryCard key={e.id} entry={e} protocolName={protocolName} />
          ))}
        </div>
      )}
    </div>
  )
}
